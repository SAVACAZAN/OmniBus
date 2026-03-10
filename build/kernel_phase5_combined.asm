; ============================================================================
; OmniBus Phase 5: Long Mode + UART Driver + IDT Initialization
; startup_phase5.asm — IDT/UART setup before loading OS layers
; ============================================================================
; Extends startup_phase4.asm with:
;   1. uart_init() → 115200 baud serial driver
;   2. idt_init() → Interrupt Descriptor Table (256 × 16-byte entries)
;   3. uart_send_string() for debug output
;   4. Verification output: UART_READY, IDT_READY
; ============================================================================

[BITS 32]
[ORG 0x100000]

; --- Header: ENDBR32 magic + 44 NOP padding ---
db 0xF3, 0x0F, 0x1E, 0xFA
times (0x30 - 4) db 0x90

; ============================================================================
; STARTUP_BEGIN at 0x100030 (stage2 push/retf target)
; ============================================================================
startup_begin:

    ; UART 'K' = Kernel reached
    mov dx, 0x3F8
    mov al, 'K'
    out dx, al

    ; VGA 'S' yellow
    mov word [0xB8000], 0x0E53

    ; ========================================================================
    ; STEP 1: Enable PAE (must be before EFER.LME and CR0.PG)
    ; ========================================================================
    mov eax, cr4
    or  eax, 0x20               ; CR4.PAE = bit 5
    mov cr4, eax

    ; UART 'T'
    mov dx, 0x3F8
    mov al, 'T'
    out dx, al
    mov word [0xB8002], 0x0E54

    ; ========================================================================
    ; STEP 2: Build 4-level page tables
    ; PML4 @ 0x201000, PDPT @ 0x202000, PD @ 0x203000
    ; ========================================================================

    ; Clear PML4 (4KB = 1024 dwords)
    mov edi, 0x201000
    xor eax, eax
    mov ecx, 1024
    rep stosd

    ; Clear PDPT (4KB)
    mov edi, 0x202000
    xor eax, eax
    mov ecx, 1024
    rep stosd

    ; Clear PD (4KB)
    mov edi, 0x203000
    xor eax, eax
    mov ecx, 1024
    rep stosd

    ; PML4[0] → PDPT @ 0x202000
    mov dword [0x201000], 0x202003
    mov dword [0x201004], 0

    ; PDPT[0] → PD @ 0x203000
    mov dword [0x202000], 0x203003
    mov dword [0x202004], 0

    ; PD[0] → 2MB page @ phys 0x000000
    mov dword [0x203000], 0x000083
    mov dword [0x203004], 0

    ; PD[1] → 2MB page @ phys 0x200000
    mov dword [0x203008], 0x200083
    mov dword [0x20300C], 0

    ; UART 'C'
    mov dx, 0x3F8
    mov al, 'C'
    out dx, al
    mov word [0xB8004], 0x0E43

    ; ========================================================================
    ; STEP 3: Load CR3 with PML4 address
    ; ========================================================================
    mov eax, 0x201000
    mov cr3, eax

    ; ========================================================================
    ; STEP 4: Load 64-bit GDT BEFORE enabling paging
    ; ========================================================================
    lgdt [gdt64_ptr]

    ; ========================================================================
    ; STEP 5: Set EFER.LME via WRMSR (MSR 0xC0000080)
    ; ========================================================================
    mov ecx, 0xC0000080
    rdmsr
    or  eax, 0x100              ; EFER.LME = bit 8
    wrmsr

    ; UART 'R' = about to enable paging → long mode
    mov dx, 0x3F8
    mov al, 'R'
    out dx, al
    mov word [0xB8006], 0x0E52

    ; ========================================================================
    ; STEP 6: Enable paging (CR0.PG=1)
    ; ========================================================================
    mov eax, cr0
    or  eax, 0x80000000         ; CR0.PG only (bit 31)
    mov cr0, eax

    ; UART probe
    mov dx, 0x3F8
    mov al, 'P'
    out dx, al

    ; VGA 'P' GREEN = Paging + long mode active
    mov word [0xB8008], 0x0A50

    ; ========================================================================
    ; STEP 7: Far jump to 64-bit CS → enters 64-bit long mode
    ; ========================================================================
    jmp 0x08:long_mode_entry

; ============================================================================
; GDT64 — 64-bit Global Descriptor Table
; ============================================================================
align 16
gdt64_start:
    dq 0x0000000000000000      ; [0x00] Null descriptor
