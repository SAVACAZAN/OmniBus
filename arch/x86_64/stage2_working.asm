; ============================================================================
; OmniBus Bootloader - Stage 2 (Working Version)
; Entry point: 0x7E00 (loaded by Stage 1)
; Fixed: Proper real mode addressing before protected mode transition
; ============================================================================

[BITS 16]
[ORG 0x7E00]

stage2_start:
    cli
    cld

    ; ========================================================================
    ; Setup segment registers for Stage 2 code and data
    ; ========================================================================
    ; We're loaded at 0x7E00 with segment base 0x0000
    ; To access data at 0x7E00+offset, we need DS = 0x07E0

    mov ax, 0x07E0
    mov ds, ax
    mov es, ax

    ; Now [address] references are relative to DS:0x07E0
    ; So [0] means 0x07E0:0 = physical 0x7E00

    ; ========================================================================
    ; Setup GDT (Global Descriptor Table)
    ; ========================================================================

    lgdt [gdt_descriptor]
    lidt [idt_descriptor]

    ; ========================================================================
    ; Enter Protected Mode
    ; ========================================================================

    mov eax, cr0
    or eax, 1                        ; Set PE bit
    mov cr0, eax

    ; ========================================================================
    ; Far jump to protected mode (flushes pipeline & reloads CS)
    ; ========================================================================

    jmp 0x08:pmode_entry

; ========================================================================
; PROTECTED MODE CODE (immediately after far jump)
; ========================================================================

[BITS 32]

pmode_entry:
    ; ========================================================================
    ; Protected mode entry
    ; ========================================================================

    ; Setup segment registers (all point to data segment 0x10)
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

    ; Setup stack (use upper half of kernel memory)
    mov esp, 0x7E000

    ; ========================================================================
    ; Print "PMODE OK" to VGA to confirm protected mode works
    ; ========================================================================

    mov eax, 0xB8000                ; VGA text buffer
    mov byte [eax], 'P'             ; 'P'
    mov byte [eax+1], 0x0F          ; White on black
    mov byte [eax+2], 'M'           ; 'M'
    mov byte [eax+3], 0x0F
    mov byte [eax+4], 'O'           ; 'O'
    mov byte [eax+5], 0x0F
    mov byte [eax+6], 'K'           ; 'K'
    mov byte [eax+7], 0x0F

    ; ========================================================================
    ; Jump to Ada Kernel at 0x100030 (startup_begin)
    ; ========================================================================

    jmp 0x100030

; ========================================================================
; Return to 16-bit section for data definitions
; ========================================================================

[BITS 16]

; ========================================================================
; DATA: GDT - Global Descriptor Table (8 bytes per descriptor)
; ========================================================================

gdt_start:

    ; Descriptor 0: NULL (REQUIRED - must be 8 bytes!)
    dq 0x0000000000000000

    ; Descriptor 1: Code Segment (selector 0x08)
    dw 0xFFFF                       ; Limit (bits 0-15)
    dw 0x0000                       ; Base (bits 0-15)
    db 0x00                         ; Base (bits 16-23)
    db 0x9A                         ; Access: present | ring 0 | code | readable
    db 0xCF                         ; Flags: granular | 32-bit | limit(19:16)
    db 0x00                         ; Base (bits 24-31)

    ; Descriptor 2: Data Segment (selector 0x10)
    dw 0xFFFF
    dw 0x0000
    db 0x00
    db 0x92                         ; Access: present | ring 0 | data | writable
    db 0xCF                         ; Flags: granular | 32-bit | limit(19:16)
    db 0x00

gdt_end:

; GDT Descriptor (used by LGDT instruction)
gdt_descriptor:
    dw gdt_end - gdt_start - 1      ; Size (limit) in bytes - 1
    dd gdt_start                    ; Base address (use absolute address in descriptor)

; ========================================================================
; DATA: IDT - Interrupt Descriptor Table (minimal, 256 entries × 8 bytes)
; ========================================================================

idt_start:
    times 256 * 8 db 0

idt_descriptor:
    dw 256 * 8 - 1                  ; Size (limit) in bytes - 1
    dd idt_start                    ; Base address

; ========================================================================
; Padding to 4KB (required for 8-sector read = 4KB)
; ========================================================================

times (0x1000 - ($ - $$)) db 0
