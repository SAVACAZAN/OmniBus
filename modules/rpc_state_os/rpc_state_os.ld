/* rpc_state_os.ld – RPC State OS Linker Script (Phase 59) */

MEMORY {
    code  (rx)  : ORIGIN = 0x650000, LENGTH = 32K
    data  (rw)  : ORIGIN = 0x658000, LENGTH = 32K
}

SECTIONS {
    .text : {
        *(.text*)
        *(.rodata*)
    } > code

    .data : {
        *(.data*)
        *(.bss*)
        *(COMMON)
    } > data

    /DISCARD/ : {
        *(.note.GNU-stack)
        *(.gnu_debuglink)
        *(.gnu_debugaltlink)
    }
}

ENTRY(init_plugin)
