/* Grid OS Linker Script
   Entry: init_plugin
   Target: 0x110000 (128KB)
   Compile: zig build-lib grid_os.zig -target x86_64-freestanding
   Link: ld -T grid_os.ld -o grid_os.elf grid_os.o
   Binary: objcopy -O binary grid_os.elf grid_os.bin
*/

ENTRY(init_plugin)

SECTIONS
{
  . = 0x110000;

  .text ALIGN(0x1000) : {
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
