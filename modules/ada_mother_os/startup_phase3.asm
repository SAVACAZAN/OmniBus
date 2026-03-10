; ============================================================================
; OmniBus Ada Mother OS - Phase 3 Rebuild
; startup_phase3.asm - Standalone kernel, no Ada/C object dependencies
; ============================================================================
; Layout (NASM flat binary, ORG 0x100000):
;
;   0x100000  ENDBR32 magic (stage2 validity check: cmp [0x8000], 0xfa1e0ff3)
;   0x100004  NOP padding × 44 bytes
;   0x100030  startup_begin  ← stage2 push/retf jumps here
;   0x100030+  257-page identity map, VGA breadcrumbs, UART probes
;   ...        Ada init stub, event loop stub
;
; Why standalone: Ada objects (ada_kernel.o, etc.) are compiled as x86_64
; (64-bit), but we're in 32-bit protected mode. REX-prefixed 64-bit instructions
; fault in 32-bit mode. Stubs stand in until Phase 4 adds long-mode transition.
;
; Build:  nasm -f bin -o kernel.bin startup_phase3.asm
; Load:   stage2 loads 16 sectors (8KB) from LBA 2048 → 0x8000 → 0x100000
; ============================================================================

[BITS 32]
[ORG 0x100000]

; ============================================================================
; HEADER: 0x100000 – 0x10002F (48 bytes)
; Stage2 checks: cmp dword [0x8000], 0xfa1e0ff3 → jne kernel_not_found
; ENDBR32 = F3 0F 1E FA → dword little-endian = 0xFA1E0FF3  ✓
; ============================================================================
db 0xF3, 0x0F, 0x1E, 0xFA          ; ENDBR32 magic (required by stage2)
times (0x30 - 4) db 0x90           ; 44 NOP bytes of padding

; ============================================================================
; STARTUP_BEGIN at 0x100030 (physical — matches stage2 push/retf target)
; ============================================================================
startup_begin:

    ; --- UART: 'K' = Kernel reached (first byte from this CPU context) ---
    mov dx, 0x3F8
    mov al, 'K'
    out dx, al

    ; --- VGA BREADCRUMB: 'S' = Startup begin (yellow 0x0E) ---
    mov word [0xB8000], 0x0E53

    ; --- IDENTIFY: write AMOS magic to 0x100000 header ---
    mov eax, 0x414D4F53             ; "AMOS"
    mov [0x100000], eax

    ; ========================================================================
    ; PAGING SETUP
    ; Identity map 0x000000–0x101000 (257 pages, 32-bit page tables)
    ; Page directory @ 0x200000, first page table @ 0x201000
    ; OS segment page tables @ 0x202000–0x204000
    ; ========================================================================

    ; Step 1: Clear page directory (4KB = 1024 × 4-byte entries)
    mov edi, 0x200000
    xor eax, eax
    mov ecx, 1024
    rep stosd

    ; Step 2: Clear first page table (16KB = 4096 × 4-byte entries)
    mov edi, 0x201000
    xor eax, eax
    mov ecx, 4096
    rep stosd

    ; --- UART: 'T' = Tables cleared ---
    mov dx, 0x3F8
    mov al, 'T'
    out dx, al

    ; --- VGA: 'T' = Tables cleared (yellow) ---
    mov word [0xB8002], 0x0E54

    ; Step 3: Populate page directory entries
    mov dword [0x200000], 0x201003  ; PDE[0] → 0x201000 (kernel identity)
    mov dword [0x200004], 0x202003  ; PDE[1] → 0x202000 (Grid OS)
    mov dword [0x200010], 0x204003  ; PDE[4] → 0x204000 (Execution OS)
    mov dword [0x200014], 0x203003  ; PDE[5] → 0x203000 (Analytics OS)

    ; Step 4: Identity map 257 pages (0x000000 – 0x101000)
    ; CRITICAL: page 257 covers 0x100000–0x100FFF = the kernel itself.
    ; Without it, CR0.PG causes immediate #PF triple fault.
    mov edi, 0x201000
    mov eax, 0x000003               ; Phys 0x000000, present + writable
    mov ecx, 257
