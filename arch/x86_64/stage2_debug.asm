; ============================================================================
; OmniBus Bootloader - Stage 2 DEBUG VERSION
; Entry point: 0x7E00 (loaded by Stage 1)
; Debug output at each step to identify hang location
; ============================================================================

[BITS 16]
[ORG 0x7E00]

stage2_start:
    cli
    cld

    ; ========================================================================
    ; DEBUG: Print "S2:" to VGA to confirm Stage 2 loaded
    ; ========================================================================
    mov ax, 0xB800
    mov es, ax
    xor di, di
    mov byte [es:di], 'S'
    mov byte [es:di+1], 0x0F         ; White text
    mov byte [es:di+2], '2'
    mov byte [es:di+3], 0x0F
    mov byte [es:di+4], ':'
    mov byte [es:di+5], 0x0F
    mov byte [es:di+6], ' '
    mov byte [es:di+7], 0x0F

    ; ========================================================================
    ; DEBUG: Print "GDT" - About to load GDT
    ; ========================================================================
    mov byte [es:di+8], 'G'
    mov byte [es:di+9], 0x0F
    mov byte [es:di+10], 'D'
    mov byte [es:di+11], 0x0F
    mov byte [es:di+12], 'T'
    mov byte [es:di+13], 0x0F

    ; ========================================================================
    ; Setup GDT (Global Descriptor Table)
    ; ========================================================================
    lgdt [gdt_descriptor]

    ; ========================================================================
    ; DEBUG: Print "OK" - GDT loaded successfully
    ; ========================================================================
    mov byte [es:di+14], 'O'
    mov byte [es:di+15], 0x0F
    mov byte [es:di+16], 'K'
    mov byte [es:di+17], 0x0F

    ; ========================================================================
    ; Setup minimal IDT - just enough to not triple-fault
    ; ========================================================================
    call setup_idt

    ; ========================================================================
    ; DEBUG: Print "PE" - About to set Protected Mode Enable bit
    ; ========================================================================
    mov byte [es:di+18], ' '
    mov byte [es:di+19], 0x0F
    mov byte [es:di+20], 'P'
    mov byte [es:di+21], 0x0F
    mov byte [es:di+22], 'E'
    mov byte [es:di+23], 0x0F

    ; ========================================================================
    ; Enter Protected Mode
    ; ========================================================================
    mov eax, cr0
    or eax, 1                        ; Set PE bit
    mov cr0, eax

    ; ========================================================================
    ; DEBUG: This point may not be reached if CR0.PE causes immediate hang
    ; Far jump to protected mode code (flushes pipeline & reloads CS)
    ; ========================================================================
    jmp 0x08:pmode_entry

    ; Should not reach here
    hlt

    align 8

; ========================================================================
; Setup IDT with 256 dummy entries
; All entries point to address 0x0000 (invalid, but won't trigger unless interrupt occurs)
; ========================================================================

setup_idt:
    mov edi, idt_start
    xor eax, eax
    mov ecx, 256

.idt_loop:
    ; Build proper interrupt gate entry (8 bytes each)
    ; Bytes 0-1: Offset (low 16 bits) = 0x0000
    mov word [edi], 0x0000
    ; Bytes 2-3: Code segment selector = 0x08
    mov word [edi+2], 0x08
    ; Byte 4: Reserved = 0x00
    mov byte [edi+4], 0x00
    ; Byte 5: Type/DPL (0x8E = interrupt gate, DPL=0, present)
    mov byte [edi+5], 0x8E
    ; Bytes 6-7: Offset (high 16 bits) = 0x0000
    mov word [edi+6], 0x0000

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
    dd gdt_start                    ; Base address (let NASM resolve absolute)

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
    ; DEBUG: If we reach here, protected mode entry succeeded!
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
    ; Print "PMODE!" to VGA to confirm protected mode works
    ; ========================================================================

    mov eax, 0xB8000                ; VGA text buffer
    mov dword [eax], 0x4F574F50     ; "POW" in white
    mov dword [eax+4], 0x4F4B4F4F   ; "OK!" in white
    mov dword [eax+8], 0x4F454D4F   ; "EMED" (4 bytes to fill space)

    ; ========================================================================
    ; Infinite loop - kernel is ready!
    ; ========================================================================

    jmp $

; ========================================================================
; Padding to 4KB (sector 1-8)
; ========================================================================

times (0x1000 - ($ - $$)) db 0
