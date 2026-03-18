/* Audit Log OS Linker Script
   Entry: init_plugin
   Target: 0x340000 (256KB)
   Compile: zig build-lib audit_log_os.zig -target x86_64-freestanding
   Link: ld -T audit_log_os.ld -o audit_log_os.elf audit_log_os.o
   Binary: objcopy -O binary audit_log_os.elf audit_log_os.bin
*/

ENTRY(init_plugin)

SECTIONS
{
  . = 0x340000;

  /* Reserve 128 bytes for AuditLogState struct (0x340000-0x34007F) */
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
