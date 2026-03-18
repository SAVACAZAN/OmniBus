; Bot Strategies Module - Entry Point
; Zig module entry and initialization

BITS 64
section .text

extern _start

; Module entry point
global _module_entry
_module_entry:
    ; Initialize module state
    ; This is called during kernel module loading

    ; Zero out BSS section
    lea rdi, [rel __bss_start]
    lea rsi, [rel __bss_end]
    sub rsi, rdi
    xor rax, rax
    cmp rsi, 0
    je .skip_bss

.zero_bss:
    mov byte [rdi], al
    inc rdi
    dec rsi
    cmp rsi, 0
    jg .zero_bss

.skip_bss:
    ; Return to kernel
    ret

; Placeholder BSS markers (if not provided by linker)
section .bss
__bss_start:
    resb 1
__bss_end:
