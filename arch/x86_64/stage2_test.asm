; ============================================================================
; OmniBus Stage 2 - Minimal Protected Mode Test
; Entry point: 0x7E00 (loaded by Stage 1)
; Strategy: Place all data inline with proper addressing
; ============================================================================

[BITS 16]
[ORG 0x7E00]

stage2_start:
    cli
    cld

    ; ========================================================================
    ; Setup real mode addressing: use DS=0 with absolute addresses
    ; ========================================================================
    xor ax, ax
    mov ds, ax
    mov es, ax

    ; ========================================================================
    ; Load GDT using absolute address (not segment-relative)
    ; LGDT expects: [address] as memory reference
    ; Since DS=0, we can use absolute address 0x7E00+offset as the operand
    ; ========================================================================

    ; Calculate GDT descriptor absolute address (this will be ~0x7E70 or so)
    ; We'll use: lea instruction to get the actual addressof gdt_descriptor
    mov eax, gdt_descriptor
    ; But LGDT requires memory operand, not immediate
    ; Instead, we'll be clever and use a pointer

    ; Actually, simplest approach: declare GDT early so address is known
    ; Let's use the following:

    lgdt [cs:gdt_descriptor]        ; Use code segment override to load from CS:offset
    lidt [cs:idt_descriptor]        ; Same for IDT

    ; ========================================================================
    ; Enter Protected Mode
    ; ========================================================================

    mov eax, cr0
    or eax, 1
    mov cr0, eax

    ; ========================================================================
    ; Far jump to protected mode
    ; ========================================================================

    jmp 0x08:0x7E00 + (pmode_entry - stage2_start)

; ========================================================================
; PROTECTED MODE (32-bit)
; ========================================================================

[BITS 32]

pmode_entry:
    ; Setup segment registers
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

    ; Setup stack
    mov esp, 0x7E000

    ; VGA output: "P"
    mov byte [0xB8000], 'P'
    mov byte [0xB8001], 0x0F

    ; Jump to kernel
    jmp 0x100030

; ========================================================================
; Return to 16-bit for data
; ========================================================================

[BITS 16]

; ========================================================================
; DATA SECTION (declare here for fixed offsets)
; ========================================================================

align 16

gdt_start:
    dq 0                            ; NULL descriptor

    ; Code segment
    dw 0xFFFF
    dw 0x0000
    db 0x00
    db 0x9A
    db 0xCF
    db 0x00

    ; Data segment
    dw 0xFFFF
    dw 0x0000
    db 0x00
    db 0x92
    db 0xCF
    db 0x00

gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1
    dd 0x7E00 + (gdt_start - stage2_start)

idt_start:
    times 256 * 8 db 0

idt_descriptor:
    dw 256 * 8 - 1
    dd 0x7E00 + (idt_start - stage2_start)

; ========================================================================
; Padding to 4KB
; ========================================================================

times (0x1000 - ($ - $$)) db 0
