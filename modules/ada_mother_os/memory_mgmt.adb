-- Memory Management Package Body
-- ===============================

with Interfaces;
use Interfaces;

package body Memory_Mgmt is

   -- =============================================
   -- MEMORY BOUNDS VALIDATION
   -- =============================================

   function Is_Access_Valid
     (Addr : Unsigned_32;
      Size : Unsigned_32;
      Task_Id : Natural) return Boolean
   is
      Addr_Int : Unsigned_32 := Addr;
      End_Addr : Unsigned_32 := Addr_Int + Size;
   begin
      case Task_Id is
         when 0 =>
            --  Kernel access
            return Addr_Int >= KERNEL_START and
                   End_Addr <= KERNEL_START + KERNEL_SIZE;

         when 1 =>
            --  Grid OS access
            return Addr_Int >= GRID_START and
                   End_Addr <= GRID_START + GRID_SIZE;

         when 2 =>
            --  Analytics OS access
            return Addr_Int >= ANALYTICS_START and
                   End_Addr <= ANALYTICS_START + ANALYTICS_SIZE;

         when 3 =>
            --  Execution OS access
            return Addr_Int >= EXECUTION_START and
                   End_Addr <= EXECUTION_START + EXECUTION_SIZE;

         when others =>
            return False;
      end case;
   end Is_Access_Valid;

   -- =============================================
   -- PAGE TABLE INITIALIZATION
   -- =============================================

   procedure Initialize_Page_Tables is
   begin
      --  This is typically called from startup.asm
      --  Ada can verify the setup was done correctly
      null;
   end Initialize_Page_Tables;

   -- =============================================
   -- TLB MANAGEMENT
   -- =============================================

   procedure Flush_TLB is
   begin
      --  In real code, this would use inline ASM:
      --  MOV EAX, CR3
      --  MOV CR3, EAX
      --  (reloading CR3 flushes TLB)
      null;
   end Flush_TLB;

   -- =============================================
   -- DIAGNOSTICS
   -- =============================================

   function Get_Page_Directory return Unsigned_32 is
   begin
      --  In real code: MOV EAX, CR3 via inline ASM
      return PAGE_DIRECTORY;
   end Get_Page_Directory;

   function Is_Paging_Enabled return Boolean is
   begin
      --  In real code: MOV EAX, CR0 and check bit 31
      --  For now, assume enabled (set by startup.asm)
      return True;
   end Is_Paging_Enabled;

end Memory_Mgmt;