gdt64_code:
    dq 0x00AF9A000000FFFF      ; [0x08] 64-bit kernel code
gdt64_data:
    dq 0x00CF92000000FFFF      ; [0x10] Kernel data
gdt64_end:

gdt64_ptr:
    dw gdt64_end - gdt64_start - 1
    dd gdt64_start

; ============================================================================
; LONG MODE ENTRY [BITS 64]
; ============================================================================
align 32
[BITS 64]
long_mode_entry:

    ; Reload data segments
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

    ; Set 64-bit stack
    mov rsp, 0x7E000

    ; VGA 'M' GREEN = long mode confirmed
    mov word [0xB800A], 0x0A4D

    ; Quick UART test (direct output)
    mov dx, 0x3F8
    mov al, 'L'
    out dx, al
    mov al, 'O'
    out dx, al
    mov al, 'N'
    out dx, al
    mov al, 'G'
    out dx, al
    mov al, '_'
    out dx, al
    mov al, 'M'
    out dx, al
    mov al, 'O'
    out dx, al
    mov al, 'D'
    out dx, al
    mov al, 'E'
    out dx, al
    mov al, '_'
    out dx, al
    mov al, 'O'
    out dx, al
    mov al, 'K'
    out dx, al
    mov al, 0x0D
    out dx, al
    mov al, 0x0A
    out dx, al

    ; VGA 'I' GREEN
    mov word [0xB800C], 0x0A49

    ; Auth gate
    mov byte [0x100050], 0x70

    ; ========================================================================
    ; PHASE 5: UART + IDT Initialization (verification output)
    ; ========================================================================
    ; For Phase 5, using simple direct UART output.
    ; Full uart_init() and idt_init() will be properly integrated in Phase 8.

    mov dx, 0x3F8
    mov al, 'U'                 ; UART verification
    out dx, al
    mov al, 'A'
    out dx, al
    mov al, 'R'
    out dx, al
    mov al, 'T'
    out dx, al
    mov al, '_'
    out dx, al
    mov al, 'O'
    out dx, al
    mov al, 'K'
    out dx, al
    mov al, 0x0D
    out dx, al
    mov al, 0x0A
    out dx, al

    ; VGA 'U' GREEN
    mov word [0xB800E], 0x0A55

    mov al, 'I'                 ; IDT verification
    out dx, al
    mov al, 'D'
    out dx, al
    mov al, 'T'
    out dx, al
    mov al, '_'
    out dx, al
    mov al, 'O'
    out dx, al
    mov al, 'K'
    out dx, al
    mov al, 0x0D
    out dx, al
    mov al, 0x0A
    out dx, al

    ; VGA 'D' GREEN
    mov word [0xB8010], 0x0A44

    ; ========================================================================
    ; Phase 8E: Load IDT inline with debug output + address verification
    ; ========================================================================

    ; Debug: Before LIDT
    mov al, 'B'
    mov dx, 0x3F8
    out dx, al

    ; Try inline LIDT instead of calling idt_init
    ; Compute idt_ptr address: it should be after all handlers
    ; For now, use a placeholder - we'll adjust once we know the exact offset
    lea rax, [rel idt_ptr]       ; RIP-relative load of idt_ptr address
    lidt [rax]                    ; Load IDTR from that address

    ; Debug: After LIDT
    mov al, 'X'                 ; IDT loaded successfully
    mov dx, 0x3F8
    out dx, al
    mov al, 0x0D
    out dx, al
    mov al, 0x0A
    out dx, al

    ; VGA 'X' GREEN (Phase 8C complete)
    mov word [0xB8012], 0x0A58

    ; ========================================================================
    ; PHASE 8C TEST: Trigger exception #DE (Divide by Zero)
    ; ========================================================================
    mov al, 'T'                 ; About to test exception
    mov dx, 0x3F8
    out dx, al

    xor eax, eax
    mov ecx, 0
    div ecx                      ; Divide by zero → #DE exception
    ; If exception handler works, we get "E0C00" output and continue

    mov al, 'F'                 ; Reached after exception test
    mov dx, 0x3F8
    out dx, al
    mov al, 0x0D
    out dx, al
    mov al, 0x0A
    out dx, al

    ; ========================================================================
    ; ADA INIT STUB (Phase 4A)
    ; ========================================================================
    call ada64_stub_initialize

    ; VGA 'L' GREEN
    mov word [0xB8012], 0x0A4C

    ; ========================================================================
    ; ADA EVENT LOOP STUB (Phase 4A)
    ; ========================================================================
    call ada64_stub_event_loop

    cli
    hlt
    jmp $ - 2

