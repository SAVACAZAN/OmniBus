ENTRY(init_plugin)

SECTIONS {
  . = 0x4B0000;
  .reserved : { BYTE(0); . = 0x280; }  /* 640B: state(128) + divergence_log(8*32=256) */
  .text     ALIGN(0x100) : { *(.text*)  }
  .rodata   ALIGN(0x100) : { *(.rodata*) }
  .data     ALIGN(0x100) : { *(.data*)  }
  . = ALIGN(4096);
  .bss : { *(.bss*) *(COMMON) }
}
