; ============================================================================
; OmniBus Phase 2 Paging Verification Kernel
; Standalone NASM test - no Ada/C dependencies
; Entry: 0x100030 (stage2 push/retf jumps here)
; Purpose: Verify 257-page identity mapping works, show breadcrumbs
; ============================================================================

[BITS 32]
[ORG 0x100000]

; ============================================================================
; HEADER (0x100000 - 0x10002F): Magic + padding
; Offset 0x00: ENDBR32 magic (0xF3 0x0F 0x1E 0xFA) - required by stage2 check
; Stage 2 verifies [0x8000] == 0xfa1e0ff3 before jumping to 0x100030
; ============================================================================
db 0xF3, 0x0F, 0x1E, 0xFA      ; ENDBR32 = magic signature (stage2 validity check)
times (0x30 - 4) db 0x90       ; Remaining 44 bytes of NOP padding

; ============================================================================
; STARTUP_BEGIN at 0x100030 (matches stage2 jump target)
; ============================================================================
startup_begin:

    ; === UART PROBE: 'K' = Kernel reached (before any paging) ===
    ; COM1 (0x3F8) is always ready in QEMU, no need to poll LSR
    mov dx, 0x3F8
    mov al, 'K'
    out dx, al

    ; === BREADCRUMB 'S' = Startup reached (yellow) ===
    mov word [0xB8000], 0x0E53

    ; === IDENTIFY: write SOMA marker ===
    mov eax, 0x414D4F53         ; "AMOS" reversed
    mov [0x100000], eax

    ; === STEP 1: Clear page directory @ 0x200000 (4KB, 1024 entries) ===
    mov edi, 0x200000
    xor eax, eax
    mov ecx, 1024
    rep stosd

    ; === UART PROBE: 'T' = Tables about to clear ===
    mov dx, 0x3F8
    mov al, 'T'
    out dx, al

    ; === BREADCRUMB 'T' = Tables cleared (yellow) ===
    mov word [0xB8002], 0x0E54

    ; === STEP 2: Clear first page table @ 0x201000 (4096 entries × 4 = 16KB) ===
    mov edi, 0x201000
    xor eax, eax
    mov ecx, 4096
    rep stosd

    ; === STEP 3: Set PDE[0] → page table @ 0x201000 (present + writable) ===
    mov dword [0x200000], 0x201003

    ; === STEP 4: Identity map 257 pages (0x000000 → 0x101000) ===
    ; CRITICAL: 256 pages only covers 0x000000–0x0FFFFF
    ; Page 257 covers 0x100000–0x100FFF (the KERNEL itself!)
    ; Without this page, enabling CR0.PG causes instant #PF triple fault
    mov edi, 0x201000           ; PTE base address
    mov eax, 0x000003           ; First page: phys 0x0000, present + writable
    mov ecx, 257                ; 257 pages = 1MB + 4KB
.map_kernel:
    mov [edi], eax
    add eax, 0x1000             ; Next physical page
    add edi, 4                  ; Next PTE slot
    loop .map_kernel

    ; === UART PROBE: 'C' = CR3 about to load ===
    mov dx, 0x3F8
    mov al, 'C'
    out dx, al

    ; === BREADCRUMB 'C' = CR3 about to load (yellow) ===
    mov word [0xB8004], 0x0E43

    ; === STEP 5: Load page directory base into CR3 ===
    mov eax, 0x200000
    mov cr3, eax

    ; === UART PROBE: 'R' = CR0.PG about to flip ===
    mov dx, 0x3F8
    mov al, 'R'
    out dx, al

    ; === BREADCRUMB 'R' = CR0.PG about to flip (yellow) ===
    mov word [0xB8006], 0x0E52

    ; === STEP 6: Enable paging (CR0 bit 31) ===
    mov eax, cr0
    or eax, 0x80000000
    mov cr0, eax

    ; === IF WE REACH HERE: PAGING WORKS! ===
    ; (A triple fault / reboot means kernel page wasn't mapped)

    ; === BREADCRUMB 'P' = Paging enabled (GREEN) ===
    mov word [0xB8008], 0x0A50  ; Green 'P'

    ; === BREADCRUMB 'I' = Idle / success (GREEN) ===
    mov word [0xB800A], 0x0A49  ; Green 'I'

    ; === BREADCRUMB 'L' = Loop / alive (GREEN) ===
    mov word [0xB800C], 0x0A4C  ; Green 'L'

    ; === UART: send "PAGING_OK\r\n" to COM1 (0x3F8) ===
    ; QEMU COM1 is always ready, no need to wait for TX empty
    mov dx, 0x3F8
    mov al, 'P' ; P
    out dx, al
    mov al, 'A'
    out dx, al
    mov al, 'G'
    out dx, al
    mov al, 'I'
    out dx, al
    mov al, 'N'
    out dx, al
    mov al, 'G'
    out dx, al
    mov al, '_'
    out dx, al
    mov al, 'O'
    out dx, al
    mov al, 'K'
    out dx, al
    mov al, 0x0D  ; CR
    out dx, al
    mov al, 0x0A  ; LF
    out dx, al

    ; === SUCCESS HALT ===
    ; VGA should show: S T C R (yellow) then P I L (green)
    ; Serial should show: PAGING_OK
    cli
.halt:
    hlt
    jmp .halt

; ============================================================================
; Pad to 8KB total (16 sectors × 512B, matches stage2 load count)
; ============================================================================
times (0x2000 - ($ - $$)) db 0
