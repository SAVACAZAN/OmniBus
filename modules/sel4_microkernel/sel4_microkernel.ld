ENTRY(init_plugin)

SECTIONS {
  . = 0x4A0000;
  .reserved : { BYTE(0); . = 0x480; }   /* 1152B: state(128) + caps(32*32=1024) */
  .text     ALIGN(0x100) : { *(.text*)  }
  .rodata   ALIGN(0x100) : { *(.rodata*) }
  .data     ALIGN(0x100) : { *(.data*)  }
  . = ALIGN(4096);
  .bss : { *(.bss*) *(COMMON) }
}
