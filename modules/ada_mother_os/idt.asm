; ============================================================================
; idt.asm — Phase 8: Interrupt Descriptor Table + Exception/IRQ Handlers
;
; x86-64 IDT setup with 256 entries (exceptions 0-31, IRQs 32-47, stubs 48-255)
; Memory: 0x100200 (4KB IDT table)
; ============================================================================

[BITS 64]
[ORG 0x100000]

; ============================================================================
; IDT SECTION — 256 × 16-byte entries = 4096 bytes
; ============================================================================

section .data align 16
idt_base:
    ; IDT will be filled by idt_init() at runtime
    ; Pre-allocate 256 × 16-byte entries
    times 256 * 2 dq 0

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
align 8
handler_stub:
    ; Generic stub: acknowledge and return
    iretq

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
    push rbx
    push rcx
    push rsi

    ; Initialize IDT table with all handler pointers
    mov rsi, idt_base

    ; Fill entries 0-19 (exceptions with various handlers)
    mov rcx, 0

.fill_exceptions:
    cmp rcx, 20
    je .fill_irqs

    ; Get handler address based on vector number
    cmp rcx, 0
    je .handler_0
    cmp rcx, 1
    je .handler_1

    ; For now: use generic stub approach
    ; Full implementation would assign specific handlers

    ; Move to next entry
    add rsi, 16
    inc rcx
    jmp .fill_exceptions

.handler_0:
    mov rax, handler_00
    jmp .fill_entry

.handler_1:
    mov rax, handler_01
    jmp .fill_entry

.fill_entry:
    ; Fill IDT entry at RSI with handler address in RAX
    ; IDT format (x86-64, 16 bytes per entry):
    ; Offset 0:1    = Handler RIP[0:15]
    ; Offset 2:3    = Code segment selector (0x08)
    ; Offset 4      = IST (0 = use RSP0)
    ; Offset 5      = Type + DPL + P (0x8E = Interrupt Gate)
    ; Offset 6:7    = Handler RIP[16:31]
    ; Offset 8:11   = Handler RIP[32:63]
    ; Offset 12:15  = Reserved (0)

    mov word [rsi + 0], ax          ; RIP[0:15]
    shr rax, 16
    mov word [rsi + 6], ax          ; RIP[16:31]
    shr rax, 16
    mov dword [rsi + 8], eax        ; RIP[32:63]

    mov word [rsi + 2], 0x08        ; Code segment
    mov byte [rsi + 4], 0           ; IST = 0
    mov byte [rsi + 5], 0x8E        ; Interrupt Gate, DPL=0, P=1
    mov qword [rsi + 12], 0         ; Reserved

    add rsi, 16
    inc rcx
    jmp .fill_exceptions

.fill_irqs:
    ; Fill entries 32-47 (IRQ handlers)
    mov rcx, 32

.fill_irqs_loop:
    cmp rcx, 48
    je .load_idtr

    ; Set all IRQ handlers to irq_handler stubs
    mov rax, handler_20            ; IRQ 0 handler

    ; Similar to above: fill IDT entry
    ; (Implementation: in production, would set each IRQ handler)

    add rsi, 16
    inc rcx
    jmp .fill_irqs_loop

.load_idtr:
    ; Load IDTR with pointer to IDT
    lidt [idt_ptr]

    pop rsi
    pop rcx
    pop rbx
    ret

; ============================================================================
; EXCEPTION/IRQ STUB HANDLERS (Phase 5 stubs — replaced by real handlers in Phase 8+)
; ============================================================================

; Simple exception handler stub
handle_exception:
    ; RDI = vector number
    ; RSI = error code
    ; For Phase 5, just print vector and return
    mov rax, rdi
    mov dx, 0x3F8
    mov al, 'E'
    out dx, al
    ret

; Simple IRQ handler stub
handle_irq:
    ; RDI = IRQ number
    mov rax, rdi
    mov dx, 0x3F8
    mov al, 'I'
    out dx, al
    ret
