/* Execution OS Linker Script
   Entry: init_plugin
   Target: 0x130000 (128KB)
   Compile: zig build-lib execution_os.zig -target x86_64-freestanding
   Link: ld -T execution_os.ld -o execution_os.elf execution_os.o
   Binary: objcopy -O binary execution_os.elf execution_os.bin
*/

ENTRY(init_plugin)

SECTIONS
{
  . = 0x130000;

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
