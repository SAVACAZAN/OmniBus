ENTRY(init_plugin)

SECTIONS {
  . = 0x4C0000;
  .reserved : { BYTE(0); . = 0x80; }  /* 128B state */
  .text     ALIGN(0x100) : { *(.text*)  }
  .rodata   ALIGN(0x100) : { *(.rodata*) }
  .data     ALIGN(0x100) : { *(.data*)  }
  . = ALIGN(4096);
  .bss : { *(.bss*) *(COMMON) }
}
