-- Task Scheduler Package Specification
-- ====================================
--
-- Manages task scheduling, round-robin fairness, and task state
-- Located at 0x102C00 in kernel memory

with System;
with Interfaces;
use System;
use Interfaces;

package Scheduler is

   -- =============================================
   -- SCHEDULER CONSTANTS
   -- =============================================

   SCHED_BASE : constant Unsigned_32 := 16#102C00#;
   SCHED_SIZE : constant Unsigned_32 := 16#800#;  -- 2KB

   -- =============================================
   -- TASK STATES
   -- =============================================

   type TaskState is (Ready, Running, Blocked, Completed, Error);

   -- =============================================
   -- SCHEDULER OPERATIONS
   -- =============================================

   --  Initialize scheduler state
   procedure Initialize_Scheduler;

   --  Get next task to run (round-robin)
   function Get_Next_Task return Natural;

   --  Mark a task as ready
   procedure Mark_Task_Ready (Task_Id : Natural);

   --  Mark a task as blocked
   procedure Mark_Task_Blocked (Task_Id : Natural);

   --  Mark a task as completed
   procedure Mark_Task_Completed (Task_Id : Natural);

   --  Get task state
   function Get_Task_State (Task_Id : Natural) return TaskState;

   --  Increment task cycle counter
   procedure Increment_Task_Cycles (Task_Id : Natural);

   --  Get total task cycles executed
   function Get_Task_Cycles (Task_Id : Natural) return Unsigned_64;

end Scheduler;
