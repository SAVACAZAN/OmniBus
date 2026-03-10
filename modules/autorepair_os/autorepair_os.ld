/* AutoRepair OS Linker Script
   Entry: init_plugin
   Target: 0x320000 (64KB)
   Compile: zig build-lib autorepair_os.zig -target x86_64-freestanding
   Link: ld -T autorepair_os.ld -o autorepair_os.elf autorepair_os.o
   Binary: objcopy -O binary autorepair_os.elf autorepair_os.bin
*/

ENTRY(init_plugin)

SECTIONS
{
  . = 0x320000;

  /* Reserve 128 bytes for AutoRepairState struct (0x320000-0x32007F) */
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
