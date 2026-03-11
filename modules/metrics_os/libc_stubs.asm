[BITS 64]

; libc stubs for MetricsOS
global memset, memcpy, strlen

memset:
    mov r8, rdi
    mov r9, rsi
    mov r10, rdx
.memset_loop:
    cmp r10, 0
    je .memset_done
    mov byte [r8], r9b
    inc r8
    dec r10
    jmp .memset_loop
.memset_done:
    ret

memcpy:
    mov r8, rdi
    mov r9, rsi
    mov r10, rdx
.memcpy_loop:
    cmp r10, 0
    je .memcpy_done
    mov al, [r9]
    mov [r8], al
    inc r8
    inc r9
    dec r10
    jmp .memcpy_loop
.memcpy_done:
    ret

strlen:
    mov r8, rdi
    xor r9, r9
.strlen_loop:
    cmp byte [r8 + r9], 0
    je .strlen_done
    inc r9
    jmp .strlen_loop
.strlen_done:
    mov rax, r9
    ret
