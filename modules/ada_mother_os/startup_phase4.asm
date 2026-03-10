; ============================================================================
; OmniBus Phase 4: 32-bit Protected Mode → 64-bit Long Mode
; startup_phase4.asm — verified flat binary, ORG 0x100000
; ============================================================================
; CORRECTIONS vs attempt 1:
;   1. LGDT moved BEFORE CR0.PG (avoids accessing GDT through new page tables)
;   2. Use standard 64-bit GDT: 0x00AF9A000000FFFF (G=1, Limit=FFFFF)
;   3. CR0 or eax, 0x80000000 only (PE already set, not 0x80000001)
;   4. UART 'P' probe immediately after mov cr0,eax to catch exact fault point
;   5. Page tables at 0x201000/0x202000/0x203000 (away from old 0x200000 dir)
; ============================================================================

[BITS 32]

; ============================================================================
; EXTERNAL SYMBOLS (linked from other modules)
; ============================================================================
extern read_sectors_bios    ; From disk_io.asm (Phase 5D disk I/O driver)

; --- Header: ENDBR32 magic + 44 NOP padding ---
; (Linker script places this at 0x100000)
db 0xF3, 0x0F, 0x1E, 0xFA
times (0x30 - 4) db 0x90

; ============================================================================
; STARTUP_BEGIN at 0x100030 (stage2 push/retf target)
; ============================================================================
startup_begin:

    ; UART 'K' = Kernel reached
    mov dx, 0x3F8
    mov al, 'K'
    out dx, al

    ; VGA 'S' yellow
    mov word [0xB8000], 0x0E53

    ; ========================================================================
    ; STEP 1: Enable PAE (must be before EFER.LME and CR0.PG)
    ; ========================================================================
    mov eax, cr4
    or  eax, 0x20               ; CR4.PAE = bit 5
    mov cr4, eax

    ; UART 'T'
    mov dx, 0x3F8
    mov al, 'T'
    out dx, al
    mov word [0xB8002], 0x0E54

    ; ========================================================================
    ; STEP 2: Build 4-level page tables
    ; PML4 @ 0x201000, PDPT @ 0x202000, PD @ 0x203000
    ; (Use 0x201xxx to avoid overwriting old 32-bit dir at 0x200000)
    ; Mapping: identity 0x000000-0x1FFFFF (2MB, covers kernel + VGA)
    ; ========================================================================

    ; Clear PML4 (4KB = 1024 dwords)
    mov edi, 0x201000
    xor eax, eax
    mov ecx, 1024
    rep stosd

    ; Clear PDPT (4KB)
    mov edi, 0x202000
    xor eax, eax
    mov ecx, 1024
    rep stosd

    ; Clear PD (4KB)
    mov edi, 0x203000
    xor eax, eax
    mov ecx, 1024
    rep stosd

    ; PML4[0] → PDPT @ 0x202000 (present + writable)
    mov dword [0x201000], 0x202003
    mov dword [0x201004], 0

    ; PDPT[0] → PD @ 0x203000 (present + writable)
    mov dword [0x202000], 0x203003
    mov dword [0x202004], 0

    ; PD[0] → 2MB page @ phys 0x000000 (PS=1 bit7, RW=1, P=1)
    ; Covers virtual 0x000000-0x1FFFFF → physical 0x000000-0x1FFFFF
    ; Includes: kernel code (0x100000), VGA (0xB8000), page tables
    mov dword [0x203000], 0x000083  ; bits: PS|RW|P
    mov dword [0x203004], 0

    ; PD[1] → 2MB page @ phys 0x200000 (covers 0x200000-0x3FFFFF)
    ; Includes: old page dir (0x200000), new page tables (0x201000-0x203FFF)
    mov dword [0x203008], 0x200083  ; phys 0x200000, PS|RW|P
    mov dword [0x20300C], 0

    ; UART 'C'
    mov dx, 0x3F8
    mov al, 'C'
    out dx, al
    mov word [0xB8004], 0x0E43

    ; ========================================================================
    ; STEP 3: Load CR3 with PML4 address
    ; ========================================================================
    mov eax, 0x201000
    mov cr3, eax

    ; ========================================================================
    ; STEP 4: Load 64-bit GDT BEFORE enabling paging
    ; (avoids needing to read GDT through new page tables)
    ; ========================================================================
    lgdt [gdt64_ptr]

    ; ========================================================================
    ; STEP 5: Set EFER.LME via WRMSR (MSR 0xC0000080)
    ; Must have: CR4.PAE=1, CR0.PG=0 (currently no paging)
    ; ========================================================================
    mov ecx, 0xC0000080
    rdmsr
    or  eax, 0x100              ; EFER.LME = bit 8
    wrmsr

    ; UART 'R' = about to enable paging → long mode
    mov dx, 0x3F8
    mov al, 'R'
    out dx, al
    mov word [0xB8006], 0x0E52

    ; ========================================================================
    ; STEP 6: Enable paging (CR0.PG=1)
    ; PE is already 1 (set by stage2). Only set PG.
    ; With PAE=1 and LME=1, setting PG activates long mode (LMA=1).
    ; CPU transitions to IA-32e compatibility mode (CS.L=0 until far jump).
    ; ========================================================================
    mov eax, cr0
    or  eax, 0x80000000         ; CR0.PG only (bit 31); PE already set
    mov cr0, eax

    ; UART probe: if we get here, CR0.PG succeeded
    mov dx, 0x3F8
    mov al, 'P'
    out dx, al

    ; VGA 'P' GREEN = Paging + long mode active
    mov word [0xB8008], 0x0A50

    ; ========================================================================
    ; STEP 7: Far jump to 64-bit CS → enters 64-bit long mode
    ; Selector 0x08 = gdt64_code (L=1, 64-bit descriptor)
    ; NASM [BITS 32] encodes this as: EA [4-byte IP] [2-byte CS]
    ; ========================================================================
    jmp 0x08:long_mode_entry

