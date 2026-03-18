/* Federation OS Linker Script
   Entry: init_plugin
   Target: 0x3A0000 (64KB)
   Memory: State (128B) + Message ring buffer (16*32B = 512B) + Route table (128B) = 768B reserved
*/

ENTRY(init_plugin)

SECTIONS
{
  . = 0x3A0000;

  /* Reserve 768 bytes for FederationState + MessageBuffer + RouteTable */
  .reserved : {
    BYTE(0);
    . = 0x300;  /* 768 bytes reserved */
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
