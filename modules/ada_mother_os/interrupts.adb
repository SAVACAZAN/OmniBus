-- Interrupt & Exception Handler Package Body
-- ==========================================

with Ada_Kernel;

package body Interrupts is

   -- =============================================
   -- EXCEPTION HANDLERS
   -- =============================================

   procedure Handle_Divide_By_Zero is
   begin
      Ada_Kernel.UART_Write_String ("[EXCEPTION] Divide by zero");
      Ada_Kernel.Sys_Panic ("DIV0");
   end Handle_Divide_By_Zero;

   procedure Handle_Undefined_Opcode is
   begin
      Ada_Kernel.UART_Write_String ("[EXCEPTION] Undefined opcode");
      Ada_Kernel.Sys_Panic ("OPCODE");
   end Handle_Undefined_Opcode;

   procedure Handle_General_Protection is
   begin
      Ada_Kernel.UART_Write_String ("[EXCEPTION] General protection fault");
      Ada_Kernel.Sys_Panic ("GP_FAULT");
   end Handle_General_Protection;

   procedure Handle_Page_Fault is
   begin
      Ada_Kernel.UART_Write_String ("[EXCEPTION] Page fault");
      Ada_Kernel.Sys_Panic ("PAGE_FAULT");
   end Handle_Page_Fault;

   -- =============================================
   -- EXCEPTION DISPATCHER
   -- =============================================

   procedure Handle_Exception (Exception_Code : Natural) is
   begin
      case Exception_Code is
         when EXCEPTION_DIVIDE_BY_ZERO =>
            Handle_Divide_By_Zero;
         when EXCEPTION_UNDEFINED_OPCODE =>
            Handle_Undefined_Opcode;
         when EXCEPTION_GENERAL_PROTECTION =>
            Handle_General_Protection;
         when EXCEPTION_PAGE_FAULT =>
            Handle_Page_Fault;
         when others =>
            Ada_Kernel.UART_Write_String ("[EXCEPTION] Unknown exception: ");
            Ada_Kernel.UART_Write_Hex (Unsigned_32 (Exception_Code));
            Ada_Kernel.Sys_Panic ("UNKNOWN");
      end case;
   end Handle_Exception;

   -- =============================================
   -- IDT INITIALIZATION
   -- =============================================

   procedure Initialize_IDT is
   begin
      Ada_Kernel.UART_Write_String ("[INT] Initializing IDT");
      --  In a complete implementation, this would:
      --  1. Create IDT entries for all exceptions
      --  2. Set gate type, privilege level, selector
      --  3. Point to handler code
      null;
   end Initialize_IDT;

   procedure Register_Handler (Vector : Natural; Handler : Unsigned_32) is
   begin
      --  Register handler at IDT[Vector]
      --  IDT entry format (8 bytes):
      --    [0:1] Offset low (16 bits)
      --    [2:3] Selector (16 bits = 0x08 for kernel code)
      --    [4]   Flags (gate type, privilege, present)
      --    [5]   Offset mid (8 bits)
      --    [6:7] Offset high (16 bits)
      null;
   end Register_Handler;

   procedure Load_IDT is
   begin
      --  Load IDT register:
      --  LIDT [address]
      --  where address points to:
      --    [0:1] Limit (16 bits) = 256 entries × 8 - 1
      --    [2:5] Base address (32 bits) = 0x101400
      null;
   end Load_IDT;

end Interrupts;
