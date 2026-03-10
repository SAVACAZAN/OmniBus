; ============================================================================
; OmniBus Stage 2 - Ultra Minimal Test (just halt)
; Entry point: 0x7E00
; Purpose: Verify Stage 2 is loaded correctly
; ============================================================================

[BITS 16]
[ORG 0x7E00]

stage2_start:
    cli
    cld

    ; Try to print character to UART to prove we're running
    mov al, 'S'         ; 'S' for Stage 2
    mov dx, 0x3F8      ; UART port
    out dx, al

    ; Halt
    cli
    hlt
    jmp $

; Padding to 4KB
times (0x1000 - ($ - $$)) db 0
