; entry.asm — BankOS entry point and function wrappers
; Phase 12: Bank settlement module entry

[BITS 64]

section .text

; Export init_plugin entry point
global bank_os_init
bank_os_init:
    ; Call the actual Zig init_plugin
    call init_plugin
    ret

; Export run_bank_cycle entry point
global bank_os_run_cycle
bank_os_run_cycle:
    ; Call the actual Zig run_bank_cycle
    call run_bank_cycle
    ret

; Export request_swift_settlement entry point
global bank_os_request_swift
bank_os_request_swift:
    ; Arguments already in rdi, rsi, rdx (x86_64 ABI)
    call request_swift_settlement
    ret

; Export request_ach_settlement entry point
global bank_os_request_ach
bank_os_request_ach:
    ; Arguments already in rdi, rsi, rdx
    call request_ach_settlement
    ret

; Export query functions
global bank_os_get_cycle_count
bank_os_get_cycle_count:
    call get_cycle_count
    ret

global bank_os_get_swift_count
bank_os_get_swift_count:
    call get_swift_count
    ret

global bank_os_get_ach_batch_count
bank_os_get_ach_batch_count:
    call get_ach_batch_count
    ret

global bank_os_get_settlement_count
bank_os_get_settlement_count:
    call get_settlement_count
    ret

global bank_os_get_pending_amount
bank_os_get_pending_amount:
    call get_pending_amount_cents
    ret

global bank_os_is_initialized
bank_os_is_initialized:
    call is_initialized
    ret
