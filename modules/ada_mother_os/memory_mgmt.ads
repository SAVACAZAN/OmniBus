-- Memory Management Package Specification
-- =======================================
--
-- Handles paging, memory isolation, and bounds checking
-- Located at 0x103200 in kernel memory

with System;
with Interfaces;
use System;
use Interfaces;

package Memory_Mgmt is

   -- =============================================
   -- CONSTANTS
   -- =============================================

   MEMORY_MGMT_BASE : constant Unsigned_32 := 16#103200#;
   PAGE_SIZE        : constant Unsigned_32 := 16#1000#;  -- 4KB
   PAGE_DIRECTORY   : constant Unsigned_32 := 16#200000#;
   PAGE_TABLES_BASE : constant Unsigned_32 := 16#201000#;

   --  Task memory segments
   KERNEL_START : constant Unsigned_32 := 16#100000#;
   KERNEL_SIZE  : constant Unsigned_32 := 16#10000#;

   GRID_START   : constant Unsigned_32 := 16#110000#;
   GRID_SIZE    : constant Unsigned_32 := 16#20000#;

   ANALYTICS_START : constant Unsigned_32 := 16#150000#;
   ANALYTICS_SIZE  : constant Unsigned_32 := 16#80000#;

   EXECUTION_START : constant Unsigned_32 := 16#130000#;
   EXECUTION_SIZE  : constant Unsigned_32 := 16#20000#;

   -- =============================================
   -- MEMORY BOUNDS CHECKING
   -- =============================================

   --  Check if address is within valid bounds for a task
   function Is_Access_Valid
     (Addr : Unsigned_32;
      Size : Unsigned_32;
      Task_Id : Natural) return Boolean;

   --  Initialize page tables (called once at boot)
   procedure Initialize_Page_Tables;

   --  Flush TLB (Translation Lookaside Buffer)
   procedure Flush_TLB;

   -- =============================================
   -- DIAGNOSTICS
   -- =============================================

   --  Get current page directory address (CR3)
   function Get_Page_Directory return Unsigned_32;

   --  Check if paging is enabled (CR0.PG bit)
   function Is_Paging_Enabled return Boolean;

end Memory_Mgmt;
