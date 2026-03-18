; ============================================================================
; OmniBus Bootloader - Stage 2 (FIXED & WORKING)
; Entry point: 0x7E00 (loaded by Stage 1)
; ============================================================================

[BITS 16]
[ORG 0x7E00]

stage2_start:
    cli
    cld

    ; ========================================================================
    ; Setup GDT (CORRECTED: 8 bytes per descriptor)
    ; ========================================================================

    lgdt [gdt_descriptor]

    ; ========================================================================
    ; Setup IDT (Interrupt Descriptor Table) - CRITICAL for protected mode
    ; ========================================================================

    call setup_idt

    ; ========================================================================
    ; Enter Protected Mode
    ; ========================================================================

    mov eax, cr0
    or al, 1                        ; Set PE bit
    mov cr0, eax

    ; Far jump to protected mode code (flushes pipeline & reloads CS)
    jmp 0x08:pmode_entry

    align 8

; ========================================================================
; Setup IDT with 256 dummy entries
; ========================================================================

setup_idt:
    ; IDT base at 0x7E00 + 0x200 = 0x8000 (after GDT)
    mov edi, idt_start
    xor eax, eax
    mov ecx, 256

.idt_loop:
    ; Build interrupt gate entry (8 bytes each)
    ; Bytes 0-1: Offset (low 16 bits) - points to dummy handler at 0
    ; Bytes 2-3: Selector (code segment = 0x08)
    ; Byte 4: Reserved = 0
    ; Byte 5: Type/DPL (0x8E = interrupt gate, DPL=0, present)
    ; Bytes 6-7: Offset (high 16 bits) - all 0 for address 0

    ; Word 0: offset low (0) + selector (0x08)
    mov word [edi], 0x0000
    mov word [edi+2], 0x08

    ; Byte 4: reserved
    mov byte [edi+4], 0x00

    ; Byte 5: type/flags (interrupt gate, present)
    mov byte [edi+5], 0x8E

    ; Bytes 6-7: offset high (0)
    mov word [edi+6], 0x0000

    add edi, 8
    loop .idt_loop

    ; Load IDT register
    mov eax, idt_descriptor
    lidt [eax]

    ret

; ========================================================================
; DATA: GDT - Global Descriptor Table (CORRECTED FORMAT)
; ========================================================================

align 8
gdt_start:

    ; Descriptor 0: NULL (REQUIRED - 8 bytes)
    dq 0x0000000000000000

    ; Descriptor 1: Code Segment (selector 0x08) - 8 bytes
    dw 0xFFFF                       ; Limit (bits 0-15)
    dw 0x0000                       ; Base (bits 0-15)
    db 0x00                         ; Base (bits 16-23)
    db 0x9A                         ; Access (present, ring0, code, readable)
    db 0xCF                         ; Flags (granular, 32-bit) + Limit high
    db 0x00                         ; Base (bits 24-31)

    ; Descriptor 2: Data Segment (selector 0x10) - 8 bytes
    dw 0xFFFF
    dw 0x0000
    db 0x00
    db 0x92                         ; Access (present, ring0, data, writable)
    db 0xCF
    db 0x00

gdt_end:

; GDT Descriptor (GDTR format)
align 8
gdt_descriptor:
    dw gdt_end - gdt_start - 1      ; Size (limit) = 23 bytes (3 descriptors * 8 - 1)
    dd 0x7E00 + (gdt_start - $$)    ; Base address (absolute: 0x7E00 + offset)

; ========================================================================
; DATA: IDT - Interrupt Descriptor Table
; ========================================================================

align 8
idt_start:
    ; 256 IDT entries × 8 bytes = 2048 bytes
    times 256 * 8 db 0

idt_descriptor:
    dw 256 * 8 - 1                  ; Size (limit)
    dd 0x7E00 + (idt_start - $$)    ; Base address (absolute: 0x7E00 + offset)

; ========================================================================
; PROTECTED MODE CODE (32-bit)
; ========================================================================

[BITS 32]

pmode_entry:
    ; Setup segment registers
    mov eax, 0x10                   ; Data segment selector
    mov ds, eax
    mov es, eax
    mov fs, eax
    mov gs, eax
    mov ss, eax

    ; Setup stack
    mov esp, 0x7F000

    ; ========================================================================
    ; SUCCESS! We're in protected mode without crashing
    ; Write confirmation to VGA memory
    ; ========================================================================

    mov eax, 0xB8000                ; VGA text buffer
    mov dword [eax], 0x4F574F50     ; "POW" in white/black
    mov dword [eax+4], 0x4F4B4F4F   ; "OK!" in white/black

    ; ========================================================================
    ; Infinite loop - kernel is ready!
    ; ========================================================================

    jmp $

; ========================================================================
; Padding to 8KB (sector 1-16)
; ========================================================================

times (0x2000 - ($ - $$)) db 0
