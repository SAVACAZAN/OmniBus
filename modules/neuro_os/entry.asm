;=============================================================================
; NEURO OS ENTRY POINT WRAPPERS (Phase 16)
; Safe calling from kernel via assembly wrappers
;=============================================================================

[BITS 64]

extern init_plugin
extern run_evolution_cycle

global neuro_entry_init
global neuro_entry_cycle

;=============================================================================
; neuro_entry_init: Initialize NeuroOS
; Called from kernel (0x2D0000)
; Returns: RAX = 0 (success)
;=============================================================================

neuro_entry_init:
    push rbp
    mov rbp, rsp
    sub rsp, 0x10

    call init_plugin

    xor rax, rax
    add rsp, 0x10
    pop rbp
    ret

;=============================================================================
; neuro_entry_cycle: Run NeuroOS evolution cycle
; Called from kernel
; Returns: RAX = 0 (success)
;=============================================================================

neuro_entry_cycle:
    push rbp
    mov rbp, rsp
    sub rsp, 0x10

    call run_evolution_cycle

    xor rax, rax
    add rsp, 0x10
    pop rbp
    ret
