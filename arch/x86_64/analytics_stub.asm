; ============================================================================
; Analytics OS Phase 5A Stub
; 64-bit flat binary, ORG 0x150000 (Analytics OS memory base)
; init_plugin() is at byte 0 — loader calls base address directly
; ============================================================================
[BITS 64]
[ORG 0x150000]

; ============================================================================
; init_plugin() — Analytics OS init stub
; Called via: mov rax, 0x150000 / call rax
; Writes "ANALYTICS_64_OK\r\n" to UART COM1, initializes price feed slot
; ============================================================================
init_plugin:
    push rax
    push rdx

    ; Initialize price feed magic at 0x150000 + 0x800 (after code)
    mov qword [0x150800], 0x4E414C41  ; "ALAN" = Analytics

    ; UART: "ANALYTICS_64_OK\r\n"
    mov dx, 0x3F8
    mov al, 'A'
    out dx, al
    mov al, 'N'
    out dx, al
    mov al, 'A'
    out dx, al
    mov al, 'L'
    out dx, al
    mov al, 'Y'
    out dx, al
    mov al, 'T'
    out dx, al
    mov al, 'I'
    out dx, al
    mov al, 'C'
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
