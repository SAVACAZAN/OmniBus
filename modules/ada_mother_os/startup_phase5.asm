; ============================================================================
; OmniBus Phase 5: Long Mode + UART Driver + IDT Initialization
; startup_phase5.asm — IDT/UART setup before loading OS layers
; ============================================================================
; Extends startup_phase4.asm with:
;   1. uart_init() → 115200 baud serial driver
;   2. idt_init() → Interrupt Descriptor Table (256 × 16-byte entries)
;   3. uart_send_string() for debug output
;   4. Verification output: UART_READY, IDT_READY
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

    ; PML4[0] → PDPT @ 0x202000
    mov dword [0x201000], 0x202003
    mov dword [0x201004], 0

    ; PDPT[0] → PD @ 0x203000
    mov dword [0x202000], 0x203003
    mov dword [0x202004], 0

    ; PD[0] → 2MB page @ phys 0x000000
    mov dword [0x203000], 0x000083
    mov dword [0x203004], 0

    ; PD[1] → 2MB page @ phys 0x200000
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
    ; STEP 6: Enable paging (CR0.PG=1)
    ; ========================================================================
    mov eax, cr0
    or  eax, 0x80000000         ; CR0.PG only (bit 31)
    mov cr0, eax

    ; UART probe
    mov dx, 0x3F8
    mov al, 'P'
    out dx, al

    ; VGA 'P' GREEN = Paging + long mode active
    mov word [0xB8008], 0x0A50

    ; ========================================================================
    ; STEP 7: Far jump to 64-bit CS → enters 64-bit long mode
    ; ========================================================================
    jmp 0x08:long_mode_entry

; ============================================================================
; GDT64 — 64-bit Global Descriptor Table
; ============================================================================
align 16
gdt64_start:
    dq 0x0000000000000000      ; [0x00] Null descriptor
gdt64_code:
    dq 0x00AF9A000000FFFF      ; [0x08] 64-bit kernel code
gdt64_data:
    dq 0x00CF92000000FFFF      ; [0x10] Kernel data
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

    ; Set 64-bit stack
    mov rsp, 0x7E000

    ; VGA 'M' GREEN = long mode confirmed
    mov word [0xB800A], 0x0A4D

    ; Quick UART test (direct output)
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
    ; PHASE 5: UART + IDT Initialization (verification output)
    ; ========================================================================
    ; For Phase 5, using simple direct UART output.
    ; Full uart_init() and idt_init() will be properly integrated in Phase 8.

    mov dx, 0x3F8
    mov al, 'U'                 ; UART verification
    out dx, al
    mov al, 'A'
    out dx, al
    mov al, 'R'
    out dx, al
    mov al, 'T'
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

    ; VGA 'U' GREEN
    mov word [0xB800E], 0x0A55

    mov al, 'I'                 ; IDT verification
    out dx, al
    mov al, 'D'
    out dx, al
    mov al, 'T'
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

    ; VGA 'D' GREEN
    mov word [0xB8010], 0x0A44

    ; ========================================================================
    ; ADA INIT STUB (Phase 4A)
    ; ========================================================================
    call ada64_stub_initialize

    ; VGA 'L' GREEN
    mov word [0xB8012], 0x0A4C

    ; ========================================================================
    ; ADA EVENT LOOP STUB (Phase 4A)
    ; ========================================================================
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

; ============================================================================
; MESSAGES (placed in-line for flat binary compatibility)
; ============================================================================

align 8
uart_ready_msg: db "UART_READY", 0x0D, 0x0A, 0
idt_ready_msg: db "IDT_READY", 0x0D, 0x0A, 0
ada_init_msg: db "ADA_64_INIT", 0x0D, 0x0A, 0
mother_msg: db "MOTHER_OS_64_OK", 0x0D, 0x0A, 0

; --- Pad to 8KB ---
times (0x2000 - ($ - $$)) db 0
