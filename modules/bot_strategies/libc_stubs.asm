; Bot Strategies Module - LibC Stubs
; Bare-metal stubs for Zig standard library calls

section .text
    global memcpy
    global memset
    global strlen
    global strcmp
    global memcmp

; memcpy(dst, src, count)
; rdi = dst, rsi = src, rdx = count
memcpy:
    push rbx
    xor rax, rax
.loop:
    cmp rax, rdx
    jge .done
    mov bl, byte [rsi + rax]
    mov byte [rdi + rax], bl
    inc rax
    jmp .loop
.done:
    pop rbx
    ret

; memset(dst, value, count)
; rdi = dst, rsi = value, rdx = count
memset:
    push rax
    mov rax, rsi
    xor rcx, rcx
.loop:
    cmp rcx, rdx
    jge .done
    mov byte [rdi + rcx], al
    inc rcx
    jmp .loop
.done:
    pop rax
    ret

; strlen(str)
; rdi = str
strlen:
    xor rax, rax
.loop:
    cmp byte [rdi + rax], 0
    je .done
    inc rax
    jmp .loop
.done:
    ret

; strcmp(s1, s2)
; rdi = s1, rsi = s2
strcmp:
    xor rax, rax
    xor rcx, rcx
.loop:
    mov al, byte [rdi + rcx]
    mov bl, byte [rsi + rcx]
    cmp al, bl
    jne .not_equal
    cmp al, 0
    je .equal
    inc rcx
    jmp .loop
.equal:
    xor rax, rax
    ret
.not_equal:
    mov rax, 1
    ret

; memcmp(s1, s2, count)
; rdi = s1, rsi = s2, rdx = count
memcmp:
    xor rax, rax
    xor rcx, rcx
.loop:
    cmp rcx, rdx
    jge .equal
    mov al, byte [rdi + rcx]
    mov bl, byte [rsi + rcx]
    cmp al, bl
    jne .not_equal
    inc rcx
    jmp .loop
.equal:
    xor rax, rax
    ret
.not_equal:
    mov rax, 1
    ret
