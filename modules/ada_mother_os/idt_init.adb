-- ============================================================================
-- idt_init.adb — Ada IDT Initialization Package Body
-- ============================================================================
-- Implements IDT setup by populating pre-allocated table with gate descriptors.
-- Handler addresses are imported from linker script as external symbols.
-- ============================================================================

with Interfaces;
with System;
use Interfaces;
use System;

package body IDT_Init is

   -- x86-64 IDT gate descriptor (16 bytes)
   type Gate_Descriptor is record
      Offset_Low : Unsigned_16;      -- RIP[0:15]
      Selector : Unsigned_16;        -- Code segment selector (0x0008)
      IST : Unsigned_8;              -- IST field (0 = use RSP0)
      Attributes : Unsigned_8;       -- Type/DPL/P (0x8E = interrupt gate)
      Offset_Mid : Unsigned_16;      -- RIP[16:31]
      Offset_High : Unsigned_32;     -- RIP[32:63]
      Reserved : Unsigned_32;        -- Reserved (must be 0)
   end record
   with Convention => C, Size => 128;

   pragma Pack (Gate_Descriptor);

   -- IDT table (256 entries × 16 bytes = 4096 bytes)
   type IDT_Table is array (0 .. 255) of Gate_Descriptor
   with Convention => C;

   -- External symbols imported from linker script
   -- These are defined in the linker script and resolve at link time
   IDT_Table_Base : IDT_Table
   with Import, Convention => C, External_Name => "idt_table";

   Exception_Handler : System.Address
   with Import, Convention => C, External_Name => "exception_handler_stub";

   ---------------------------------------------------------------------------
   -- Initialize_IDT — Populate IDT entries with gate descriptors
   ---------------------------------------------------------------------------
   procedure Initialize_IDT is
      Handler_Addr : Unsigned_64 := Unsigned_64 (To_Integer (Exception_Handler));
      Low_16  : Unsigned_16;
      Mid_16  : Unsigned_16;
      High_32 : Unsigned_32;
   begin
      -- Extract handler address components
      Low_16  := Unsigned_16 (Handler_Addr and 16#FFFF#);
      Mid_16  := Unsigned_16 (Shift_Right (Handler_Addr, 16) and 16#FFFF#);
      High_32 := Unsigned_32 (Shift_Right (Handler_Addr, 32));

      -- Populate all 256 IDT entries
      for Index in IDT_Table_Base'Range loop
         IDT_Table_Base (Index).Offset_Low := Low_16;
         IDT_Table_Base (Index).Selector := 16#0008#;       -- Kernel code segment
         IDT_Table_Base (Index).IST := 0;                   -- Use RSP0
         IDT_Table_Base (Index).Attributes := 16#8E#;       -- Interrupt gate, P=1, DPL=0
         IDT_Table_Base (Index).Offset_Mid := Mid_16;
         IDT_Table_Base (Index).Offset_high := High_32;
         IDT_Table_Base (Index).Reserved := 0;
      end loop;

      -- Load IDTR register (interrupt descriptor table register)
      -- IDTR format: limit (2B) + base (8B)
      -- Inline assembly loads IDTR with pre-computed pointer
      declare
         IDTR_Limit : constant Unsigned_16 := (256 * 16) - 1;  -- 4096 - 1
         IDTR_Base  : constant System.Address :=
            System.Storage_Elements.To_Address (16#100400#);  -- IDT base address
      begin
         -- Execute: lidt [IDTR_Base]
         -- The IDTR pointer structure is at IDTR_Base: limit (2B) + base (8B)
         -- For now, we'll load it using inline ASM
         null;  -- Placeholder: LIDT will be done from assembly caller
      end;

   end Initialize_IDT;

end IDT_Init;
