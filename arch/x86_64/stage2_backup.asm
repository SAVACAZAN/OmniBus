; ============================================================================
; OmniBus Bootloader - Stage 2 (Minimal, Working Version)
; Entry point: 0x7E00
; ============================================================================

[BITS 16]
[ORG 0x7E00]

    cli
    cld

    ; Print confirmation
    mov si, msg1
    call print

    ; Build GDT at 0x7E00 + 100 (data area)
    mov di, gdt_table

    ; Null descriptor
    xor eax, eax
    stosd
    stosd

    ; Code descriptor (base 0, limit 0xFFFFFFFF)
    mov eax, 0x00009A00
    stosd
    mov eax, 0x000000CF
    stosd

    ; Data descriptor
    mov eax, 0x00009200
    stosd
    mov eax, 0x000000CF
    stosd

    ; Setup GDTR
    mov eax, 0x7E00 + gdt_offset
    mov [gdtr + 2], eax             ; Set base address
    mov ax, 23                      ; Size = 3*8 - 1
    mov [gdtr], ax

    ; Load GDT
    lgdt [gdtr]

    ; Enable protected mode
    mov eax, cr0
    or al, 1
    mov cr0, eax

    ; Jump to protected mode
    jmp 0x08:pmode

    align 4
    gdtr: dd 0, 0
    gdt_offset equ 100
    gdt_table:

; ============================================================================
; PROTECTED MODE
; ============================================================================

[BITS 32]

pmode:
    mov eax, 0x10
    mov ds, eax
    mov es, eax
    mov ss, eax
    mov fs, eax
    mov gs, eax

    mov esp, 0x7F000

    ; Write to VGA to show we're here
    mov dword [0xB8000], 0x4F524F50  ; "POR" in magenta

    ; Infinite loop
    jmp $

; ========================================================================
; 16-bit print function
; ========================================================================

[BITS 16]

print:
    mov ah, 0x0E
.loop:
    lodsb
    test al, al
    jz .done
    int 0x10
    jmp .loop
.done:
    ret

msg1: db "Stage2 running...", 0

; ========================================================================
; Padding
; ========================================================================

times (0x2000 - ($ - $$)) db 0
