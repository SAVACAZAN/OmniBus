; libc_stubs.asm - Minimal C library stubs for AutoRepair OS
; Required for Zig's standard library minimal functions

[BITS 64]

; memset(ptr, value, size)
global memset
memset:
    push rbp
    mov rbp, rsp
    mov rax, rsi                   ; value in AL
    mov rcx, rdx                   ; count in RCX
    mov rdi, rdi                   ; dest in RDI (already set)
    rep stosb
    mov rsp, rbp
    pop rbp
    ret

; memcpy(dest, src, size)
global memcpy
memcpy:
    push rbp
    mov rbp, rsp
    mov rsi, rsi                   ; src in RSI (already set)
    mov rdi, rdi                   ; dest in RDI (already set)
    mov rcx, rdx                   ; count in RCX
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

; __divti3 - 128-bit division (rarely used, stub)
global __divti3
__divti3:
    ret

; __udivti3 - unsigned 128-bit division (stub)
global __udivti3
__udivti3:
    ret
