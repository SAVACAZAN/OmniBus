; ============================================================================
; OmniBus Phase 5: OS Layer Loader + 64-bit Long Mode
; startup_phase5.asm — verified flat binary, ORG 0x100000
; ============================================================================
; BUILDS ON Phase 4 (startup_phase4.asm — long mode verified)
; NEW IN PHASE 5:
;   1. PIO ATA disk reader in [BITS 32] section (before long mode)
;   2. Load Grid OS stub (8KB) from LBA 4096 → 0x110000
;   3. Load Analytics OS stub (8KB) from LBA 4352 → 0x150000
;   4. Load Execution OS stub (8KB) from LBA 4608 → 0x130000
;   5. Call init_plugin() for each module in [BITS 64] (after long mode)
;
; DISK LAYOUT (sectors):
;   0         Stage 1 (boot.asm, 512B)
;   1-8       Stage 2 (stage2_fixed.asm, 4KB)
;   2048-2063 This kernel (startup_phase5.asm, 8KB)
;   4096-4111 Grid OS stub (grid_stub.asm, 8KB)
;   4352-4367 Analytics OS stub (analytics_stub.asm, 8KB)
;   4608-4623 Execution OS stub (execution_stub.asm, 8KB)
;
; EXPECTED SERIAL: KD123TCRP LONG_MODE_OK GRID_OS_64_OK
;                  ANALYTICS_64_OK EXEC_OS_64_OK ADA64_INIT MOTHER_OS_64_OK
; ============================================================================

[BITS 32]
[ORG 0x100000]

; --- Header: ENDBR32 magic + 44 NOP padding ---
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
    ; PHASE 5: Load OS layer stubs from disk via PIO ATA (before long mode)
    ; ATA Primary channel: 0x1F0–0x1F7 (QEMU IDE emulation)
    ; We're in 32-bit PM with flat segments (ES base=0), no paging yet.
    ; All physical addresses 0x110000, 0x130000, 0x150000 are directly
    ; accessible as linear addresses with ES:EDI (ES=0x10, base=0).
    ; ========================================================================

    ; UART 'D' = Disk loads starting
    mov dx, 0x3F8
    mov al, 'D'
    out dx, al

    ; --- Load Grid OS stub: LBA 4096, 16 sectors → 0x110000 ---
    mov ebx, 4096
    mov ecx, 16
    mov edi, 0x110000
    call ata_read_sectors

    ; UART '1' = Grid OS loaded
    mov dx, 0x3F8
    mov al, '1'
    out dx, al

    ; --- Load Analytics OS stub: LBA 4352, 16 sectors → 0x150000 ---
    mov ebx, 4352
    mov ecx, 16
    mov edi, 0x150000
    call ata_read_sectors

    ; UART '2' = Analytics OS loaded
    mov dx, 0x3F8
    mov al, '2'
    out dx, al

    ; --- Load Execution OS stub: LBA 4608, 16 sectors → 0x130000 ---
    mov ebx, 4608
    mov ecx, 16
    mov edi, 0x130000
    call ata_read_sectors

    ; UART '3' = Execution OS loaded
    mov dx, 0x3F8
    mov al, '3'
    out dx, al

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
    ; 2MB identity pages:
    ;   PD[0] = 0x000083 → 0x000000-0x1FFFFF (covers kernel + OS stubs + VGA)
    ;   PD[1] = 0x200083 → 0x200000-0x3FFFFF (covers page tables)
    ; ========================================================================

    ; Clear PML4 (4KB)
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

    ; PML4[0] → PDPT @ 0x202000
    mov dword [0x201000], 0x202003
    mov dword [0x201004], 0

    ; PDPT[0] → PD @ 0x203000
    mov dword [0x202000], 0x203003
    mov dword [0x202004], 0

    ; PD[0] → 2MB page @ phys 0x000000 (PS=1, RW=1, P=1)
    ; Covers kernel (0x100000), OS stubs (0x110000,0x130000,0x150000), VGA (0xB8000)
    mov dword [0x203000], 0x000083
    mov dword [0x203004], 0

    ; PD[1] → 2MB page @ phys 0x200000 (covers page tables 0x201000-0x203FFF)
    mov dword [0x203008], 0x200083
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
    ; ========================================================================
    lgdt [gdt64_ptr]

    ; ========================================================================
    ; STEP 5: Set EFER.LME via WRMSR (MSR 0xC0000080)
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
    ; STEP 6: Enable paging (CR0.PG=1) → activates long mode
    ; ========================================================================
    mov eax, cr0
    or  eax, 0x80000000
    mov cr0, eax

    ; UART 'P' = CR0.PG succeeded, long mode active
    mov dx, 0x3F8
    mov al, 'P'
    out dx, al

    ; VGA 'P' GREEN
    mov word [0xB8008], 0x0A50

    ; ========================================================================
    ; STEP 7: Far jump to 64-bit CS → enters 64-bit long mode
    ; ========================================================================
    jmp 0x08:long_mode_entry

