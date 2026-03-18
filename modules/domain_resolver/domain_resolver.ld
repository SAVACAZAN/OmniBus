/* Domain Resolver OS Linker Script
   Entry: init_plugin
   Target: 0x4E0000 (64KB)
   Compile: zig build-obj domain_resolver_os.zig -target x86_64-freestanding
   Link: ld -T domain_resolver.ld -o domain_resolver_os.elf domain_resolver_os.o
   Binary: objcopy -O binary domain_resolver_os.elf domain_resolver_os.bin
*/

ENTRY(init_plugin)

SECTIONS
{
  . = 0x4E0000;

  .reserved : { BYTE(0); . = 0x80; }  /* 128B state */

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

  . = ALIGN(4096);
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