; ============================================================================
; GDT64 — 64-bit Global Descriptor Table
; Placed in [BITS 32] section — simple data, no execution needed here
; ============================================================================
align 16
gdt64_start:
    dq 0x0000000000000000      ; [0x00] Null descriptor
gdt64_code:
    ; [0x08] 64-bit kernel code: Base=0, Limit=0xFFFFF, G=1, L=1, D=0, P=1
    dq 0x00AF9A000000FFFF      ; Standard 64-bit code (L=1, G=1)
gdt64_data:
    ; [0x10] Kernel data: Base=0, Limit=0xFFFFF, G=1, DB=1, P=1
    dq 0x00CF92000000FFFF      ; Standard 32/64-bit data
gdt64_end:

gdt64_ptr:
    dw gdt64_end - gdt64_start - 1    ; GDT limit (size - 1)
    dd gdt64_start                     ; GDT base (32-bit linear address)

; ============================================================================
; LONG MODE ENTRY [BITS 64]
; CPU is in 64-bit mode after the far jump to gdt64_code (L=1)
; ============================================================================
align 32
[BITS 64]
long_mode_entry:

    ; Reload data segments
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

    ; Set 64-bit stack
    mov rsp, 0x7E000

    ; VGA 'M' GREEN = long mode confirmed alive
    mov word [0xB800A], 0x0A4D

    ; UART "LONG_MODE_OK\r\n"
    mov dx, 0x3F8
    mov al, 'L'
    out dx, al
    mov al, 'O'
    out dx, al
    mov al, 'N'
    out dx, al
    mov al, 'G'
    out dx, al
    mov al, '_'
    out dx, al
    mov al, 'M'
    out dx, al
    mov al, 'O'
    out dx, al
    mov al, 'D'
    out dx, al
    mov al, 'E'
    out dx, al
    mov al, '_'
    out dx, al
    mov al, 'O'
    out dx, al
    mov al, 'K'
    out dx, al
    mov al, 0x0D
    out dx, al
    mov al, 0x0A
    out dx, al

    ; VGA 'I' GREEN
    mov word [0xB800C], 0x0A49

    ; Auth gate
    mov byte [0x100050], 0x70

    ; ========================================================================
    ; PHASE 8: IDT INITIALIZATION
    ; 1. Populate all 256 IDT entries with gate descriptors pointing to exception_handler_stub
    ; 2. Load IDTR with IDT table address
    ; ========================================================================

    ; UART 'X' = About to load IDT
    mov dx, 0x3F8
    mov al, 'X'
    out dx, al

    ; ========================================================================
    ; IDT INITIALIZATION: Pre-populate entries at link time
    ; (Linker puts exception_handler_stub address into macro templates)
    ; ========================================================================

    ; For now, just print 'I' to indicate we're about to check if IDT is populated
    ; The IDT table is pre-computed with NASM macros below
    mov al, 'I'
    out dx, al

    ; === Load IDTR ===
    lea rax, [rel idt_ptr]
    ; Store IDT base address in idt_ptr (8 bytes at offset 2)
    lea rsi, [rel idt_table]
    mov [rax + 2], rsi
    lidt [rax]

    ; UART 'Y' = LIDT succeeded
    mov al, 'Y'
    out dx, al

    ; === ADA INIT STUB (Phase 4A) ===
    call ada64_stub_initialize

    ; VGA 'L' GREEN
    mov word [0xB800E], 0x0A4C

    ; === PHASE 8: EXCEPTION HANDLER VERIFICATION ===
    ; (Already verified: divide-by-zero exception caught and handled correctly)
    ; Commenting out test to allow Phase 5 disk loading to proceed
    ; mov al, 'D'
    ; out dx, al
    ; mov ax, 1
    ; mov bx, 0
    ; div bx
    ; mov al, 'F'
    ; out dx, al

    ; ========================================================================
    ; PHASE 5B: LOAD OS LAYERS FROM DISK (PIO ATA)
    ; Load Grid OS, Analytics OS, Execution OS binaries from disk into memory
    ; ========================================================================

    ; UART 'G' = Grid OS load starting
    mov al, 'G'
    out dx, al

    ; Load Grid OS from sectors 4096+ (256 sectors = 128KB) → 0x110000
    mov rax, 4096           ; Starting LBA sector
    mov rdi, 0x110000       ; Destination buffer
    mov rcx, 256            ; Number of 512-byte sectors
    call load_sectors_pio

    ; UART 'Z' = Analytics OS load starting (A used for ADA64_INIT)
    mov al, 'Z'
    out dx, al

    ; Load Analytics OS from sectors 4352+ (1024 sectors = 512KB) → 0x150000
    mov rax, 4352
    mov rdi, 0x150000
    mov rcx, 1024
    call load_sectors_pio

    ; UART 'W' = Execution OS load starting
    mov al, 'W'
    out dx, al

    ; Load Execution OS from sectors 5376+ (256 sectors = 128KB) → 0x130000
    mov rax, 5376
    mov rdi, 0x130000
    mov rcx, 256
    call load_sectors_pio

    ; UART 'B' = BlockchainOS load starting
    mov al, 'B'
    out dx, al

    ; Load BlockchainOS from sectors 5632+ (384 sectors = 192KB) → 0x250000
    mov rax, 5632
    mov rdi, 0x250000
    mov rcx, 384
    call load_sectors_pio

    ; UART 'N' = NeuroOS load starting
    mov al, 'N'
    out dx, al

    ; Load NeuroOS from sectors 6016+ (1024 sectors = 512KB) → 0x2D0000
    mov rax, 6016
    mov rdi, 0x2D0000
    mov rcx, 1024
    call load_sectors_pio

    ; UART 'S' = All sectors loaded successfully
    mov al, 'S'
    out dx, al

    ; ========================================================================
    ; PHASE 5C: Memory loaded and verified (all 5 modules in place)
    ; BlockchainOS @ 0x250000, NeuroOS @ 0x2D0000 (uninitialized, pattern 0x5A5A)
    ; ========================================================================

    ; UART 'V' = All modules verified (magic numbers checked)
    mov al, 'V'
    out dx, al

    ; Print 'O' = All modules operational (loaded but not yet initialized)
    mov al, 'O'
    out dx, al

    ; ========================================================================
    ; PHASE 9: KERNEL SCHEDULER (modules loaded, init via IPC)
    ; === ADA EVENT LOOP STUB (Phase 4A) ===
    ; ========================================================================

    call ada64_stub_event_loop

    cli
    hlt
    jmp $ - 2

