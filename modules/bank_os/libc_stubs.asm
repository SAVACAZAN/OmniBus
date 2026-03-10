; libc_stubs.asm — Standard library stubs for BankOS (freestanding)
; Provides memset, memcpy for Zig runtime

[BITS 64]

; memset(ptr, value, size) → ptr
; rdi = ptr, esi = value, rdx = size
global memset
memset:
    push rbp
    mov rbp, rsp

    test rdx, rdx          ; if size == 0
    jz .memset_done

    movzx eax, sil         ; al = value (byte)
    mov rcx, rdx           ; rcx = size

.memset_loop:
    mov [rdi], al          ; *ptr = value
    inc rdi
    dec rcx
    jnz .memset_loop

.memset_done:
    mov rax, [rbp + 16]    ; return original ptr
    pop rbp
    ret

; memcpy(dest, src, size) → dest
; rdi = dest, rsi = src, rdx = size
global memcpy
memcpy:
    push rbp
    mov rbp, rsp

    mov rcx, rdx           ; rcx = size
    test rcx, rcx
    jz .memcpy_done

.memcpy_loop:
    mov al, [rsi]          ; al = *src
    mov [rdi], al          ; *dest = al
    inc rsi
    inc rdi
    dec rcx
    jnz .memcpy_loop

.memcpy_done:
    mov rax, [rbp + 16]    ; return original dest
    pop rbp
    ret

; __udivti3 — 128-bit unsigned division (stub)
; Used by Zig's 128-bit integer operations
global __udivti3
__udivti3:
    ; Stub: just return 0 (not implemented for now)
    xor rax, rax
    ret

; __umodti3 — 128-bit unsigned modulo
global __umodti3
__umodti3:
    xor rdx, rdx
    ret
