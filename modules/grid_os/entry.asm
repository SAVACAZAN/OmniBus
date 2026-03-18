;=============================================================================
; GRID OS ENTRY POINT WRAPPERS (Phase 16)
; Safe calling from kernel via assembly wrappers
;=============================================================================

[BITS 64]

extern init_plugin
extern run_grid_cycle
extern export_metrics

global grid_entry_init
global grid_entry_cycle

;=============================================================================
; grid_entry_init: Initialize Grid OS
; Called from kernel (0x110000)
; Returns: RAX = 0 (success)
;=============================================================================

grid_entry_init:
    push rbp
    mov rbp, rsp
    sub rsp, 0x10           ; Stack alignment

    call init_plugin

    xor rax, rax            ; Return 0 (success)
    add rsp, 0x10
    pop rbp
    ret

;=============================================================================
; grid_entry_cycle: Run Grid OS cycle
; Called from kernel
; Returns: RAX = 0 (success)
;=============================================================================

grid_entry_cycle:
    push rbp
    mov rbp, rsp
    sub rsp, 0x10

    call run_grid_cycle
    call export_metrics     ; Export metrics after cycle

    xor rax, rax
    add rsp, 0x10
    pop rbp
    ret
