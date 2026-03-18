; libc_stubs.asm — Minimal C library stubs for UP Module (bare-metal freestanding)

bits 64

global memset
global memcpy
global strlen

section .text

; memset(void *ptr, int value, size_t num)
; rdi = ptr, rsi = value, rdx = num
memset:
    push rbx
    test rdx, rdx
    jz .memset_done
    movzx rax, sil          ; rax = value & 0xFF
    mov rcx, rdx
.memset_loop:
    mov byte [rdi], al
    inc rdi
    dec rcx
    jnz .memset_loop
.memset_done:
    pop rbx
    ret

; memcpy(void *dest, const void *src, size_t num)
; rdi = dest, rsi = src, rdx = num
memcpy:
    push rsi
    mov rcx, rdx
    test rcx, rcx
    jz .memcpy_done
    cld
    rep movsb
.memcpy_done:
    pop rsi
    ret

; strlen(const char *str)
; rdi = str
; returns rax = length
strlen:
    xor rax, rax
    mov rcx, -1
    xor al, al
    repne scasb
    lea rax, [rcx + 1]
    neg rax
    dec rax
    ret
