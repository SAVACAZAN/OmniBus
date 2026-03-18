ENTRY(init_plugin)

SECTIONS
{
  . = 0x5E0000;

  .text.init_plugin : { *(.text.init_plugin) }
  .text : { *(.text) }
  .rodata : { *(.rodata) }
  .data : { *(.data) }
  .bss : { *(.bss) }
}