; ============================================================================
; PIO ATA Disk Read Subroutine (32-bit mode)
; Input:  EBX = LBA start sector (24-bit, < 0x1000000)
;         ECX = sector count (1-255)
;         EDI = destination buffer (linear address, ES=0x10 flat)
; Uses:   EAX, ECX, EDX, EDI (clobbered)
; Notes:  Uses primary ATA channel (0x1F0-0x1F7), LBA28 mode, master drive.
;         rep insw reads from port DX (0x1F0) to ES:EDI in 32-bit PM.
; ============================================================================
ata_read_sectors:
    ; Input: EBX = LBA (24-bit), ECX = sector count (1-255), EDI = dest buffer
    push ebp
    push ebx
    push ecx
    push esi
    push edi

    mov esi, ecx            ; save sector count in ESI for loop (CL still valid now)

    ; Drive select: master drive, LBA mode, LBA bits[27:24]=0
    mov dx, 0x1F6
    mov al, 0xE0
    out dx, al

    ; 400ns delay: read alternate status register 4 times
    mov dx, 0x3F6
    in  al, dx
    in  al, dx
    in  al, dx
    in  al, dx

    ; Sector count (CL = low byte of original ECX = sector count)
    mov dx, 0x1F2
    mov al, cl              ; CL valid in [BITS 32]; use before ECX is modified
    out dx, al

    ; LBA[7:0]
    mov dx, 0x1F3
    mov al, bl
    out dx, al

    ; LBA[15:8]
    mov dx, 0x1F4
    mov al, bh
    out dx, al

    ; LBA[23:16]
    ror ebx, 16
    mov dx, 0x1F5
    mov al, bl
    ror ebx, 16
    out dx, al

    ; Issue READ SECTORS command (LBA28, PIO)
    mov dx, 0x1F7
    mov al, 0x20
    out dx, al

    ; Read ESI sectors, 256 words (512 bytes) each
.sector_loop:
    ; Wait: BSY=0 (bit7) AND DRQ=1 (bit3)
    mov dx, 0x1F7
.bsy_wait:
    in  al, dx
    test al, 0x80           ; BSY set?
    jnz .bsy_wait
    test al, 0x08           ; DRQ set?
    jz  .bsy_wait

    ; Read 256 words = 512 bytes from data port into [ES:EDI]
    ; ES = 0x10 (flat data segment, base=0) set by stage2 — never clobbered
    mov dx, 0x1F0
    mov ecx, 256
    rep insw                ; reads word from port DX → [ES:EDI], EDI += 2

    dec esi
    jnz .sector_loop

    pop edi
    pop esi
    pop ecx
    pop ebx
    pop ebp
    ret

; ============================================================================
; GDT64 — 64-bit Global Descriptor Table
; ============================================================================
align 16
gdt64_start:
    dq 0x0000000000000000      ; [0x00] Null descriptor
gdt64_code:
    dq 0x00AF9A000000FFFF      ; [0x08] 64-bit code: L=1, G=1, P=1
gdt64_data:
    dq 0x00CF92000000FFFF      ; [0x10] Data: DB=1, G=1, P=1, RW=1
gdt64_end:

gdt64_ptr:
    dw gdt64_end - gdt64_start - 1
    dd gdt64_start

; ============================================================================
; LONG MODE ENTRY [BITS 64]
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

    ; 64-bit stack
    mov rsp, 0x7E000

    ; VGA 'M' GREEN = long mode alive
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

    ; Auth gate
    mov byte [0x100050], 0x70

    ; ========================================================================
    ; PHASE 5: Call init_plugin() for each loaded OS module
    ; Each stub has init_plugin at byte 0 (ORG = base address)
    ; RSP = 0x7E000 (valid stack for calls)
    ; ========================================================================

    ; --- Grid OS init_plugin @ 0x110000 ---
    mov rax, 0x110000
    call rax
    mov word [0xB800C], 0x0A47  ; VGA 'G' GREEN

    ; --- Analytics OS init_plugin @ 0x150000 ---
    mov rax, 0x150000
    call rax
    mov word [0xB800E], 0x0A41  ; VGA 'A' GREEN

    ; --- Execution OS init_plugin @ 0x130000 ---
    mov rax, 0x130000
    call rax
    mov word [0xB8010], 0x0A45  ; VGA 'E' GREEN

    ; ========================================================================
    ; Ada Mother OS stubs (Phase 4A pattern — running in 64-bit mode)
    ; ========================================================================
    call ada64_stub_initialize

    mov word [0xB8012], 0x0A4C  ; VGA 'L' GREEN

    call ada64_stub_event_loop

    cli
    hlt
    jmp $ - 2

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
; 64-bit Ada Event Loop Stub
; ============================================================================
ada64_stub_event_loop:
    push rax
    push rdx
    mov dx, 0x3F8
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
    pop rdx
    pop rax
    cli
.halt:
    hlt
    jmp .halt

; --- Pad to 8KB ---
times (0x2000 - ($ - $$)) db 0
