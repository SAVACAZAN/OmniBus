/* Alert System OS Linker Script
   Entry: init_plugin
   Target: 0x380000 (64KB)
   Memory: State (128B) + Rules (32*32B = 1024B) + Queue (64*16B = 1024B)
*/

ENTRY(init_plugin)

SECTIONS
{
  . = 0x380000;

  /* Reserve memory for state, rules, and queue */
  .reserved : {
    BYTE(0);
    . = 0x2080;  /* 128 + 1024 + 1024 + padding */
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
