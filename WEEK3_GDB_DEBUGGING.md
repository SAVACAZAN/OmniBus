# Week 3 GDB Debugging Guide - Protected Mode Triple Fault

## Problem Statement
After entering protected mode (CR0.PE = 1), the bootloader triple-faults instead of executing the protected mode code. This happens consistently whether we use a far jump or not.

## Root Cause (Unknown)
Likely candidates:
1. GDT descriptor format or alignment issue
2. Code segment selector (0x08) pointing to invalid or misformatted descriptor
3. Mode mismatch (16-bit code, 32-bit CPU state)
4. Stack or segment register state issue
5. A20 gate, IDT, or other prerequisite not properly initialized

## GDB Debugging Setup

### Prerequisites
- QEMU with GDB stub support: `qemu-system-x86_64 -s` flag
- GDB: `apt install gdb`
- `.gdbinit` file (auto-created in project root)
- `debug_qemu.sh` script (auto-created in project root)

### Step 1: Launch QEMU with GDB Stub
```bash
./debug_qemu.sh &
# OR manually:
qemu-system-x86_64 -m 256 -S -s -d int,cpu_reset \
    -drive format=raw,file=build/omnibus.iso \
    -chardev stdio,id=ser0 -device isa-serial,chardev=ser0 \
    -monitor none -nographic
```

The `-S` flag freezes the CPU at startup.
The `-s` flag enables GDB stub on `localhost:1234`.
The `-d int,cpu_reset` flag logs interrupts and CPU resets (critical for diagnosing triple faults).

### Step 2: Connect GDB (in another terminal)
```bash
gdb -x .gdbinit
```

The `.gdbinit` script will:
- Auto-connect to QEMU
- Load breakpoints at 0x7C00, 0x7E00, 0x100030
- Switch between 16-bit and 32-bit architecture as needed
- Display register states at each breakpoint

### Step 3: Debug the Protected Mode Transition

**Continue to Stage 2:**
```
(gdb) c
# Execution continues until first breakpoint
```

**Step through the critical protected mode code:**
```
(gdb) si
# Step one instruction at a time

# Watch for the moment when it crashes
# GDB will show "Remote connection closed" on triple fault
```

**Inspect registers at any point:**
```
(gdb) info registers
# Shows CS, DS, ES, FS, GS, SS, CR0, CR3, etc.

(gdb) info all-registers
# Even more detailed register info

(gdb) x/i $pc
# Disassemble the current instruction

(gdb) x/16i $pc
# Disassemble next 16 instructions
```

**Check QEMU's view of the GDT:**
```
(gdb) monitor info registers
# Shows GDTR (GDT register) value
```

## Critical Inspection Points

### Before Protected Mode Entry
At breakpoint `0x7e00` (Stage 2 entry), verify:
- A20 line enabled (should be, from Stage 1)
- Stack pointer reasonable (not zero)
- All segments set up correctly

### Before Far Jump
At the instruction before the far jump (around `0x7e1a`):
- Print CR0 value (should have PE bit about to be set)
- Verify GDT descriptor address in memory
- Check that the GDT descriptors are properly formatted

### After CR0.PE Set (CRITICAL)
```
(gdb) si
# After: mov cr0, eax    <- Set PE bit
(gdb) info registers
# CR0 should now have PE=1 (bit 0 = 1)
# CS should still be 0x0000 (real mode selector)
# IP should point to next instruction

(gdb) si
# Execute the next instruction (far jump)
# If this crashes, GDB prints "Remote connection closed"
```

### If Triple Fault Occurs
When you see "Remote connection closed" or "Remote closed", the QEMU terminal may show:
```
check_exception old_exception=0xffffffff
```

This means QEMU hit a CPU exception. Look at the QEMU output window for the exact exception code.

## Common Causes & Fixes

| Symptom | Likely Cause | Fix |
|---------|--------------|-----|
| Crashes after `mov cr0, eax` | GDT invalid or PE bit causes immediate fault | Check GDT format, ensure descriptors are 8 bytes each |
| Crashes after far jump | Segment selector invalid | Verify GDT entry for 0x08 is a valid code descriptor |
| Crashes in protected mode code | Mode mismatch (16-bit code, 32-bit CPU) | Ensure `[BITS 32]` is set in assembly before protected mode code |
| Crashes with "no valid IDT" | Interrupt after PE bit before IDT loaded | Ensure `CLI` is executed and `LIDT` happens immediately |
| Stack issues | Stack pointer in bad location | Verify `ESP` is set to a valid address in protected mode |

## Expected Success Indicators

When the protected mode transition works:
1. GDB continues stepping without "Remote connection closed"
2. CS register changes from 0x0000 to 0x0008 (or your code selector)
3. CPU continues executing the protected mode code (starting with segment register setup)
4. Eventually reaches the Ada kernel at 0x100030

## Next Steps After Debugging

Once you identify the exact instruction causing the triple fault:
1. Compare your GDT entry with a known-good example
2. Verify the exact format of the descriptor (8 bytes, all fields correct)
3. Check for off-by-one errors in address calculations
4. Verify NASM is generating the correct bytecode for the GDT

## Emergency Backup Plan

If GDB debugging proves too difficult:
1. Try a different bootloader (e.g., from OSDev.org Bare Bones tutorial)
2. Temporarily use BIOS calls to stay in real mode longer
3. Use a simpler paging setup (don't enable paging immediately)
4. Skip protected mode entirely and use long mode (64-bit) directly

---

**Status**: Ready for next session debugging
**Created**: 2026-03-10
**Owner**: Week 3 Development Team
