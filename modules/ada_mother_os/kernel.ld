/* ============================================================================
   kernel.ld — Kernel Linker Script for Phase 8 (IDT + Ada)
   ============================================================================
   Links assembly startup code with Ada IDT initialization module.
   Places sections at predictable addresses for deterministic execution.
*/

ENTRY(startup_begin)

SECTIONS
{
  /* Kernel starts at 0x100000 */
  . = 0x100000;

  /* Startup code (32-bit and 64-bit) */
  .text ALIGN(0x1000) : {
    *(.text.startup_begin)
    *(.text.long_mode_entry)
    *(.text*)
    *(.gnu.linkonce.t*)
  }

  /* Exception handler stubs */
  .text.handlers ALIGN(0x100) : {
    exception_handler_stub = .;
    *(.text.handler*)
    *(.text.*handler*)
  }

  /* IDT table (must be at known address) */
  .idt ALIGN(0x100) : {
    idt_table = .;
    . += 4096;  /* 256 entries × 16 bytes = 4096 bytes */
  }

  /* IDTR pointer structure (2B limit + 8B base) */
  .idtr ALIGN(0x10) : {
    idt_ptr = .;
    . += 10;
  }

  /* Read-only data */
  .rodata ALIGN(0x100) : {
    *(.rodata*)
    *(.gnu.linkonce.r*)
  }

  /* Initialized data */
  .data ALIGN(0x100) : {
    *(.data*)
    *(.gnu.linkonce.d*)
  }

  /* Uninitialized data */
  .bss ALIGN(0x100) : {
    *(.bss*)
    *(COMMON)
  }

  /* Discard unnecessary sections */
  /DISCARD/ : {
    *(.note.GNU-stack)
    *(.gnu_debuglink)
    *(.gnu_debugdata)
    *(.eh_frame)
    *(.comment)
  }
}
