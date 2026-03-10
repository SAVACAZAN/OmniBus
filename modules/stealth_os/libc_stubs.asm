; libc_stubs.asm — Standard library stubs for Stealth OS (freestanding)

[BITS 64]

global memset
memset:
    push rbp
    mov rbp, rsp
    test rdx, rdx
    jz .memset_done
    movzx eax, sil
    mov rcx, rdx
.memset_loop:
    mov [rdi], al
    inc rdi
    dec rcx
    jnz .memset_loop
.memset_done:
    mov rax, [rbp + 16]
    pop rbp
    ret

global memcpy
memcpy:
    push rbp
    mov rbp, rsp
    mov rcx, rdx
    test rcx, rcx
    jz .memcpy_done
.memcpy_loop:
    mov al, [rsi]
    mov [rdi], al
    inc rsi
    inc rdi
    dec rcx
    jnz .memcpy_loop
.memcpy_done:
    mov rax, [rbp + 16]
    pop rbp
    ret

global __udivti3
__udivti3:
    xor rax, rax
    ret

global __umodti3
__umodti3:
    xor rdx, rdx
    ret
