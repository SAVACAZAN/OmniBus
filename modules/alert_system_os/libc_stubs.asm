; libc_stubs.asm - Minimal C library stubs for Alert System OS
; Required for Zig's standard library minimal functions

[BITS 64]

; memset(ptr, value, size)
global memset
memset:
    push rbp
    mov rbp, rsp
    mov rax, rsi
    mov rcx, rdx
    rep stosb
    mov rsp, rbp
    pop rbp
    ret

; memcpy(dest, src, size)
global memcpy
memcpy:
    push rbp
    mov rbp, rsp
    mov rsi, rsi
    mov rdi, rdi
    mov rcx, rdx
    rep movsb
    mov rsp, rbp
    pop rbp
    ret

; strlen(str)
global strlen
strlen:
    xor rax, rax
    cmp rdi, 0
    je .done
.loop:
    mov cl, byte [rdi + rax]
    test cl, cl
    jz .done
    inc rax
    jmp .loop
.done:
    ret

; abort
global abort
abort:
    cli
    hlt
    jmp abort

; exit
global exit
exit:
    cli
    hlt
    jmp exit

; __divti3
global __divti3
__divti3:
    ret

; __udivti3
global __udivti3
__udivti3:
    ret
