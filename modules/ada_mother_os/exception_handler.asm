; ============================================================================
; exception_handler.asm — Phase 8C: Real Exception Handler Implementations
;
; Called from idt.asm common_handler routine with:
;   RDI = exception vector number
;   RSI = error code (or dummy)
;
; Implements centralized exception handling with UART logging
; ============================================================================

[BITS 64]

; ============================================================================
; EXCEPTION HANDLER — Called from common_handler
; ============================================================================

global handle_exception
handle_exception:
    ; RDI = vector, RSI = error code (already saved in common_handler)
    ; Save RDI/RSI for UART output
    push rdi
    push rsi
    push rdx

    mov dx, 0x3F8               ; UART port

    ; Output 'E' prefix for exception
    mov al, 'E'
    out dx, al

    ; Output exception vector as hex digit (0-F only for now)
    mov rax, rdi
    and al, 0x0F                ; Mask to 4 bits
    cmp al, 9
    jle .exc_digit
    add al, 'A' - 10
    jmp .exc_send
.exc_digit:
    add al, '0'
.exc_send:
    out dx, al

    ; Output error code as two hex digits
    mov al, 'C'
    out dx, al

    mov rax, rsi
    shr al, 4                   ; High nibble
    cmp al, 9
    jle .err_high_digit
    add al, 'A' - 10
    jmp .err_high_send
.err_high_digit:
    add al, '0'
.err_high_send:
    out dx, al

    mov rax, rsi
    and al, 0x0F                ; Low nibble
    cmp al, 9
    jle .err_low_digit
    add al, 'A' - 10
    jmp .err_low_send
.err_low_digit:
    add al, '0'
.err_low_send:
    out dx, al

    ; Output CRLF
    mov al, 0x0D
    out dx, al
    mov al, 0x0A
    out dx, al

    pop rdx
    pop rsi
    pop rdi
    ret

; ============================================================================
; IRQ HANDLER — Called from irq_handler_common
; ============================================================================

global handle_irq
handle_irq:
    ; RDI = IRQ number
    push rdi
    push rdx

    mov dx, 0x3F8               ; UART port

    ; Output 'I' prefix for IRQ
    mov al, 'I'
    out dx, al

    ; Output IRQ number as hex (0-F)
    mov rax, rdi
    and al, 0x0F
    cmp al, 9
    jle .irq_digit
    add al, 'A' - 10
    jmp .irq_send
.irq_digit:
    add al, '0'
.irq_send:
    out dx, al

    ; Output CRLF
    mov al, 0x0D
    out dx, al
    mov al, 0x0A
    out dx, al

    ; Send EOI (End of Interrupt) to PIC
    ; For now, just return (Phase 8C: EOI handling deferred to Phase 8D)

    pop rdx
    pop rdi
    ret
