/* Checksum OS Linker Script
   Entry: init_plugin
   Target: 0x310000 (64KB)
   Compile: zig build-lib checksum_os.zig -target x86_64-freestanding
   Link: ld -T checksum_os.ld -o checksum_os.elf checksum_os.o
   Binary: objcopy -O binary checksum_os.elf checksum_os.bin
*/

ENTRY(init_plugin)

SECTIONS
{
  . = 0x310000;

  /* Reserve 128 bytes for ChecksumState struct (0x310000-0x31007F) */
  /* Then 128 bytes padding, then code */
  .reserved : {
    BYTE(0);
    . = 0x80;
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
