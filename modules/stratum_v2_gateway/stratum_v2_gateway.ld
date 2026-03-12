ENTRY(init_plugin)

SECTIONS
{
  . = 0x5B0000;

  .text.init_plugin : { *(.text.init_plugin) }
  .text : { *(.text) }
  .rodata : { *(.rodata) }
  .data : { *(.data) }
  .bss : { *(.bss) }
}
