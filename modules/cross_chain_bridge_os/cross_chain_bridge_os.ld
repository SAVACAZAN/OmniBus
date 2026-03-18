ENTRY(init_plugin)

SECTIONS {
  . = 0x3C0000;
  .text : { *(.text*) }
  .rodata : { *(.rodata*) }
  .data : { *(.data*) }
  . = ALIGN(4096);
  .bss : { *(.bss*) *(COMMON) }
}
