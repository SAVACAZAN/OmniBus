/* Report OS Linker Script
   Entry: init_plugin
   Target: 0x300000 (256KB)
   Compile: zig build-lib report_os.zig -target x86_64-freestanding
   Link: ld -T report_os.ld -o report_os.elf report_os.o
   Binary: objcopy -O binary report_os.elf report_os.bin
*/

ENTRY(init_plugin)

SECTIONS
{
  . = 0x300000;

  /* Reserve 256 bytes for ReportState struct (0x300000-0x3000FF) */
  /* Then 64 bytes padding, then daily metrics array */
  .reserved : {
    BYTE(0);
    . = 0x80;
  }

  /* Daily metrics array starts at 0x300080 */
  .data_metrics ALIGN(0x100) : {
    *(.data.daily_metrics)
  }

  /* Code section */
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
