; ============================================================================
; OmniBus Bootloader - Stage 2 (FIXED - Working Protected Mode)
; Entry point: 0x7E00 (loaded by Stage 1)
; Goal: Successfully transition to protected mode without crashing
; ============================================================================

[BITS 16]
[ORG 0x7E00]

    cli
    cld

    ; Print "Stage2 starting" in real mode
    mov ax, 0xB800
    mov es, ax
    xor di, di
    mov byte [es:di], 'S'
    mov byte [es:di+2], '2'
    mov byte [es:di+4], ':'

    ; ========================================================================
    ; Setup GDT (Global Descriptor Table)
    ; ========================================================================

    mov eax, gdt_ptr
    lgdt [eax]

    ; ========================================================================
    ; Setup IDT (Interrupt Descriptor Table) - CRITICAL
    ; ========================================================================

    ; For now, setup a minimal IDT with all entries pointing to a dummy handler
    call setup_idt

    ; ========================================================================
    ; Enter Protected Mode
    ; ========================================================================

    mov eax, cr0
    or al, 1                       ; Set PE (Protected Mode Enable)
    mov cr0, eax

    ; Jump to protected mode (flush pipeline)
    jmp 0x08:pmode_entry

    ; Pad rest of 16-bit code
    align 256

; ========================================================================
; Setup IDT - Create 256 empty interrupt gates
; ========================================================================

setup_idt:
    ; IDT will be at 0x7E00 + 0x100
    mov edi, idt_start
    xor eax, eax

    ; Create 256 IDT entries (8 bytes each = 2048 bytes)
    mov ecx, 256
.idt_loop:
    ; Each IDT entry (interrupt gate):
    ; Offset 0-1: Handler offset (low 16 bits)  → 0x0000
    ; Offset 2-3: Code segment selector       → 0x08
    ; Offset 4: Reserved                       → 0x00
    ; Offset 5: Type + flags (0x8E = interrupt gate) → 0x8E
    ; Offset 6-7: Handler offset (high 16 bits) → 0x0000

    mov dword [edi], 0x0000008E00
    mov dword [edi+4], 0x00000000

    add edi, 8
    loop .idt_loop

    ; Load IDTR
    mov eax, idt_descriptor
    lidt [eax]

    ret

; ========================================================================
; DATA: GDT Descriptor Table
; ========================================================================

align 8
gdt_start:
    ; Descriptor 0: NULL
    dq 0x0000000000000000

    ; Descriptor 1: Code Segment (selector 0x08)
    dw 0xFFFF                       ; Limit (low)
    dw 0x0000                       ; Base (low)
    db 0x00                         ; Base (middle)
    db 0x9A                         ; Type: Code
    db 0xCF                         ; Flags
    db 0x00                         ; Base (high)

    ; Descriptor 2: Data Segment (selector 0x10)
    dw 0xFFFF
    dw 0x0000
    db 0x00
    db 0x92                         ; Type: Data
    db 0xCF
    db 0x00

gdt_end:

gdt_ptr:
    dw gdt_end - gdt_start - 1
    dd gdt_start

; ========================================================================
; DATA: IDT Descriptor
; ========================================================================

align 8
idt_start:
    ; Space for 256 IDT entries (256 * 8 = 2048 bytes)
    times 256 * 8 db 0

idt_descriptor:
    dw 256 * 8 - 1                  ; Limit
    dd idt_start                    ; Base

; ========================================================================
; PROTECTED MODE CODE (32-bit)
; ========================================================================

[BITS 32]

pmode_entry:
    ; Setup segment registers
    mov ax, 0x10                    ; Data segment selector
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

    ; Setup stack in protected mode
    mov esp, 0x7E000

    ; ========================================================================
    ; Print confirmation to VGA
    ; ========================================================================

    mov eax, 0xB8000                ; VGA memory
    mov dword [eax], 0x4F334F50     ; "P3" in white on black
    mov dword [eax+4], 0x4F4F4F4F   ; "OOOO"

    ; ========================================================================
    ; Infinite loop - we're in protected mode!
    ; ========================================================================

    jmp $                           ; Halt here

; ========================================================================
; Padding
; ========================================================================

times (0x2000 - ($ - $$)) db 0