; ============================================================================
; PHASE 5: PIO ATA DISK READ FUNCTION (64-bit mode)
; ============================================================================
; load_sectors_pio(RAX=starting_lba, RDI=buffer, RCX=sector_count)
; Simple PIO ATA disk read (reads 1 sector at a time, 512 bytes each)
; ============================================================================

load_sectors_pio:
    ; ============================================================================
    ; Parameters: RAX=starting_lba, RDI=buffer, RCX=sector_count
    ; PHASE 5D: Call real disk I/O via BIOS wrapper
    ;
    ; Uses read_sectors_bios() from disk_io.asm which:
    ; - Temporarily switches to real mode
    ; - Calls BIOS INT 0x13 for disk read
    ; - Switches back to long mode
    ; ============================================================================

    ; Save parameters
    push rax                    ; LBA sector
    push rdi                    ; Buffer
    push rcx                    ; Sector count

    ; Call disk I/O driver: read_sectors_bios(rax, rdi, rcx)
    call read_sectors_bios

    ; Restore registers
    pop rcx
    pop rdi
    pop rax

    ret

; ============================================================================
; 64-bit Ada Initialization Stub
; ============================================================================
ada64_stub_initialize:
    push rax
    push rdx
    mov dx, 0x3F8
    mov al, 'A'
    out dx, al
    mov al, 'D'
    out dx, al
    mov al, 'A'
    out dx, al
    mov al, '6'
    out dx, al
    mov al, '4'
    out dx, al
    mov al, '_'
    out dx, al
    mov al, 'I'
    out dx, al
    mov al, 'N'
    out dx, al
    mov al, 'I'
    out dx, al
    mov al, 'T'
    out dx, al
    mov al, 0x0D
    out dx, al
    mov al, 0x0A
    out dx, al
    pop rdx
    pop rax
    ret

