-- Task Scheduler Package Body
-- ============================

with Interfaces;
use Interfaces;

package body Scheduler is

   -- =============================================
   -- SCHEDULER STATE (at 0x102C00)
   -- =============================================

   Current_Task : Natural := 0;
   pragma Volatile (Current_Task);

   Cycle_Counter : Unsigned_64 := 0;
   pragma Volatile (Cycle_Counter);

   type Task_Cycle_Array is array (0 .. 2) of Unsigned_64;
   Task_Cycles : Task_Cycle_Array := (others => 0);
   pragma Volatile (Task_Cycles);

   type Task_State_Array is array (0 .. 2) of TaskState;
   Task_States : Task_State_Array := (others => Ready);
   pragma Volatile (Task_States);

   -- =============================================
   -- INITIALIZATION
   -- =============================================

   procedure Initialize_Scheduler is
   begin
      Current_Task := 0;
      Cycle_Counter := 0;
      Task_Cycles := (others => 0);
      Task_States := (Ready, Ready, Ready);
   end Initialize_Scheduler;

   -- =============================================
   -- TASK SELECTION (ROUND-ROBIN)
   -- =============================================

   function Get_Next_Task return Natural is
      Next : Natural;
   begin
      --  Simple round-robin: 0 → 1 → 2 → 0 → ...
      Next := (Current_Task + 1) mod 3;
      Current_Task := Next;
      return Next;
   end Get_Next_Task;

   -- =============================================
   -- TASK STATE MANAGEMENT
   -- =============================================

   procedure Mark_Task_Ready (Task_Id : Natural) is
   begin
      if Task_Id < 3 then
         Task_States (Task_Id) := Ready;
      end if;
   end Mark_Task_Ready;

   procedure Mark_Task_Blocked (Task_Id : Natural) is
   begin
      if Task_Id < 3 then
         Task_States (Task_Id) := Blocked;
      end if;
   end Mark_Task_Blocked;

   procedure Mark_Task_Completed (Task_Id : Natural) is
   begin
      if Task_Id < 3 then
         Task_States (Task_Id) := Completed;
      end if;
   end Mark_Task_Completed;

   function Get_Task_State (Task_Id : Natural) return TaskState is
   begin
      if Task_Id < 3 then
         return Task_States (Task_Id);
      else
         return Error;
      end if;
   end Get_Task_State;

   -- =============================================
   -- CYCLE TRACKING
   -- =============================================

   procedure Increment_Task_Cycles (Task_Id : Natural) is
   begin
      if Task_Id < 3 then
         Task_Cycles (Task_Id) := Task_Cycles (Task_Id) + 1;
      end if;
   end Increment_Task_Cycles;

   function Get_Task_Cycles (Task_Id : Natural) return Unsigned_64 is
   begin
      if Task_Id < 3 then
         return Task_Cycles (Task_Id);
      else
         return 0;
      end if;
   end Get_Task_Cycles;

end Scheduler;