.map_kernel:
    mov [edi], eax
    add eax, 0x1000
    add edi, 4
    loop .map_kernel

    ; Step 5: Map Grid OS (0x110000–0x12FFFF, 32 pages)
    mov edi, 0x202000
    mov eax, 0x110003
    mov ecx, 32
.map_grid:
    mov [edi], eax
    add eax, 0x1000
    add edi, 4
    loop .map_grid

    ; Step 6: Map Analytics OS (0x150000–0x1FFFFF, 128 pages)
    mov edi, 0x203000
    mov eax, 0x150003
    mov ecx, 128
.map_analytics:
    mov [edi], eax
    add eax, 0x1000
    add edi, 4
    loop .map_analytics

    ; Step 7: Map Execution OS (0x130000–0x14FFFF, 32 pages)
    mov edi, 0x204000
    mov eax, 0x130003
    mov ecx, 32
.map_execution:
    mov [edi], eax
    add eax, 0x1000
    add edi, 4
    loop .map_execution

    ; --- UART: 'C' = CR3 about to load ---
    mov dx, 0x3F8
    mov al, 'C'
    out dx, al

    ; --- VGA: 'C' = CR3 about to load (yellow) ---
    mov word [0xB8004], 0x0E43

    ; Step 8: Load CR3 (page directory base register)
    mov eax, 0x200000
    mov cr3, eax

    ; --- UART: 'R' = CR0.PG about to flip ---
    mov dx, 0x3F8
    mov al, 'R'
    out dx, al

    ; --- VGA: 'R' = CR0.PG about to flip (yellow) ---
    mov word [0xB8006], 0x0E52

    ; Step 9: Enable paging (CR0 bit 31)
    mov eax, cr0
    or eax, 0x80000000
    mov cr0, eax
    ; ← If we triple fault here → page not mapped. Should NOT happen with 257 pages.

    ; ========================================================================
    ; PAGING IS NOW ACTIVE — kernel running under identity-mapped virtual memory
    ; ========================================================================

    ; --- VGA: 'P' = Paging enabled (GREEN 0x0A) ---
    mov word [0xB8008], 0x0A50

    ; --- VGA: 'I' = About to call Initialize_kernel (GREEN) ---
    mov word [0xB800A], 0x0A49

    ; ========================================================================
    ; ADA INITIALIZE_KERNEL STUB CALL
    ; In Phase 3: Ada objects are x86_64 (64-bit code). Calling them from
    ; 32-bit protected mode would fault on REX-prefixed instructions.
    ; Stub simulates the call boundary: writes UART + returns cleanly.
    ; Phase 4: Add long-mode (64-bit) transition before calling real Ada code.
    ; ========================================================================
    call ada_stub_initialize

    ; --- VGA: 'L' = Event loop reached (GREEN) ---
    mov word [0xB800C], 0x0A4C

    ; ========================================================================
    ; ADA RUN_EVENT_LOOP STUB
    ; ========================================================================
    call ada_stub_event_loop

    ; Should never return from event loop
    ; --- VGA: 'X' = Unexpected return (RED 0x0C) ---
    mov word [0xB800E], 0x0C58
    cli
    hlt
    jmp $ - 2

; ============================================================================
; ADA INITIALIZE_KERNEL STUB
; Replaces ada_kernel__initialize_kernel for Phase 3 testing
; ============================================================================
ada_stub_initialize:
    ; UART: "ADA_INIT\r\n"
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

    ; Set Ada auth gate: write 0x70 to 0x100050 (Mother OS marker)
    mov byte [0x100050], 0x70
    ret

; ============================================================================
; ADA RUN_EVENT_LOOP STUB
; Replaces ada_kernel__run_event_loop for Phase 3 testing
; Writes UART "MOTHER_OS_OK\r\n" then halts
; ============================================================================
ada_stub_event_loop:
    ; UART: "MOTHER_OS_OK\r\n"
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
    mov al, 'O'
    out dx, al
    mov al, 'K'
    out dx, al
    mov al, 0x0D
    out dx, al
    mov al, 0x0A
    out dx, al

    cli
.halt:
    hlt
    jmp .halt

; ============================================================================
; Pad to 8KB (= 16 sectors × 512B = stage2 load size)
; ============================================================================
times (0x2000 - ($ - $$)) db 0
