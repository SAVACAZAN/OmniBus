; ============================================================================
; OmniBus Kernel Stub (Ada Mother OS Entry Point)
; Located at: 0x100000 (1MB mark)
; Purpose: Stub that validates Stage 2 worked, prepares for Ada kernel
; ============================================================================

[BITS 64]
[ORG 0x100000]

kernel_stub:
    ; We're in 64-bit long mode!

    ; Setup a basic IDT (Interrupt Descriptor Table) for now
    ; IDT at 0x100100

    ; Print to VGA: "Kernel@1MB"
    mov rax, 0x000000000000004B    ; 'K'
    mov [0xB8028], ax

    mov rax, 0x0000000000000065    ; 'e'
    mov [0xB802A], ax

    mov rax, 0x0000000000000072    ; 'r'
    mov [0xB802C], ax

    mov rax, 0x000000000000006E    ; 'n'
    mov [0xB802E], ax

    ; Setup UART for debugging at 0x3F8 (COM1)
    mov dx, 0x3F8 + 1              ; Line Control Register
    mov al, 0x80                   ; Divisor Latch Access Bit
    out dx, al

    ; Set baud rate divisor to 1 (115200 baud)
    mov dx, 0x3F8                  ; DLL
    mov al, 0x01
    out dx, al

    mov dx, 0x3F8 + 1              ; DLM
    mov al, 0x00
    out dx, al

    ; LCR: 8 bits, no parity, 1 stop bit
    mov dx, 0x3F8 + 3
    mov al, 0x03
    out dx, al

    ; Write "O" to UART to confirm kernel is running
    mov al, 'O'
    mov dx, 0x3F8
    out dx, al

    ; Infinite loop
    jmp $

    ; Padding to fill kernel stub area
    times (0x1000 - ($ - $$)) db 0
