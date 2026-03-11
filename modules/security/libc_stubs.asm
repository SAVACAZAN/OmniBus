; Minimal libc stubs for security modules
; memcpy, memset required by Zig runtime

bits 64

global memcpy
global memset
global memcmp

section .text

; memcpy(rdi=dest, rsi=src, rdx=count) -> rax=dest
memcpy:
    mov rax, rdi                ; return value = destination
    cmp rdx, 0
    je .memcpy_done
.memcpy_loop:
    mov cl, byte [rsi]
    mov byte [rdi], cl
    inc rsi
    inc rdi
    dec rdx
    jnz .memcpy_loop
.memcpy_done:
    ret

; memset(rdi=dest, rsi=value, rdx=count) -> rax=dest
memset:
    mov rax, rdi                ; return value = destination
    cmp rdx, 0
    je .memset_done
    mov al, sil
.memset_loop:
    mov byte [rdi], al
    inc rdi
    dec rdx
    jnz .memset_loop
.memset_done:
    mov rax, rdi
    ret

; memcmp(rdi=s1, rsi=s2, rdx=count) -> rax=(s1-s2)
memcmp:
    xor rax, rax
    cmp rdx, 0
    je .memcmp_done
.memcmp_loop:
    mov al, byte [rdi]
    mov cl, byte [rsi]
    cmp al, cl
    jne .memcmp_diff
    inc rdi
    inc rsi
    dec rdx
    jnz .memcmp_loop
    jmp .memcmp_done
.memcmp_diff:
    movzx rax, al
    movzx rcx, cl
    sub rax, rcx
.memcmp_done:
    ret
