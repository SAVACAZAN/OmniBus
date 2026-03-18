; MINIMAL Stage 2 - Just enter protected mode and jump to kernel
[BITS 16]
[ORG 0x7E00]

minimal_stage2:
    cli
    cld

    ; Load GDT
    lgdt [gdt_descriptor_addr]

    ; Load IDT
    lidt [idt_descriptor_addr]

    ; Enable protected mode
    mov eax, cr0
    or eax, 1
    mov cr0, eax

    ; Far jump to protected mode
    jmp 0x08:pmode_code

[BITS 32]
align 16

pmode_code:
    ; Setup segment registers
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

    ; Setup stack
    mov esp, 0x7E000

    ; Jump to Ada kernel
    jmp 0x100030

; Data section
align 16

; GDT
gdt_table:
    dq 0x0000000000000000  ; Null descriptor
    dq 0x00cf9a000000ffff  ; Code descriptor (CS=0x08)
    dq 0x00cf92000000ffff  ; Data descriptor (DS=0x10)

gdt_descriptor_addr:
    dw (3 * 8) - 1         ; Size = 24 bytes - 1
    dd gdt_table           ; Base

; IDT (minimal)
idt_table:
    times 256 * 8 db 0

idt_descriptor_addr:
    dw (256 * 8) - 1       ; Size = 2048 bytes - 1
    dd idt_table           ; Base

; Padding to 4KB
times (0x1000 - ($ - $$)) db 0
