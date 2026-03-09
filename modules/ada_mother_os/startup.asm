; Ada Mother OS Startup (x86-64 Protected Mode)
; ============================================
; Entry point: startup_begin (to be linked at 0x100010)
; Purpose: Initialize paging, GDT, IDT, then call Ada_Main
; Output: Control to Ada kernel main loop

SECTION .text
BITS 32

GLOBAL startup_begin
EXTERN ada_kernel__initialize_kernel
EXTERN ada_kernel__run_event_loop

startup_begin:
    ; === IDENTIFY OURSELVES ===
    mov eax, 0x414D4F53        ; "AMOS" (Ada Mother OS marker)
    mov [0x100000], eax        ; Write magic to kernel header

    ; === INITIALIZE PAGE TABLES ===
    ; Create page directory @ 0x200000 (64KB segment reserved)
    ; Create page tables @ 0x201000–0x20FFFF

    mov edi, 0x200000          ; EDI = page directory address

    ; Clear page directory (4KB)
    xor eax, eax
    mov ecx, 1024              ; 4KB / 4 bytes = 1024 entries
    rep stosd                  ; Write 0 to all PDE

    ; Create page table @ 0x201000 (first page table for kernel)
    mov edi, 0x201000
    xor eax, eax
    mov ecx, 4096              ; 4096 entries per page table
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
    mov eax, 0x000003         ; Physical address 0x0000, present + writable
    mov ecx, 256
.map_kernel:
    mov [edi], eax
    add eax, 0x1000           ; Next 4KB page
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

    ; === ENABLE PAGING ===
    mov eax, 0x200000         ; EAX = page directory address
    mov cr3, eax              ; Load CR3 (page directory base)

    mov eax, cr0
    or eax, 0x80000000        ; Set CR0.PG (bit 31)
    mov cr0, eax              ; Enable paging

    ; === CALL ADA KERNEL ===
    ; Call Initialize_Kernel to set up kernel state
    call ada_kernel__initialize_kernel

    ; Call Run_Event_Loop (should never return)
    call ada_kernel__run_event_loop

    ; If Run_Event_Loop returns (shouldn't happen), halt
    cli
    hlt
    jmp $ - 2

; ============================================
; END OF STARTUP CODE
; ============================================
