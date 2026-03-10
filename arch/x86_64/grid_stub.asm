; ============================================================================
; Grid OS Phase 5A Stub
; 64-bit flat binary, ORG 0x110000 (Grid OS memory base)
; init_plugin() is at byte 0 — loader calls base address directly
; ============================================================================
[BITS 64]
[ORG 0x110000]

; ============================================================================
; init_plugin() — Grid OS init stub
; Called via: mov rax, 0x110000 / call rax
; Writes "GRID_OS_64_OK\r\n" to UART COM1, initializes magic header
; ============================================================================
init_plugin:
    push rax
    push rdx

    ; Write magic "GRID" to Grid OS state header (0x110800 = after code)
    mov qword [0x110800], 0x44495247  ; "GRID" little-endian

    ; UART: "GRID_OS_64_OK\r\n"
    mov dx, 0x3F8
    mov al, 'G'
    out dx, al
    mov al, 'R'
    out dx, al
    mov al, 'I'
    out dx, al
    mov al, 'D'
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
