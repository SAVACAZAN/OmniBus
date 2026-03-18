[BITS 64]
global memcpy
global memset
memcpy:
    push rdi
    mov rcx, rdx
    cmp rcx, 0
    je .done
.loop:
    mov al, byte [rsi]
    mov byte [rdi], al
    inc rsi
    inc rdi
    dec rcx
    jnz .loop
.done:
    pop rax
    ret
memset:
    push rdi
    mov rcx, rdx
    mov al, sil
    cmp rcx, 0
    je .mdone
.mloop:
    mov byte [rdi], al
    inc rdi
    dec rcx
    jnz .mloop
.mdone:
    pop rax
    ret
