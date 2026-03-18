; ============================================================================
; uart.asm — Phase 8: UART Serial Driver (115200 baud, 8-N-1)
;
; Port 0x3F8 = COM1 (default serial port)
; Standard registers:
;   +0: THR (Transmit Holding Register) / RBR (Receive Buffer Register)
;   +1: IER (Interrupt Enable Register)
;   +2: FCR (FIFO Control Register)
;   +3: LCR (Line Control Register)
;   +4: MCR (Modem Control Register)
;   +5: LSR (Line Status Register) — bit 6 = THRE (transmit empty), bit 0 = DR (data ready)
;   +6: MSR (Modem Status Register)
;   +7: SCR (Scratch Register)
; ============================================================================

[BITS 64]

; ============================================================================
; UART Port Addresses
; ============================================================================

UART_PORT equ 0x3F8        ; COM1 base port
UART_THR equ (UART_PORT + 0)    ; Transmit Holding Register
UART_RBR equ (UART_PORT + 0)    ; Receive Buffer Register
UART_IER equ (UART_PORT + 1)    ; Interrupt Enable Register
UART_FCR equ (UART_PORT + 2)    ; FIFO Control Register
UART_LCR equ (UART_PORT + 3)    ; Line Control Register
UART_MCR equ (UART_PORT + 4)    ; Modem Control Register
UART_LSR equ (UART_PORT + 5)    ; Line Status Register
UART_MSR equ (UART_PORT + 6)    ; Modem Status Register

; Divisor for baud rate: divisor = 115200 / desired_baud
; For 115200 baud: divisor = 1
UART_DIVISOR equ 1

; LSR bit masks
UART_LSR_DR equ 0x01       ; Data Ready
UART_LSR_OE equ 0x02       ; Overrun Error
UART_LSR_PE equ 0x04       ; Parity Error
UART_LSR_FE equ 0x08       ; Framing Error
UART_LSR_BI equ 0x10       ; Break Interrupt
UART_LSR_THRE equ 0x20     ; Transmit Holding Register Empty
UART_LSR_TEMT equ 0x40     ; Transmitter Empty

; Removed .data section for flat binary compatibility
; Data will be placed inline in code section
uart_initialized: db 0
align 16

; ============================================================================
; UART INITIALIZATION (115200 baud, 8 data bits, 1 stop bit, no parity)
; ============================================================================

global uart_init
uart_init:
    ; Save register
    push rax
    push rdx

    ; Disable interrupts (IER = 0x00)
    mov al, 0x00
    mov dx, UART_IER
    out dx, al

    ; Enable DLAB (Divisor Latch Access Bit) in LCR
    mov al, 0x80                ; LCR: DLAB=1
    mov dx, UART_LCR
    out dx, al

    ; Set divisor latch (for 115200 baud)
    mov ax, UART_DIVISOR
    mov dx, UART_PORT           ; DLL (divisor low byte)
    out dx, al
    mov al, ah                  ; DLM (divisor high byte)
    mov dx, (UART_PORT + 1)
    out dx, al

    ; Clear DLAB and set to 8-N-1 (8 bits, no parity, 1 stop bit)
    mov al, 0x03                ; LCR: 8 data bits, 1 stop bit, no parity, DLAB=0
    mov dx, UART_LCR
    out dx, al

    ; Enable FIFO (FCR = 0xC7)
    mov al, 0xC7                ; FCR: FIFO enable, clear buffers, set threshold to 14 bytes
    mov dx, UART_FCR
    out dx, al

    ; Enable RTS/DTR (MCR = 0x0B)
    mov al, 0x0B                ; MCR: RTS=1, DTR=1
    mov dx, UART_MCR
    out dx, al

    mov byte [uart_initialized], 1

    pop rdx
    pop rax
    ret

; ============================================================================
; UART TRANSMIT CHARACTER (RDI = character)
; ============================================================================

global uart_putchar
uart_putchar:
    ; RDI contains character to send
    push rax
    push rdx
    push rcx

    mov al, dil                 ; Character in AL

.wait_thre:
    ; Wait for THRE (Transmit Holding Register Empty)
    mov dx, UART_LSR
    in al, dx
    test al, UART_LSR_THRE      ; Test THRE bit
    jz .wait_thre

    ; Send character
    mov al, dil                 ; Restore character
    mov dx, UART_THR
    out dx, al

    pop rcx
    pop rdx
    pop rax
    ret

; ============================================================================
; UART RECEIVE CHARACTER → RAX (returns -1 if no data ready)
; ============================================================================

