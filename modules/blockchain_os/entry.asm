;=============================================================================
; BLOCKCHAIN OS ENTRY POINT WRAPPERS (Phase 16)
; Safe calling from kernel via assembly wrappers
;=============================================================================

[BITS 64]

extern init_plugin
extern run_blockchain_cycle

global blockchain_entry_init
global blockchain_entry_cycle

;=============================================================================
; blockchain_entry_init: Initialize BlockchainOS
; Called from kernel (0x250000)
; Returns: RAX = 0 (success)
;=============================================================================

blockchain_entry_init:
    push rbp
    mov rbp, rsp
    sub rsp, 0x10

    call init_plugin

    xor rax, rax
    add rsp, 0x10
    pop rbp
    ret

;=============================================================================
; blockchain_entry_cycle: Run BlockchainOS cycle
; Called from kernel
; Returns: RAX = 0 (success)
;=============================================================================

blockchain_entry_cycle:
    push rbp
    mov rbp, rsp
    sub rsp, 0x10

    call run_blockchain_cycle

    xor rax, rax
    add rsp, 0x10
    pop rbp
    ret