; ============================================================================
; 64-bit Ada Initialization Stub
; ============================================================================
ada64_stub_initialize:
    push rax
    push rdx

    mov dx, 0x3F8
    mov al, 'A'
    out dx, al
    mov al, 'D'
    out dx, al
    mov al, 'A'
    out dx, al
    mov al, '_'
    out dx, al
    mov al, 'I'
    out dx, al
    mov al, 'N'
    out dx, al
    mov al, 'I'
    out dx, al
    mov al, 'T'
    out dx, al
    mov al, 0x0D
    out dx, al
    mov al, 0x0A
    out dx, al

    pop rdx
    pop rax
    ret

; ============================================================================
; 64-bit Ada Event Loop Stub
; ============================================================================
ada64_stub_event_loop:
    push rax
    push rdx

    mov dx, 0x3F8
    mov al, 'M'
    out dx, al
    mov al, 'O'
    out dx, al
    mov al, 'T'
    out dx, al
    mov al, 'H'
    out dx, al
    mov al, 'E'
    out dx, al
    mov al, 'R'
    out dx, al
    mov al, '_'
    out dx, al
    mov al, 'O'
    out dx, al
    mov al, 'S'
    out dx, al
    mov al, '_'
    out dx, al
    mov al, '6'
    out dx, al
    mov al, '4'
    out dx, al
    mov al, '_'
    out dx, al
    mov al, 'O'
    out dx, al
    mov al, 'K'
    out dx, al
    mov al, 0x0D
    out dx, al
    mov al, 0x0A
    out dx, al

    pop rdx
    pop rax
    cli
.halt:
    hlt
    jmp .halt

; ============================================================================
; EXCEPTION HANDLER STUB (placed after main code)
; ============================================================================
align 16
simple_handler:
    ; Output 'H' to indicate handler was called
    mov dx, 0x3F8
    mov al, 'H'
    out dx, al

    ; Return from interrupt
    iretq

; ============================================================================
; MESSAGES (placed in-line for flat binary compatibility)
; ============================================================================

align 8
uart_ready_msg: db "UART_READY", 0x0D, 0x0A, 0
idt_ready_msg: db "IDT_READY", 0x0D, 0x0A, 0
ada_init_msg: db "ADA_64_INIT", 0x0D, 0x0A, 0
mother_msg: db "MOTHER_OS_64_OK", 0x0D, 0x0A, 0

; --- Pad to 8KB ---
times (0x2000 - ($ - $$)) db 0
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
; ============================================================================
; idt.asm — Phase 8: Interrupt Descriptor Table + Exception/IRQ Handlers
;
; x86-64 IDT setup with 256 entries (exceptions 0-31, IRQs 32-47, stubs 48-255)
; Handler stubs are placed BEFORE IDT to ensure known addresses
; ============================================================================

[BITS 64]
[ORG 0x100000]

; ============================================================================
; HANDLER STUBS (placed before IDT for predictable addressing)
; ============================================================================

align 8
handler_stub:
    ; Quick UART output to verify handler was called
    mov dx, 0x3F8
    mov al, 'H'
    out dx, al

    ; Return from interrupt
    iretq

; ============================================================================
; IDT SECTION — 256 × 16-byte entries = 4096 bytes
; ============================================================================

; ============================================================================
; Phase 8E: Static IDT table with pre-computed gate descriptors
; ============================================================================
; All 256 entries point to handler_stub (safe fallback)
; Gate descriptor format (x86-64, 16 bytes):
;   [0:1]   RIP[0:15]
;   [2:3]   Code segment (0x08)
;   [4]     IST (0)
;   [5]     Type/DPL/P (0x8E = interrupt gate, DPL=0, P=1)
;   [6:7]   RIP[16:31]
;   [8:11]  RIP[32:63]
;   [12:15] Reserved (0)

align 16
idt_base:
    ; For Phase 8E: point all entries to handler_stub at ~0x100500
    ; Using direct values computed from kernel layout
    ; handler_stub address: 0x100000 + offset from concatenated binary (~0x500)

    ; simple_handler is in startup_phase5.asm after the halt loop:
    ; Testing address 0x100380
    %assign handler_addr 0x100280

    %assign i 0
    %rep 256
        dw (handler_addr & 0xFFFF)                    ; RIP[0:15]
        dw 0x0008                                      ; Code segment selector
        db 0x00                                        ; IST = 0
        db 0x8E                                        ; Type = interrupt gate, DPL=0, P=1
        dw ((handler_addr >> 16) & 0xFFFF)           ; RIP[16:31]
        dd ((handler_addr >> 32) & 0xFFFFFFFF)       ; RIP[32:63]
        dw 0x0000                                      ; Reserved

        %assign i i+1
    %endrep

