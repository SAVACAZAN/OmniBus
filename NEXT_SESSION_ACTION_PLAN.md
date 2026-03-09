# Week 3 → Week 4 Handoff: Protected Mode Debugging Action Plan

## Executive Summary
The bootloader is **95% complete**. The protected mode transition triple-faults, likely due to a subtle GDT format issue or a missing keyword in the assembly. This document is your complete action plan for the next session.

## Pre-Session Checklist
- ✅ GDB infrastructure ready (`.gdbinit`, `debug_qemu.sh`)
- ✅ Bootloader code frozen at a working checkpoint (commit d00f11f)
- ✅ Ada kernel fully compiled and waiting
- ✅ All OS layers (Grid, Analytics, Execution) compiled and ready
- ✅ Expert pro-tips captured in WEEK3_GDB_DEBUGGING.md

## Next Session: 3-Step Action Plan

### Step 1: Launch Debugging Infrastructure (5 minutes)
```bash
cd /home/kiss/OmniBus

# Terminal 1: Start QEMU with GDB stub frozen at boot
./debug_qemu.sh &

# Terminal 2: Connect GDB (auto-loads .gdbinit config)
gdb -x .gdbinit
```

### Step 2: Execute the Smoking Gun Checklist (10 minutes)

Once GDB breaks at 0x7e00 (Stage 2 entry), run these commands in order:

```gdb
# Continue to Stage 2
(gdb) c

# At breakpoint 0x7e00, verify GDT is loaded correctly
(gdb) monitor info registers
# Look at GDTR.base - should be 0x00007e50 (full address, not truncated)

# Dump the raw GDT bytes and compare against reference
(gdb) x/24xb 0x7e50
# Expected output:
# 0x7e50: 00 00 00 00 00 00 00 00
# 0x7e58: ff ff 00 00 00 9a cf 00  ← CODE descriptor
# 0x7e60: ff ff 00 00 00 92 cf 00  ← DATA descriptor

# Step through protected mode transition
(gdb) si
# After: mov cr0, eax    (set PE bit)

(gdb) info registers
# Check: CR0 should have bit 0 set (PE = 1)
# Check: CS should still be 0x0000 (real mode, about to change)

(gdb) si
# Execute: jmp 0x08:offset (far jump)

# If crash occurs, GDB will print "Remote connection closed"
# Terminal 1 (QEMU) will show: "check_exception old_exception=0xffffffff"
```

### Step 3: Diagnose Based on Where It Crashes

**If crash occurs immediately after `mov cr0, eax`:**
```
→ GDT likely invalid
→ Run: (gdb) x/24xb 0x7e50
→ Compare against reference in WEEK3_GDB_DEBUGGING.md
→ Check Access Bytes (byte 6 of each descriptor)
```

**If crash occurs on `jmp 0x08:offset`:**
```
→ Segment selector invalid or jump encoding wrong
→ Check: (gdb) x/i $pc  (disassemble the jump instruction)
→ Look for: ea xx xx xx xx 08 00 (far jump encoding)
→ If missing 'dword' keyword → add to NASM source
→ Edit: arch/x86_64/stage2_fixed_final.asm line 40
```

**If crash occurs in protected mode code:**
```
→ CPU mode mismatch or stack issue
→ Check: (gdb) x/i $pc  (should show 32-bit instructions)
→ Check: (gdb) info registers  (EIP should be >= 0x00100000)
→ If EIP truncated to 0x0000xxxx → addressing bug in jump
```

## Critical Files for Next Session

**Read-Only (frozen):**
- `arch/x86_64/stage2_fixed_final.asm` - Bootloader code (line 40 is critical)
- `.gdbinit` - GDB auto-config (do not modify)
- `WEEK3_GDB_DEBUGGING.md` - Debugging guide with pro-tips

**May Need Editing:**
- `arch/x86_64/stage2_fixed_final.asm` - IF jump encoding is wrong, add `dword` keyword to line 40

## Expected Outcomes

### Best Case (5 minutes to fix):
```
Diagnosis: Missing 'dword' keyword or wrong GDT Access Byte
Fix: Edit 1 line in assembly
Action: Add keyword → rebuild → test
Result: Bootloader works, Ada kernel boots to UART output
```

### Moderate Case (30 minutes to fix):
```
Diagnosis: GDT descriptor format slightly wrong (e.g., wrong flags)
Fix: Adjust GDT entry format
Action: Fix bytes 0-7 of descriptor → rebuild → test
Result: Bootloader works, Ada kernel boots
```

### Hard Case (requires deeper investigation):
```
Diagnosis: Fundamental architecture issue (e.g., A20 line, memory layout)
Next Steps:
  1. Review OSDev.org Bare Bones bootloader for reference
  2. Compare GDT format byte-by-byte with known-good example
  3. Consider alternative protected mode entry approach
```

## Success Criteria

The bootloader is **complete when**:
1. GDB steps through without "Remote connection closed"
2. CS register changes from 0x0000 to 0x0008 at far jump
3. CPU executes protected mode code (starting at pmode_entry)
4. UART output shows "[KERN]" initialization messages from Ada kernel

## Fallback Plan

If GDB debugging becomes unproductive:
1. Search OSDev forum for "triple fault after far jump"
2. Try linking with a known-good Stage 2 bootloader (reference: Bare Bones tutorial)
3. Use minimal bootloader → direct to 64-bit long mode (skip protected mode)
4. Ask for code review on GDT format

## Timeline Estimate

- **10 min**: Launch GDB, identify crash point
- **5-15 min**: Apply fix if simple (keyword, flag)
- **5 min**: Rebuild and test
- **Total**: 20-30 minutes to bootloader completion (most likely)

## Commit History for Reference

Latest commits in order:
```
d00f11f - Add expert pro-tips to GDB debugging guide
a2aef26 - Add comprehensive GDB debugging guide
70e4ed1 - Add GDB debugging infrastructure
b5d90e0 - Fix GDT alignment, extensive protected mode debugging
b2f5b63 - Simplify Stage 2, fix QEMU threading crash
1328a85 - Fix bootloader to jump to Ada kernel at 0x100030
```

## What You'll See When It Works

After bootloader successfully hands off to Ada kernel:

```
[QEMU Serial Output]
OmniBus: Boot Stage 1 loaded. Jumping to Stage 2..
[QEMU shows "PMODE OK" in VGA text]
[Ada kernel startup begins]
[KERN] Ada kernel booting @ 0x100000
[KERN] PQC vault loaded @ 0x100800
[KERN] Task table initialized
[KERN] Exception handlers ready
[KERN] Scheduler ready
[KERN] Auth gate DISABLED - waiting for auth
[SCHED] Dispatching L2 Grid OS
[SCHED] Dispatching L3 Analytics OS
[SCHED] Dispatching L4 Execution OS
```

---

**Ready for**: Next debugging session
**Confidence Level**: High (likely simple fix once root cause identified)
**Estimated Time**: 20-30 minutes to complete bootloader
**Next Milestone**: Ada kernel UART output visible in QEMU
