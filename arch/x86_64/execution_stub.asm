; ============================================================================
; Execution OS Phase 5A Stub
; 64-bit flat binary, ORG 0x130000 (Execution OS memory base)
; init_plugin() is at byte 0 — loader calls base address directly
; ============================================================================
[BITS 64]
[ORG 0x130000]

; ============================================================================
; init_plugin() — Execution OS init stub
; Called via: mov rax, 0x130000 / call rax
; Writes "EXEC_OS_64_OK\r\n" to UART COM1, initializes order queue header
; ============================================================================
init_plugin:
    push rax
    push rdx

    ; Initialize order queue magic at 0x130000 + 0x800 (after code)
    mov qword [0x130800], 0x43455845  ; "EXEC"

    ; UART: "EXEC_OS_64_OK\r\n"
    mov dx, 0x3F8
    mov al, 'E'
    out dx, al
    mov al, 'X'
    out dx, al
    mov al, 'E'
    out dx, al
    mov al, 'C'
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
    ret

; --- Pad to 8KB (16 sectors × 512B) ---
times (0x2000 - ($ - $$)) db 0