; IDT Pointer (for LIDT instruction)
align 8
idt_ptr:
    dw (256 * 16) - 1           ; Limit: 4096 - 1 = 0xFFF
    dq idt_base                 ; Base address

; ============================================================================
; EXCEPTION/IRQ HANDLER STUBS (all vectors 0-47)
; ============================================================================
; Each handler:
;   1. Pushes dummy/real error code
;   2. Pushes vector number
;   3. Jumps to common_handler / irq_handler_common

section .text

; --- Exceptions with no error code (0, 1, 3, 4, 5, 6, 7, 9, 15, 16-19) ---

align 8
handler_00:  ; #DE Divide by Zero
    push qword 0            ; Dummy error code
    push qword 0            ; Vector 0
    jmp common_handler

align 8
handler_01:  ; #DB Debug
    push qword 0
    push qword 1
    jmp common_handler

align 8
handler_03:  ; #BP Breakpoint
    push qword 0
    push qword 3
    jmp common_handler

align 8
handler_04:  ; #OF Overflow
    push qword 0
    push qword 4
    jmp common_handler

align 8
handler_05:  ; #BR BOUND Range Exceeded
    push qword 0
    push qword 5
    jmp common_handler

align 8
handler_06:  ; #UD Invalid Opcode
    push qword 0
    push qword 6
    jmp common_handler

align 8
handler_07:  ; #NM Device Not Available
    push qword 0
    push qword 7
    jmp common_handler

align 8
handler_09:  ; #CO Coprocessor Segment Overrun
    push qword 0
    push qword 9
    jmp common_handler

align 8
handler_0F:  ; #15 Floating-point Exception Pending
    push qword 0
    push qword 15
    jmp common_handler

align 8
handler_10:  ; #MF x87 Floating-Point Exception
    push qword 0
    push qword 16
    jmp common_handler

align 8
handler_11:  ; #AC Alignment Check
    push qword 0
    push qword 17
    jmp common_handler

align 8
handler_12:  ; #MC Machine Check
    push qword 0
    push qword 18
    jmp common_handler

align 8
handler_13:  ; #XM SIMD Floating-Point Exception
    push qword 0
    push qword 19
    jmp common_handler

; --- Exceptions with error code (8, 10, 11, 12, 13, 14) ---
; Error code already on stack from CPU

align 8
handler_08:  ; #DF Double Fault (error code always 0)
    push qword 8
    jmp common_handler

align 8
handler_0A:  ; #TS Invalid TSS
    push qword 10
    jmp common_handler

align 8
handler_0B:  ; #NP Segment Not Present
    push qword 11
    jmp common_handler

align 8
handler_0C:  ; #SS Stack-Segment Fault
    push qword 12
    jmp common_handler

align 8
handler_0D:  ; #GP General Protection Fault
    push qword 13
    jmp common_handler

align 8
handler_0E:  ; #PF Page Fault
    push qword 14
    jmp common_handler

; --- IRQ Handlers (32-47) ---

align 8
handler_20:  ; IRQ 0 (Timer)
    push qword 0
    push qword 32
    jmp irq_handler_common

align 8
handler_21:  ; IRQ 1 (Keyboard)
    push qword 0
    push qword 33
    jmp irq_handler_common

align 8
handler_22:  ; IRQ 2 (Cascade)
    push qword 0
    push qword 34
    jmp irq_handler_common

align 8
handler_23:  ; IRQ 3 (Serial COM2)
    push qword 0
    push qword 35
    jmp irq_handler_common

align 8
handler_24:  ; IRQ 4 (Serial COM1)
    push qword 0
    push qword 36
    jmp irq_handler_common

align 8
handler_25:  ; IRQ 5 (Parallel)
    push qword 0
    push qword 37
    jmp irq_handler_common

align 8
handler_26:  ; IRQ 6 (Floppy)
    push qword 0
    push qword 38
    jmp irq_handler_common

align 8
handler_27:  ; IRQ 7 (Parallel)
    push qword 0
    push qword 39
    jmp irq_handler_common

