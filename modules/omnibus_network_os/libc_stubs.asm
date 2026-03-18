; Phase 66: OmniBus Network OS – libc stub functions
; ====================================================

section .text
    global memset, memcpy, strlen, strcmp, malloc, free, exit, abort

; memset(void *s, int c, size_t n)
memset:
    push rbx
    mov rax, rsi        ; c
    mov rcx, rdx        ; n
    mov rdi, rdi        ; s
    cld
    rep stosb
    pop rbx
    ret

; memcpy(void *dest, const void *src, size_t n)
memcpy:
    push rsi
    push rdi
    mov rcx, rdx        ; n
    cld
    rep movsb
    pop rdi
    pop rsi
    ret

; strlen(const char *s)
strlen:
    xor rax, rax
    xor rcx, rcx
    dec rcx             ; rcx = -1
    cld
    repne scasb
    lea rax, [rcx + 1]
    neg rax
    dec rax
    ret

; strcmp(const char *s1, const char *s2)
strcmp:
    xor rax, rax
    xor rcx, rcx
.loop:
    mov al, byte [rdi]
    mov cl, byte [rsi]
    cmp al, cl
    jne .ne
    test al, al
    jz .eq
    inc rdi
    inc rsi
    jmp .loop
.eq:
    xor eax, eax
    ret
.ne:
    movzx eax, al
    movzx ecx, cl
    sub eax, ecx
    ret

; malloc(size_t size) – stub (return NULL)
malloc:
    xor rax, rax
    ret

; free(void *ptr) – stub (no-op)
free:
    ret

; exit(int status) – stub (no-op)
exit:
    ret

; abort() – stub (no-op)
abort:
    ret