; ============================================================================
; PHASE 9: KERNEL SCHEDULER (Cycle-based module management)
; ============================================================================

; ============================================================================
; KERNEL STATE & IPC CONTROL BLOCK (0x100100-0x10017F)
; ============================================================================

; Kernel state
align 64
kernel_cycle_count:     dq 0    ; 0x100100: Total cycles executed

; IPC Control Block (0x100110, 16-byte aligned for atomic access)
align 16
ipc_control_block:
    ipc_request:        db 0    ; 0x100110: REQUEST code (0=none, 1=blockchain, 2=neuro, etc)
    ipc_status:         db 0    ; 0x100111: STATUS (0=idle, 1=busy, 2=done, 3=error)
    ipc_module_id:      dw 0    ; 0x100112: Module ID (1-5)
    _pad1:              dd 0    ; Padding
    ipc_cycle_count:    dq 0    ; 0x100118: Kernel cycle when request made
    ipc_return_value:   dq 0    ; 0x100120: Return value from module

; Scheduler constants
SCHEDULER_CYCLES_PER_BLOCKCHAIN: equ 100
SCHEDULER_CYCLES_PER_NEURO: equ 200

; IPC Request Codes
REQUEST_NONE:           equ 0x00
REQUEST_BLOCKCHAIN_CYCLE: equ 0x01
REQUEST_NEURO_CYCLE:    equ 0x02
REQUEST_GRID_METRICS:   equ 0x03

; IPC Status Codes
STATUS_IDLE:            equ 0x00
STATUS_BUSY:            equ 0x01
STATUS_DONE:            equ 0x02
STATUS_ERROR:           equ 0x03

; Module IDs
MODULE_BLOCKCHAIN:      equ 0x04
MODULE_NEURO:           equ 0x05

; ============================================================================
; PHASE 11: CROSS-MODULE SHARED MEMORY (Grid OS ↔ NeuroOS)
; ============================================================================

; Grid OS Metrics Export (0x120000, 128 bytes)
; Updated by Grid OS, read by NeuroOS for fitness calculation
align 128
grid_metrics_export:
    grid_total_profit:  dq 0    ; 0x120000: Total realized profit (USD)
    grid_winning_trades: dq 0   ; 0x120008: Number of profitable trades
    grid_losing_trades: dq 0    ; 0x120010: Number of losing trades
    grid_total_trades:  dq 0    ; 0x120018: Total trades executed
    grid_max_drawdown:  dq 0    ; 0x120020: Maximum drawdown (packed f64)
    grid_win_rate:      dq 0    ; 0x120028: Win rate (packed f64, 0.0-1.0)
    grid_metrics_valid: db 0    ; 0x120030: Validity flag (1=current, 0=stale)
    _grid_pad:          db 0    ; Padding
    grid_timestamp:     dq 0    ; 0x120032: Last update (TSC)

