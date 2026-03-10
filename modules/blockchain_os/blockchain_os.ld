/* BlockchainOS Linker Script
   Entry: init_plugin
   Target: 0x250000 (192KB)
   Compile: zig build-obj blockchain_os.zig -target x86_64-freestanding
   Link: ld -T blockchain_os.ld -o blockchain_os.elf blockchain_os.o
   Binary: objcopy -O binary blockchain_os.elf blockchain_os.bin
*/

ENTRY(init_plugin)

SECTIONS
{
  . = 0x250000;

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
