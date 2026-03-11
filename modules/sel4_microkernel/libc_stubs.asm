; libc_stubs.asm - Minimal C library stubs for seL4 Microkernel
; Required for Zig's standard library minimal functions

[BITS 64]

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

global abort
abort:
    cli
    hlt
    jmp abort

global exit
exit:
    cli
    hlt
    jmp exit

global __divti3
__divti3:
    ret

global __udivti3
__udivti3:
    ret
