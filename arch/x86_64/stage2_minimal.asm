; ============================================================================
; Stage 2: MINIMAL WORKING VERSION
; Just transition to protected mode and stay alive
; ============================================================================

[BITS 16]
[ORG 0x7E00]

    cli

    ; Load minimal GDT
    lgdt [gdt_descriptor]

    ; Enter protected mode
    mov eax, cr0
    or eax, 1
    mov cr0, eax

    ; Far jump to 32-bit code
    jmp 0x08:pmode

    ; GDT
    align 8
    gdt:
        dq 0                        ; Null
        dw 0xFFFF,0,0x9A,0xCF      ; Code
        dw 0xFFFF,0,0x92,0xCF      ; Data
    gdt_end:

    gdt_descriptor:
        dw gdt_end - gdt - 1
        dd gdt

    align 256

[BITS 32]

pmode:
    mov ax, 0x10
    mov ds, ax
    mov ss, ax
    mov esp, 0x7F000

    ; Infinite loop
    jmp $

    times (0x2000 - ($ - $$)) db 0
