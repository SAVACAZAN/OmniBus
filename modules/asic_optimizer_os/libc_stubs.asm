; Minimal libc stubs for freestanding Zig code
; memcpy(rdi=dest, rsi=src, rdx=len) -> rdi
; memset(rdi=dest, rsi=val, rdx=len) -> rdi

[BITS 64]

global memcpy
global memset

; Simple memcpy: copy rdx bytes from rsi to rdi
memcpy:
    push rdi
    mov rcx, rdx      ; rcx = number of bytes
    cmp rcx, 0
    je .memcpy_done

    ; Copy byte by byte (simple implementation)
.memcpy_loop:
    mov al, byte [rsi]
    mov byte [rdi], al
    inc rsi
    inc rdi
    dec rcx
    jnz .memcpy_loop

.memcpy_done:
    pop rax           ; Return value: original dest
    ret

; Simple memset: fill rdi with byte rsi for rdx bytes
memset:
    push rdi
    mov rcx, rdx      ; rcx = number of bytes
    mov al, sil       ; al = byte value
    cmp rcx, 0
    je .memset_done

.memset_loop:
    mov byte [rdi], al
    inc rdi
    dec rcx
    jnz .memset_loop

.memset_done:
    pop rax           ; Return value: original dest
    ret