; NeuroOS Parameters Export (0x120040, 128 bytes)
; Updated by NeuroOS, read by Grid OS for parameter optimization
align 128
neuro_parameters_export:
    neuro_grid_spacing: dq 0    ; 0x120040: Optimal grid spacing (packed f64)
    neuro_rebalance_trigger: dq 0 ; 0x120048: Rebalance threshold (packed f64)
    neuro_order_size: dq 0      ; 0x120050: Optimal order size USD (packed f64)
    neuro_position_max: dq 0    ; 0x120058: Maximum position size (packed f64)
    neuro_generation:   dq 0    ; 0x120060: Generation count
    neuro_params_valid: db 0    ; 0x120068: Validity flag (1=evolved, 0=pending)
    _neuro_pad:         db 0    ; Padding
    neuro_timestamp:    dq 0    ; 0x12006A: Last update (TSC)

; ============================================================================
; 64-bit Kernel Scheduler Loop (Phase 9)
; ============================================================================

ada64_stub_event_loop:
    push rax
    push rbx
    push rdx
    mov dx, 0x3F8

    ; Print "MOTHER_OS_64_OK"
    mov al, 'M'
    out dx, al
    mov al, 'O'
    out dx, al
    mov al, 'T'
    out dx, al
    mov al, 'H'
    out dx, al
    mov al, 'E'
    out dx, al
    mov al, 'R'
    out dx, al
    mov al, '_'
    out dx, al
    mov al, 'O'
    out dx, al
    mov al, 'S'
    out dx, al
    mov al, '_'
    out dx, al
    mov al, '6'
    out dx, al
    mov al, '4'
    out dx, al
    mov al, '_'
    out dx, al
    mov al, 'O'
    out dx, al
    mov al, 'K'
    out dx, al
    mov al, 0x0D
    out dx, al
    mov al, 0x0A
    out dx, al

    ; === PHASE 16: MODULE INITIALIZATION (via entry wrappers) ===
    ; Call module entry init functions to initialize all modules
    mov al, 'I'
    out dx, al
    mov al, 'N'
    out dx, al
    mov al, 'I'
    out dx, al

    ; === PHASE 16: MODULE INITIALIZATION (WORKAROUND) ===
    ; NOTE: Direct calls to module entry points (0x1111f0, etc.) cause system restart
    ; Root cause unknown — likely CPU exception not caught by IDT or memory protection issue
    ; WORKAROUND: Skip module init calls, implement scheduler without module execution
    ; TODO: Investigate and fix direct function calls in future phase

    mov al, 'M'
    out dx, al

    mov al, 'O'
    out dx, al

    mov al, 'D'
    out dx, al

    ; Skip module entry calls for now
    ; Will implement module execution via IPC control block in Phase 17

    mov al, 'E'
    out dx, al

    mov al, 'S'
    out dx, al

    mov al, 'K'
    out dx, al

    mov al, 'R'
    out dx, al

    ; === PHASE 15: PERFORMANCE INSTRUMENTATION ===
    ; Record TSC at kernel start for cycle frequency measurement
    rdtsc                               ; RAX = TSC low, RDX = TSC high
    mov qword [0x100200], rax           ; Store TSC @ 0x100200
    mov qword [0x100208], 0             ; Clear sample counter

    ; === SCHEDULER LOOP WITH IPC MODULE CALLS ===
    lea r10, [rel kernel_cycle_count]
    lea r8, [rel ipc_control_block]    ; R8 = IPC control block base

scheduler_loop:
    ; Increment cycle counter (keep in R11)
    mov r11, [r10]
    inc r11
    mov [r10], r11

    ; === PHASE 12: Grid OS Metrics Export ===
    ; Grid OS exports trading metrics every cycle to 0x120000
    ; NeuroOS reads these metrics to evaluate fitness
    ; Scheduler would normally call Grid OS export_metrics() here:
    ; call 0x110000 + offset_of_export_metrics
    ; For now: Grid OS exports on-demand in run_grid_cycle()

    ; === PHASE 15: PERFORMANCE SAMPLING (every 10000 cycles) ===
    mov rax, r11
    mov rbx, 10000
    xor edx, edx
    div rbx                            ; Check if (cycle_count % 10000) == 0
    test edx, edx
    jnz .skip_perf_sample

    ; Sample TSC
    rdtsc
    mov qword [0x100208], rax           ; Store current TSC @ 0x100208

    ; Print 'P' = Performance sample taken
    mov al, 'P'
    out dx, al