global uart_getchar
uart_getchar:
    push rdx

    ; Check Data Ready bit
    mov dx, UART_LSR
    in al, dx
    test al, UART_LSR_DR        ; Test DR bit
    jz .no_data

    ; Read character
    mov dx, UART_RBR
    xor eax, eax
    in al, dx                   ; AL = character
    movzx rax, al
    jmp .done

.no_data:
    mov rax, -1                 ; No data available

.done:
    pop rdx
    ret

; ============================================================================
; UART SEND STRING (RDI = pointer to null-terminated string)
; ============================================================================

global uart_send_string
uart_send_string:
    push rax
    push rdi

.loop:
    movzx eax, byte [rdi]       ; Load character
    test al, al                 ; Check for null terminator
    jz .done

    mov rdi, rax
    call uart_putchar           ; Send character

    pop rdi
    inc rdi                      ; Next character
    push rdi
    jmp .loop

.done:
    pop rdi
    pop rax
    ret

; ============================================================================
; UART WRITE HEX (RDI = 64-bit value to output as hex)
; ============================================================================

global uart_write_hex
uart_write_hex:
    push rax
    push rcx
    push rdx
    push rsi

    mov rax, rdi                ; Value in RAX
    mov rcx, 64                 ; 64 bits to process
    mov rsi, rax

.hex_loop:
    sub rcx, 4                  ; Process 4 bits at a time
    mov rax, rsi
    shr rax, cl
    and al, 0x0F                ; Mask to 4 bits

    ; Convert to ASCII hex
    cmp al, 9
    jle .digit
    add al, 'A' - 10
    jmp .send_hex
.digit:
    add al, '0'

.send_hex:
    mov rdi, rax
    call uart_putchar

    cmp rcx, 0
    jg .hex_loop

    pop rsi
    pop rdx
    pop rcx
    pop rax
    ret

; ============================================================================
; UART WRITE 8-BIT HEX (RDI = 8-bit value to output as hex)
; ============================================================================

global uart_write_hex8
uart_write_hex8:
    push rax
    push rcx
    push rdx
    push rsi

    movzx eax, dil              ; Zero-extend AL to RAX
    mov rsi, rax

    ; High nibble
    mov al, sil
    shr al, 4
    and al, 0x0F
    cmp al, 9
    jle .digit_high
    add al, 'A' - 10
    jmp .send_high
.digit_high:
    add al, '0'
.send_high:
    mov rdi, rax
    call uart_putchar

    ; Low nibble
    mov al, sil
    and al, 0x0F
    cmp al, 9
    jle .digit_low
    add al, 'A' - 10
    jmp .send_low
.digit_low:
    add al, '0'
.send_low:
    mov rdi, rax
    call uart_putchar

    pop rsi
    pop rdx
    pop rcx
    pop rax
    ret

; ============================================================================
; UART WRITE NEWLINE (CR + LF)
; ============================================================================

global uart_newline
uart_newline:
    push rdi
    mov rdi, 0x0D               ; CR
    call uart_putchar
    mov rdi, 0x0A               ; LF
    call uart_putchar
    pop rdi
    ret

; ============================================================================
; UART WRITE 32-BIT VALUE AS DECIMAL (RDI = value)
; ============================================================================

global uart_write_dec32
uart_write_dec32:
    push rax
    push rcx
    push rdx
    push rsi
    push rdi

    mov eax, edi                ; Value in EAX
    mov rcx, 0                  ; Count of digits

    ; Handle zero special case
    test eax, eax
    jnz .count_digits

    mov rdi, '0'
    call uart_putchar
    jmp .done_dec

.count_digits:
    mov rsi, 10
    mov ecx, 0

.count_loop:
    xor edx, edx
    div esi                     ; EAX / 10, remainder in EDX
    inc rcx
    test eax, eax
    jnz .count_loop

    ; Restore value and print digits
    mov eax, edi
    mov rsi, 10

.print_digits:
    xor edx, edx
    div esi
    push rdx                    ; Push digit
    dec rcx
    jnz .print_digits
    push rdx                    ; Push last digit

.print_loop:
    pop rax
    add al, '0'
    mov rdi, rax
    call uart_putchar
    loop .print_loop

.done_dec:
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rax
    ret

; ============================================================================
; UART WRITE SPACE
; ============================================================================

global uart_write_space
uart_write_space:
    push rdi
    mov rdi, ' '
    call uart_putchar
    pop rdi
    ret

; ============================================================================
; UART IS READY? (Returns 1 if initialized, 0 otherwise)
; ============================================================================

global uart_is_ready
uart_is_ready:
    xor eax, eax
    mov al, byte [uart_initialized]
    movzx rax, al
    ret
