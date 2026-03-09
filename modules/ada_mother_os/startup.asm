; Ada Mother OS Startup (x86-64 Protected Mode)
; ============================================
; Entry point: 0x100010 (from Bootloader Stage 2)
; Purpose: Initialize paging, GDT, IDT, then call Ada_Main
; Output: Control to Ada kernel main loop
;
; Assumptions:
; - Bootloader has already enabled protected mode (CR0.PE = 1)
; - We're in 32-bit protected mode
; - Stack is somewhere functional (set by bootloader)
; - Memory at 0x100000 is writable

bits 32
org 0x100010

; ============================================
; ADA MOTHER OS STARTUP CODE
; ============================================

startup_begin:
    ; === IDENTIFY OURSELVES ===
    mov eax, 0x414D4F53    ; "AMOS" (Ada Mother OS marker)
    mov [0x100000], eax    ; Write magic to kernel header

    ; === INITIALIZE PAGE TABLES ===
    ; Create page directory @ 0x200000 (64KB segment reserved)
    ; Create page tables @ 0x201000–0x20FFFF

    mov edi, 0x200000      ; EDI = page directory address

    ; Clear page directory (4KB)
    xor eax, eax
    mov ecx, 1024          ; 4KB / 4 bytes = 1024 entries
    rep stosd              ; Write 0 to all PDE

    ; Create page table @ 0x201000 (first page table for kernel)
    mov edi, 0x201000
    xor eax, eax
    mov ecx, 4096          ; 4096 entries per page table
    rep stosd

    ; === POPULATE PAGE DIRECTORY ===
    ; PDE[0] = 0x201000 | 0x03 (kernel page table, present + writable)
    mov dword [0x200000], 0x201003

    ; PDE[1] = 0x202000 | 0x03 (Grid OS page table)
    mov dword [0x200004], 0x202003

    ; PDE[5] = 0x203000 | 0x03 (Analytics OS page table)
    mov dword [0x200014], 0x203003

    ; PDE[4] = 0x204000 | 0x03 (Execution OS page table)
    mov dword [0x200010], 0x204003

    ; === POPULATE PAGE TABLES ===
    ; Map kernel: 0x100000 → 0x10FFFF (16 pages)
    mov edi, 0x201000
    mov eax, 0x000003     ; Physical address 0x0000, present + writable
    mov ecx, 256
    .map_kernel:
        mov [edi], eax
        add eax, 0x1000   ; Next 4KB page
        add edi, 4
        loop .map_kernel

    ; Map Grid OS: 0x110000 → 0x12FFFF (32 pages)
    mov edi, 0x202000
    mov eax, 0x110003
    mov ecx, 32
    .map_grid:
        mov [edi], eax
        add eax, 0x1000
        add edi, 4
        loop .map_grid

    ; Map Analytics OS: 0x150000 → 0x1FFFFF (128 pages)
    mov edi, 0x203000
    mov eax, 0x150003
    mov ecx, 128
    .map_analytics:
        mov [edi], eax
        add eax, 0x1000
        add edi, 4
        loop .map_analytics

    ; Map Execution OS: 0x130000 → 0x14FFFF (32 pages)
    mov edi, 0x204000
    mov eax, 0x130003
    mov ecx, 32
    .map_execution:
        mov [edi], eax
        add eax, 0x1000
        add edi, 4
        loop .map_execution

    ; === MAP I/O SPACE ===
    ; Map UART @ 0x3F8 (for debug output)
    ; I/O addresses stay at 0x3F8 (no paging for I/O ports in simple setup)
    ; In production, you'd use memory-mapped I/O

    ; === ENABLE PAGING ===
    mov eax, 0x200000     ; EAX = page directory address
    mov cr3, eax          ; Load CR3 (page directory base)

    mov eax, cr0
    or eax, 0x80000000    ; Set CR0.PG (bit 31)
    mov cr0, eax          ; Enable paging

    ; === JUMP TO CONTINUE INITIALIZATION ===
    lea eax, [rel after_paging]
    jmp eax

after_paging:
    ; === SETUP GDT ===
    ; GDT @ 0x100400 (in kernel segment, managed by Ada later)
    ; For now, use existing GDT from Bootloader
    ;
    ; Bootloader already set up a minimal GDT:
    ; - Selector 0x00: Null
    ; - Selector 0x08: Code (0x0–0xFFFFFFFF, present, ring 0)
    ; - Selector 0x10: Data (0x0–0xFFFFFFFF, present, ring 0)

    ; === SETUP IDT ===
    ; IDT @ 0x100400 (256 gates × 8 bytes = 2KB)
    ; For now, leave as stub (Ada will populate in Ada_Main)

    ; === UART OUTPUT ===
    ; Print startup message via UART (0x3F8)
    mov eax, 0x4B524550   ; "KPREP" (Kernel Preparation)

    ; Send 'K' to UART
    mov al, 'K'
    mov dx, 0x3F8
    out dx, al

    mov al, 'R'
    out dx, al

    mov al, 'N'
    out dx, al

    mov al, '\n'
    out dx, al

    ; === CALL ADA MAIN ===
    ; Ada_Main is linked @ 0x100020 (after this startup code)
    ; Call it as a function: push return address, jmp
    push exit_kernel      ; Return address (should not return)
    lea eax, [rel ada_main_entry]
    jmp eax

exit_kernel:
    ; If Ada_Main returns (shouldn't happen), halt
    cli
    hlt
    jmp exit_kernel

; Placeholder for external Ada_Main (linked by Ada compiler)
; This will be resolved by the linker
ada_main_entry:
    ; This address will be filled by linker with Ada_Main location
    ; The GNAT runtime will create this symbol
    extern ada_main
    jmp ada_main

startup_end:
    align 0x100

; ============================================
; PROTECTED SYMBOLS FOR LINKER
; ============================================
global startup_begin
global startup_end

; ============================================
; END OF STARTUP CODE (~150 bytes)
; ============================================
