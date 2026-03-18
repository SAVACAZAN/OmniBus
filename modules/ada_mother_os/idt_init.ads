-- ============================================================================
-- idt_init.ads — Ada IDT Initialization Package Specification
-- ============================================================================
-- Provides interrupt descriptor table setup with linker-resolved addresses.
-- The linker script places the IDT table and handler symbols deterministically.
-- ============================================================================

package IDT_Init is

   -- Initialize the Interrupt Descriptor Table
   -- Called from 64-bit long mode startup code (startup_phase5.asm)
   procedure Initialize_IDT;

   pragma Export (C, Initialize_IDT, "idt_init");

end IDT_Init;
