/* Analytics OS Linker Script
   Entry: init_plugin
   Target: 0x150000 (512KB)
   Compile: zig build-lib analytics_os.zig -target x86_64-freestanding
   Link: ld -T analytics_os.ld -o analytics_os.elf analytics_os.o
   Binary: objcopy -O binary analytics_os.elf analytics_os.bin
*/

ENTRY(init_plugin)

SECTIONS
{
  . = 0x150000;

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