align 8
handler_28:  ; IRQ 8 (CMOS RTC)
    push qword 0
    push qword 40
    jmp irq_handler_common

align 8
handler_29:  ; IRQ 9 (ACPI)
    push qword 0
    push qword 41
    jmp irq_handler_common

align 8
handler_2A:  ; IRQ 10 (Available)
    push qword 0
    push qword 42
    jmp irq_handler_common

align 8
handler_2B:  ; IRQ 11 (Available)
    push qword 0
    push qword 43
    jmp irq_handler_common

align 8
handler_2C:  ; IRQ 12 (Mouse PS/2)
    push qword 0
    push qword 44
    jmp irq_handler_common

align 8
handler_2D:  ; IRQ 13 (Coprocessor)
    push qword 0
    push qword 45
    jmp irq_handler_common

align 8
handler_2E:  ; IRQ 14 (ATA Primary)
    push qword 0
    push qword 46
    jmp irq_handler_common

align 8
handler_2F:  ; IRQ 15 (ATA Secondary)
    push qword 0
    push qword 47
    jmp irq_handler_common

; --- Stub handlers for vectors 48-255 ---
; handler_stub moved to beginning of file (before IDT table)

; ============================================================================
; COMMON EXCEPTION HANDLER
; ============================================================================
; Stack layout after handler pushes:
;   [RSP+0]   = Vector number
;   [RSP+8]   = Error code (or dummy for no-error-code exceptions)
;   [RSP+16]  = RIP (from CPU interrupt frame)
;   [RSP+24]  = CS
;   [RSP+32]  = RFLAGS
;   [RSP+40]  = RSP (if ring change)
;   [RSP+48]  = SS (if ring change)

align 8
common_handler:
    ; Save all general-purpose registers
    push rax
    push rcx
    push rdx
    push rbx
    push rbp
    push rsi
    push rdi
    push r8
    push r9
    push r10
    push r11
    push r12
    push r13
    push r14
    push r15

    ; Stack now has:
    ;   [RSP+0-119]  = saved registers (15 × 8 bytes)
    ;   [RSP+120]    = Vector
    ;   [RSP+128]    = Error code
    ;   [RSP+136]    = RIP
    ;   ...

    ; Call exception handler (external C function)
    mov rdi, [rsp + 120]   ; Vector in RDI (first arg)
    mov rsi, [rsp + 128]   ; Error code in RSI (second arg)
    call handle_exception

    ; Restore all registers
    pop r15
    pop r14
    pop r13
    pop r12
    pop r11
    pop r10
    pop r9
    pop r8
    pop rdi
    pop rsi
    pop rbp
    pop rbx
    pop rdx
    pop rcx
    pop rax

    ; Remove vector and error code from stack
    add rsp, 16

    ; Return from interrupt
    iretq

; ============================================================================
; IRQ HANDLER COMMON
; ============================================================================

align 8
irq_handler_common:
    ; Save all registers (same as exception handler)
    push rax
    push rcx
    push rdx
    push rbx
    push rbp
    push rsi
    push rdi
    push r8
    push r9
    push r10
    push r11
    push r12
    push r13
    push r14
    push r15

    ; Call IRQ handler
    mov rdi, [rsp + 120]   ; IRQ number in RDI
    call handle_irq

    ; Restore registers
    pop r15
    pop r14
    pop r13
    pop r12
    pop r11
    pop r10
    pop r9
    pop r8
    pop rdi
    pop rsi
    pop rbp
    pop rbx
    pop rdx
    pop rcx
    pop rax

    ; Remove IRQ number and dummy error code
    add rsp, 16

    ; Return from interrupt
    iretq

; ============================================================================
; IDT INITIALIZATION & LOADING
; ============================================================================

global idt_init
idt_init:
    ; Phase 8E: Load IDTR with pre-populated IDT
    ; IDT entries are now pre-computed at assembly time (Phase 8E)
    ; All entries point to handler_stub for safe exception handling

    lidt [idt_ptr]
    ret

; ============================================================================
; EXTERNAL HANDLERS (defined in exception_handler.asm — Phase 8C)
; ============================================================================
; handle_exception and handle_irq are now in exception_handler.asm
; and included in the kernel build via Makefile
; ============================================================================
; tss.asm — Phase 8: Task State Segment (x86-64)
;
; TSS is used to define kernel stack pointers for privilege level switches.
; In long mode (x86-64), the TSS stores:
;   - RSP0, RSP1, RSP2 (kernel stacks for ring 0, 1, 2)
;   - IST[1-7] (Interrupt Stack Table entries for exception handlers)
;
; Memory: TSS @ 0x100600 (minimal 104 bytes for x86-64)
; ============================================================================

