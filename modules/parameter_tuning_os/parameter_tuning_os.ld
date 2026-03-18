/* Parameter Tuning OS Linker Script
   Entry: init_plugin
   Target: 0x360000 (64KB)
   Compile: zig build-obj parameter_tuning_os.zig -target x86_64-freestanding
   Link: ld -T parameter_tuning_os.ld -o parameter_tuning_os.elf parameter_tuning_os.o
   Binary: objcopy -O binary parameter_tuning_os.elf parameter_tuning_os.bin
*/

ENTRY(init_plugin)

SECTIONS
{
  . = 0x360000;

  /* Reserve 256 bytes for ParameterTuningState struct (0x360000-0x3600FF) */
  /* Then 128 bytes padding, then code */
  .reserved : {
    BYTE(0);
    . = 0x100;
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
