-- Ada Mother OS Kernel Package Specification
-- =============================================
--
-- Purpose: Define the interface contract for the Ada kernel
-- Provides task scheduling, memory isolation, exception handling
--
-- Memory Layout:
--   0x100000: Kernel header (16B)
--   0x100010: Startup code (1KB)
--   0x100050: AUTH GATE (1B) - Must be 0x70 to execute
--   0x100400: Task descriptor table (4KB)
--   0x101400: Exception handlers (6KB)
--   0x102C00: Scheduler state (2KB)
--   0x103200: Memory management (3KB)
--   0x100800: PQC vault - Kyber-512 keys (2KB)
--   0x100C00: Governance state (2KB)
--   Rest: Stack + scratch space (48KB)

with System;
with Interfaces;
use System;
use Interfaces;

package Ada_Kernel is

   -- =============================================
   -- KERNEL CONSTANTS
   -- =============================================

   KERNEL_BASE      : constant Unsigned_32 := 16#100000#;
   KERNEL_SIZE      : constant Unsigned_32 := 16#10000#;  -- 64KB
   AUTH_GATE_ADDR   : constant Unsigned_32 := 16#100050#;
   AUTH_ENABLED     : constant Unsigned_8 := 16#70#;
   PQC_VAULT_ADDR   : constant Unsigned_32 := 16#100800#;
   PQC_VAULT_SIZE   : constant Unsigned_32 := 16#800#;   -- 2KB
   TASK_TABLE_ADDR  : constant Unsigned_32 := 16#100400#;
   MAX_TASKS        : constant := 3;

   -- =============================================
   -- TASK ENUMERATION
   -- =============================================

   type TaskId is (
      Grid_OS,       -- L2: Grid trading engine @ 0x110000
      Analytics_OS,  -- L3: Price aggregation @ 0x150000
      Execution_OS   -- L4: Order signing @ 0x130000
   );

   -- =============================================
   -- TASK STATE TRACKING
   -- =============================================

   type TaskState is (Ready, Running, Blocked, Completed, Error);

   type TaskDescriptor is record
      Id           : TaskId;
      State        : TaskState;
      Entry_Point  : Unsigned_32;
      Memory_Start : Unsigned_32;
      Memory_Size  : Unsigned_32;
      Cycle_Count  : Unsigned_64;
      Error_Count  : Unsigned_32;
      TSC_Last_Run : Unsigned_64;
   end record;

   -- =============================================
   -- MEMORY ISOLATION
   -- =============================================

   type MemoryBounds is record
      Start : Unsigned_32;
      Size  : Unsigned_32;
      Flags : Unsigned_8;  -- read(1) | write(2) | exec(4)
   end record;

   -- =============================================
   -- SCHEDULER STATE
   -- =============================================

   type TaskStateArray is array (TaskId) of TaskState;
   type TaskCycleArray is array (TaskId) of Unsigned_64;
   type TaskErrorArray is array (TaskId) of Unsigned_32;

   type SchedulerState is record
      Current_Task     : TaskId;
      Cycle_Count      : Unsigned_64;
      Task_States      : TaskStateArray;
      Task_Cycle_Count : TaskCycleArray;
      Task_Errors      : TaskErrorArray;
   end record;

   -- =============================================
   -- KERNEL INITIALIZATION
   -- =============================================

   --  Initialize the Ada kernel
   --  Sets up task table, exception handlers, scheduler state
   --  Pre-condition: Paging and GDT are already set up by startup.asm
   --  Post-condition: Kernel is ready to dispatch tasks
   procedure Initialize_Kernel;

   -- =============================================
   -- MAIN EXECUTION LOOP
   -- =============================================

   --  Run the main kernel event loop
   --  Dispatches tasks in round-robin fashion
   --  Never returns (runs until SYS_PANIC or halt)
   procedure Run_Event_Loop;

   --  Run a single kernel cycle
   --  Dispatches one task, waits for completion
   procedure Run_Cycle;

   --  Check authorization gate
   --  Returns True if 0x100050 == 0x70
   function Is_Authorized return Boolean;

   --  Increment global cycle counter
   procedure Increment_Cycle;

   -- =============================================
   -- DIAGNOSTICS & DEBUG
   -- =============================================

   --  Write a single character to UART (0x3F8)
   procedure UART_Write_Char (C : Character);

   --  Write a null-terminated string to UART
   procedure UART_Write_String (S : String);

   --  Write a 32-bit value as hex to UART
   procedure UART_Write_Hex (Value : Unsigned_32);

   --  Panic with error message
   --  Halts the kernel
   procedure Sys_Panic (Message : String);

   -- =============================================
   -- INTERNAL STATE (not exported)
   -- =============================================

   -- Current global cycle counter
   Global_Cycle_Count : Unsigned_64 := 0;
   pragma Volatile (Global_Cycle_Count);

   -- Current kernel state
   Kernel_State : array (0 .. 63) of Unsigned_8 := (others => 0);
   pragma Volatile (Kernel_State);

end Ada_Kernel;
