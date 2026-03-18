/* Historical Analytics OS Linker Script
   Entry: init_plugin
   Target: 0x370000 (64KB)
   Memory: State (128B) + Ring buffer (256 * 32B = 8192B)
*/

ENTRY(init_plugin)

SECTIONS
{
  . = 0x370000;

  /* Reserve 128 bytes for HistoricalAnalyticsState + 8KB ring buffer */
  .reserved : {
    BYTE(0);
    . = 0x2080;  /* 128 + 8192 = 8320 bytes reserved */
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
