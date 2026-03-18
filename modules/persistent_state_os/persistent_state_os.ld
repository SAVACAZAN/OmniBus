ENTRY(init_plugin)
SECTIONS {
  . = 0x510000;
  .reserved : { BYTE(0); . = 0x80; }
  .text ALIGN(0x100) : { *(.text.init_plugin) *(.text*) *(.gnu.linkonce.t*) }
  .rodata ALIGN(0x100) : { *(.rodata*) *(.gnu.linkonce.r*) }
  .data ALIGN(0x100) : { *(.data*) *(.gnu.linkonce.d*) }
  . = ALIGN(4096);
  .bss : { *(.bss*) *(COMMON) }
  /DISCARD/ : { *(.note.GNU-stack) *(.gnu_debuglink) *(.gnu_debugdata) }
}
