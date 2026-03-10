/* Neuro OS Linker Script
   Entry: init_plugin
   Target: 0x2D0000 (512KB)
   Compile: zig build-obj neuro_os.zig -target x86_64-freestanding
   Link: ld -T neuro_os.ld -o neuro_os.elf neuro_os.o
   Binary: objcopy -O binary neuro_os.elf neuro_os.bin
*/

ENTRY(init_plugin)

SECTIONS
{
  . = 0x2D0000;

  .text : {
    *(.text.init_plugin)
    *(.text*)
    *(.gnu.linkonce.t*)
  }

  .rodata : {
    *(.rodata*)
    *(.gnu.linkonce.r*)
  }

  .data : {
    *(.data*)
    *(.gnu.linkonce.d*)
  }

  .bss : {
    *(.bss*)
    *(COMMON)
  }

  /DISCARD/ : {
    *(.note.GNU-stack)
    *(.gnu_debuglink)
    *(.gnu_debugdata)
  }
}
