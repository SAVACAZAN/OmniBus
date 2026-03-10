/* Grid OS Linker Script
   Entry: init_plugin
   Target: 0x110000 (128KB)
   Compile: zig build-lib grid_os.zig -target x86_64-freestanding
   Link: ld -T grid_os.ld -o grid_os.elf grid_os.o
   Binary: objcopy -O binary grid_os.elf grid_os.bin
*/

ENTRY(init_plugin)

SECTIONS
{
  . = 0x110000;

  /* Reserve 256 bytes for GridState struct (0x110000-0x1100FF) */
  /* These bytes will be zero-initialized at load time */
  /* Using a dummy section filled with zeros */
  .reserved : {
    BYTE(0);  /* Insert at least one zero byte */
    . = 0x100;  /* Advance to offset 0x100 */
  }

  /* .text section now starts at 0x110100 */
  .text ALIGN(16) : {
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
