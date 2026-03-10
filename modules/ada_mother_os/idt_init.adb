-- ============================================================================
-- idt_init.adb — Ada IDT Initialization Package Body (Simplified)
-- ============================================================================
-- Minimal implementation: just load IDTR with pre-computed IDT from asm
-- The IDT table itself stays in idt.asm (static), Ada just does the LIDT
-- ============================================================================

with System;
use System;

package body IDT_Init is

   ---------------------------------------------------------------------------
   -- Initialize_IDT — Load IDTR with IDT address
   ---------------------------------------------------------------------------
   -- This function is called from assembly startup code
   -- It simply executes: lidt [idt_ptr]
   -- where idt_ptr is defined in idt.asm
   procedure Initialize_IDT is
   begin
      -- The IDT is pre-initialized in idt.asm with all 256 entries
      -- We just need to load the IDTR register

      -- Inline x86-64 assembly to load IDTR
      -- LIDT instruction: LIDT mem64
      -- Operand format: 10 bytes = limit (2B) + base (8B)

      System.Machine_Code.Asm (
         "lidt [rax]",
         Inputs => (System.Address'Asm_Input ("a", IDT_Pointer)),
         Volatile => True);
   end Initialize_IDT;

   -- Imported from idt.asm (assembly)
   -- These are the pre-computed IDT structures
   IDT_Pointer : System.Address
   with Import, Convention => C, External_Name => "idt_ptr";

end IDT_Init;
