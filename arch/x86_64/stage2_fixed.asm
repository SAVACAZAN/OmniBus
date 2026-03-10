; ============================================================================
; OmniBus Bootloader - Stage 2 (Fixed Protected Mode Entry)
; Entry point: 0x7E00 (loaded by Stage 1)
; Fixed: Use register-indirect addressing to avoid segment base doubling
; ============================================================================

[BITS 16]
[ORG 0x7E00]

entry:
    ; 1. Ensure segments are synchronized
    cli
    cld
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00                ; Stack safely below Stage 2

    ; 2. Calculate linear address of GDT descriptor using register
    ; This avoids NASM displacement assumptions
    mov bx, gdt_descriptor
    lgdt [bx]

    ; 3. Load IDT descriptor similarly
    mov bx, idt_descriptor
    lidt [bx]

    ; 4. Enter Protected Mode
    mov eax, cr0
    or eax, 1                      ; Set PE bit
    mov cr0, eax

    ; 5. Far jump to clear prefetch queue and reload CS
    jmp 0x08:pm_entry

[BITS 32]

pm_entry:
    ; 6. Update data segments for protected mode
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

    ; 7. Setup stack in protected mode
    mov esp, 0x7E000

    ; 8. Visual confirmation: Write "PM OK" to VGA buffer
    ; This proves we successfully entered protected mode
    mov dword [0xB8000], 0x0F4F0F50   ; "PO" in white
    mov dword [0xB8004], 0x0F4B0F4D   ; "MK" in white

    ; 9. Jump to Ada Kernel at 0x100030
    jmp 0x100030

; ========================================================================
; DATA SECTION - GDT Definition
; ========================================================================

align 16

gdt_start:
    dq 0x0                          ; Null descriptor (required)

gdt_code:
    ; Code segment (selector 0x08)
    ; Base: 0x00000000, Limit: 0xFFFFF, Type: Code, Present, Ring 0, 32-bit
    dw 0xFFFF                       ; Limit (bits 0-15)
    dw 0x0000                       ; Base (bits 0-15)
    db 0x00                         ; Base (bits 16-23)
    db 0x9A                         ; P=1, DPL=0, S=1, Type=1010 (code)
    db 0xCF                         ; G=1 (granular), DB=1 (32-bit), Limit(19:16)=1111
    db 0x00                         ; Base (bits 24-31)

gdt_data:
    ; Data segment (selector 0x10)
    ; Base: 0x00000000, Limit: 0xFFFFF, Type: Data, Present, Ring 0, 32-bit
    dw 0xFFFF
    dw 0x0000
    db 0x00
    db 0x92                         ; P=1, DPL=0, S=1, Type=0010 (data)
    db 0xCF                         ; G=1 (granular), DB=1 (32-bit), Limit(19:16)=1111
    db 0x00

gdt_end:

; GDT Descriptor (for LGDT instruction)
gdt_descriptor:
    dw gdt_end - gdt_start - 1      ; Limit (size - 1)
    dd gdt_start                    ; Base address (absolute linear address)

; ========================================================================
; IDT Definition (minimal, filled with zeros)
; ========================================================================

idt_start:
    ; 256 IDT entries × 8 bytes = 2048 bytes (all zeros for now)
    times 256 * 8 db 0

idt_descriptor:
    dw 256 * 8 - 1                  ; Limit (size - 1)
    dd idt_start                    ; Base address

; ========================================================================
; Padding to 4KB (required by Stage 1 which reads 8 sectors)
; ========================================================================

times (0x1000 - ($ - $$)) db 0
