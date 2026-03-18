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