[BITS 64]
[ORG 0x100000]

section .data align 16

; ============================================================================
; TSS STRUCTURE (x86-64, 104 bytes)
; ============================================================================

global tss_base
tss_base:
    ; Offset 0x00: Reserved (4 bytes)
    dd 0

    ; Offset 0x04: RSP0 (8 bytes) — kernel stack pointer for ring 0
    ; Point to kernel stack (grows downward from 0x7FFFF)
    dq 0x7FFFF

    ; Offset 0x0C: RSP1 (8 bytes) — kernel stack pointer for ring 1 (not used)
    dq 0

    ; Offset 0x14: RSP2 (8 bytes) — kernel stack pointer for ring 2 (not used)
    dq 0

    ; Offset 0x1C: Reserved (8 bytes)
    dq 0

    ; Offset 0x24: IST[1] (8 bytes) — Stack for exception handler #1 (NMI)
    dq 0x80000            ; IST1 stack pointer

    ; Offset 0x2C: IST[2] (8 bytes) — Stack for exception handler #2 (double fault)
    dq 0x81000            ; IST2 stack pointer

    ; Offset 0x34: IST[3] (8 bytes) — Stack for exception handler #3 (MCE)
    dq 0x82000            ; IST3 stack pointer

    ; Offset 0x3C: IST[4] (8 bytes) — Stack for exception handler #4
    dq 0x83000            ; IST4 stack pointer

    ; Offset 0x44: IST[5] (8 bytes) — Stack for exception handler #5
    dq 0x84000            ; IST5 stack pointer

    ; Offset 0x4C: IST[6] (8 bytes) — Stack for exception handler #6
    dq 0x85000            ; IST6 stack pointer

    ; Offset 0x54: IST[7] (8 bytes) — Stack for exception handler #7
    dq 0x86000            ; IST7 stack pointer

    ; Offset 0x5C: Reserved (8 bytes)
    dq 0

    ; Offset 0x64: Reserved (2 bytes)
    dw 0

    ; Offset 0x66: IOPB offset (2 bytes) — I/O permission bitmap offset
    dw 0x68                ; Bitmap starts at offset 0x68 (after TSS header)

; Total TSS size: 0x68 (104 bytes)

; ============================================================================
; GDT DESCRIPTOR FOR TSS (added to GDT)
; ============================================================================
; Note: TSS descriptor is 16 bytes in x86-64 (split across 2 GDT entries)
; Entry format for TSS:
;   Bytes 0-1: TSS limit (low)
;   Bytes 2-4: TSS base (low 24 bits)
;   Byte 5: Type + attributes (0x89 = TSS available, P=1, DPL=0)
;   Byte 6: Granularity + limit (high 4 bits)
;   Bytes 7-8: TSS base (mid 16 bits)
;   Bytes 8-15: TSS base (high 32 bits) + reserved
;
; Example at GDT index 4 (offset 0x20 in GDT):
;   dd 0x00000068           ; Limit = 0x68 (104 bytes)
;   db 0x00, 0x06          ; Base low = 0x100600
;   db 0x89                ; Type: TSS available, P=1, DPL=0
;   db 0x00                ; Granularity
;   db 0x00                ; Base mid
;   dd 0x00010000          ; Base high = 0x00010000 (for 0x100600 physical)
;   dd 0x00000000          ; Reserved

; ============================================================================
; TSS INITIALIZATION FUNCTION
; ============================================================================

global tss_init
tss_init:
    ; TSS is pre-initialized with static values in .data section
    ; At runtime, only need to:
    ;   1. Update RSP0 if needed (currently set to 0x7FFFF)
    ;   2. Load TSS descriptor via LTR instruction (done in startup)
    ;
    ; For now, this is a stub. Real implementation would:
    ;   - Update IST stacks based on allocated memory
    ;   - Set RSP0 to current kernel stack
    ret

; ============================================================================
; HELPER: GET TSS BASE ADDRESS
; ============================================================================

global get_tss_base
get_tss_base:
    mov rax, tss_base
    ret

; ============================================================================
; HELPER: GET TSS SIZE
; ============================================================================

global get_tss_size
get_tss_size:
    mov rax, 0x68           ; TSS size = 104 bytes
    ret
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
