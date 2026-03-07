; ============================================================================
; OmniBus Bootloader - Stage 2 UART DEBUG VERSION
; Uses COM1 serial port for debug output (guaranteed to show up)
; Entry point: 0x7E00 (loaded by Stage 1)
; ============================================================================

[BITS 16]
[ORG 0x7E00]

%define COM1 0x3F8

stage2_start:
    cli
    cld

    ; ========================================================================
    ; DEBUG: Send "S" to UART to confirm Stage 2 loaded
    ; ========================================================================
    mov al, 'S'
    mov dx, COM1
    out dx, al
    mov al, '2'
    out dx, al
    mov al, ':'
    out dx, al

    ; ========================================================================
    ; DEBUG: Send "L" - About to load GDT
    ; ========================================================================
    mov al, 'L'
    out dx, al

    ; ========================================================================
    ; Setup GDT (Global Descriptor Table)
    ; ========================================================================
    lgdt [gdt_descriptor]

    ; ========================================================================
    ; DEBUG: Send "G" - GDT loaded successfully
    ; ========================================================================
    mov al, 'G'
    out dx, al

    ; ========================================================================
    ; Setup minimal IDT
    ; ========================================================================
    call setup_idt

    ; ========================================================================
    ; DEBUG: Send "I" - IDT loaded successfully
    ; ========================================================================
    mov al, 'I'
    out dx, al

    ; ========================================================================
    ; DEBUG: Send "P" - About to set Protected Mode Enable bit
    ; ========================================================================
    mov al, 'P'
    out dx, al

    ; ========================================================================
    ; Enter Protected Mode
    ; ========================================================================
    mov eax, cr0
    or eax, 1                        ; Set PE bit
    mov cr0, eax

    ; ========================================================================
    ; DEBUG: Send "!" - Protected mode entry
    ; If we get here, CR0.PE didn't cause immediate hang
    ; ========================================================================
    mov al, '!'
    out dx, al

    ; Far jump to protected mode code (flushes pipeline & reloads CS)
    jmp 0x08:pmode_entry

    ; Should not reach here
    hlt

    align 8

; ========================================================================
; Setup IDT with 256 dummy entries
; ========================================================================

setup_idt:
    mov edi, idt_start
    xor eax, eax
    mov ecx, 256

.idt_loop:
    ; Build proper interrupt gate entry (8 bytes each)
    mov word [edi], 0x0000          ; Offset low
    mov word [edi+2], 0x08          ; Code segment selector
    mov byte [edi+4], 0x00          ; Reserved
    mov byte [edi+5], 0x8E          ; Type/DPL (interrupt gate)
    mov word [edi+6], 0x0000        ; Offset high

    add edi, 8
    loop .idt_loop

    ; Load IDT register
    lidt [idt_descriptor]

    ret

; ========================================================================
; DATA: GDT - Global Descriptor Table
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
    dw gdt_end - gdt_start - 1      ; Size (limit)
    dd gdt_start                    ; Base address

; ========================================================================
; DATA: IDT - Interrupt Descriptor Table
; ========================================================================

align 8
idt_start:
    ; 256 IDT entries × 8 bytes = 2048 bytes
    times 256 * 8 db 0

idt_descriptor:
    dw 256 * 8 - 1                  ; Size (limit)
    dd idt_start                    ; Base address

; ========================================================================
; PROTECTED MODE CODE (32-bit)
; ========================================================================

[BITS 32]

pmode_entry:
    ; ========================================================================
    ; If we reach here, protected mode entry succeeded!
    ; ========================================================================

    ; Setup segment registers
    mov eax, 0x10                   ; Data segment selector
    mov ds, eax
    mov es, eax
    mov fs, eax
    mov gs, eax
    mov ss, eax

    ; Setup stack
    mov esp, 0x7E000

    ; ========================================================================
    ; Print "OK" to VGA to confirm protected mode works
    ; ========================================================================

    mov eax, 0xB8000                ; VGA text buffer
    mov dword [eax], 0x4F4B4F50     ; "POK" at VGA
    mov dword [eax+4], 0x4F4F4F4D   ; "OOM" at VGA

    ; ========================================================================
    ; Infinite loop - kernel is ready!
    ; ========================================================================

    jmp $

; ========================================================================
; Padding to 4KB
; ========================================================================

times (0x1000 - ($ - $$)) db 0
