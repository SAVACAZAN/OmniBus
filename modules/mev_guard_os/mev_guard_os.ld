/* MEV Guard OS Linker Script
   Entry: init_plugin
   Target: 0x3B0000 (64KB)
   Memory: State (128B) + Sandwich windows (16*32B = 512B) = 640B reserved
*/

ENTRY(init_plugin)

SECTIONS
{
  . = 0x3B0000;

  /* Reserve 640 bytes for MevGuardState + SandwichWindowBuffer */
  .reserved : {
    BYTE(0);
    . = 0x280;  /* 640 bytes reserved */
  }

  /* Code section */
  .text ALIGN(0x100) : {
    *(.text.init_plugin)
    *(.text*)
    *(.gnu.linkonce.t*)
  }

  .rodata ALIGN(0x100) : {
    *(.rodata*)
    *(.gnu.linkonce.r*)
  }

  .data ALIGN(0x100) : {
    *(.data*)
    *(.gnu.linkonce.d*)
  }

  .bss ALIGN(0x100) : {
    *(.bss*)
    *(COMMON)
  }

  /DISCARD/ : {
    *(.note.GNU-stack)
    *(.gnu_debuglink)
    *(.gnu_debugdata)
  }
}
