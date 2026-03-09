-- Interrupt & Exception Handler Package Specification
-- ===================================================
--
-- Defines exception handlers for CPU exceptions and software interrupts
-- Located at 0x101400 in kernel memory

with System;
with Interfaces;
use System;
use Interfaces;

package Interrupts is

   -- =============================================
   -- CONSTANTS
   -- =============================================

   INTERRUPTS_BASE : constant Unsigned_32 := 16#101400#;
   IDT_ENTRY_SIZE  : constant Unsigned_32 := 8;  -- 8 bytes per IDT descriptor

   -- =============================================
   -- EXCEPTION CODES
   -- =============================================

   EXCEPTION_DIVIDE_BY_ZERO       : constant Natural := 0;
   EXCEPTION_UNDEFINED_OPCODE     : constant Natural := 6;
   EXCEPTION_GENERAL_PROTECTION   : constant Natural := 13;
   EXCEPTION_PAGE_FAULT           : constant Natural := 14;

   -- =============================================
   -- EXCEPTION HANDLERS
   -- =============================================

   --  Divide by zero (exception #0)
   procedure Handle_Divide_By_Zero;

   --  Undefined opcode (exception #6)
   procedure Handle_Undefined_Opcode;

   --  General protection fault (exception #13)
   procedure Handle_General_Protection;

   --  Page fault (exception #14)
   procedure Handle_Page_Fault;

   --  Generic exception dispatcher
   procedure Handle_Exception (Exception_Code : Natural);

   -- =============================================
   -- INTERRUPT INITIALIZATION
   -- =============================================

   --  Initialize interrupt descriptor table (IDT)
   procedure Initialize_IDT;

   --  Register an exception handler
   procedure Register_Handler (Vector : Natural; Handler : Unsigned_32);

   --  Load IDT register (LIDT instruction)
   procedure Load_IDT;

end Interrupts;