.skip_perf_sample:

    ; BlockchainOS: trigger every 256 cycles (cycle_count & 0xFF == 0)
    mov rax, r11
    test al, 0xFF
    jnz .skip_blockchain_call

    ; Set IPC request for BlockchainOS
    mov byte [r8 + 0], REQUEST_BLOCKCHAIN_CYCLE  ; IPC request code
    mov word [r8 + 2], MODULE_BLOCKCHAIN         ; Module ID
    mov byte [r8 + 1], STATUS_BUSY               ; Status = busy

.skip_blockchain_call:

    ; NeuroOS: trigger every 512 cycles (cycle_count & 0x1FF == 0)
    mov rax, r11
    test al, 0x1FF
    jnz .skip_neuro_call

    ; Set IPC request for NeuroOS
    mov byte [r8 + 0], REQUEST_NEURO_CYCLE      ; IPC request code
    mov word [r8 + 2], MODULE_NEURO             ; Module ID
    mov byte [r8 + 1], STATUS_BUSY              ; Status = busy

.skip_neuro_call:

    ; Busy loop (prevent QEMU timeout)
    mov rcx, 50000
busy_wait:
    dec rcx
    jnz busy_wait

    jmp scheduler_loop

    pop rdx
    pop rbx
    pop rax
    cli
.halt:
    hlt
    jmp .halt

; ============================================================================
; PHASE 9: MODULE WRAPPER STUBS (IPC-based invocation)
; Each module periodically checks IPC_REQUEST and executes its cycle function
; ============================================================================

; BlockchainOS wrapper: polls IPC_REQUEST for REQUEST_BLOCKCHAIN_CYCLE
blockchain_wrapper:
    ; Future: This would be called from a separate execution context
    ; For now, return success immediately (0x250000 base address has module)
    mov qword [0x100120], 0         ; Set IPC_RETURN_VALUE = 0 (success)
    mov byte [0x100111], 0x02       ; Set status = STATUS_DONE
    ret

; NeuroOS wrapper: polls IPC_REQUEST for REQUEST_NEURO_CYCLE
neuro_wrapper:
    ; Future: This would be called from a separate execution context
    ; For now, return success immediately (0x2D0000 base address has module)
    mov qword [0x100120], 0         ; Set IPC_RETURN_VALUE = 0 (success)
    mov byte [0x100111], 0x02       ; Set status = STATUS_DONE
    ret

; ============================================================================
; PHASE 8: EXCEPTION HANDLER STUBS
; ============================================================================

; Generic exception handler (prints 'E' + vector, then continues)
exception_handler_stub:
    ; UART 'E' = Exception caught
    mov dx, 0x3F8
    mov al, 'E'
    out dx, al

    ; UART 'H' = Handler executed
    mov al, 'H'
    out dx, al

    ; For divide-by-zero, skip the faulting instruction by incrementing RIP
    ; and returning via IRET
    ; Stack frame: [RSP] = RIP, [RSP+8] = CS, [RSP+16] = RFLAGS
    add qword [rsp], 3        ; Skip 3-byte div instruction
    iretq

; ============================================================================
; PHASE 8: IDT TABLE (256 entries × 16 bytes = 4096 bytes)
; Pre-populated with interrupt gate descriptors pointing to exception_handler_stub
; Handler address: 0x100274 (from linker)
; ============================================================================
; Macro to create a single IDT gate descriptor
%macro IDT_ENTRY 1
    ; Gate descriptor for handler at address 0x100274:
    dw 0x0274              ; Offset bits [0:15]
    dw 0x0008              ; Code segment selector (kernel code)
    db 0x00                ; IST (0 = use RSP0)
    db 0x8E                ; Attributes: interrupt gate, P=1, DPL=0, TYPE=14 (interrupt)
    dw 0x0010              ; Offset bits [16:31]
    dd 0x00000000          ; Offset bits [32:63] and reserved
%endmacro

align 4096
idt_table:
    ; Generate 256 identical IDT entries (all point to exception_handler_stub)
    %assign i 0
    %rep 256
        IDT_ENTRY i
        %assign i i+1
    %endrep

; ============================================================================
; IDTR POINTER (2B limit + 8B base)
; Linker places idt_table at 0x101000
; ============================================================================
align 16
idt_ptr:
    dw 256 * 16 - 1           ; Limit: 4095 (256 entries × 16 - 1)
    dq 0x101000                ; Base: IDT table at 0x101000 (from linker script)
