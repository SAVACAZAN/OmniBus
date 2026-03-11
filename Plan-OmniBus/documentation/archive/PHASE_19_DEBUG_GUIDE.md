# Phase 19: Module Execution Debugging Guide

## Problem Statement
Direct calls to module code (`call 0x1111f0`, `jmp rax` where rax=module_addr) cause system restart. However:
- Code IS readable and present at those addresses
- Page tables have execute permission
- Exception handler is loaded

## Debugging Steps (Manual)

### Step 1: Boot with GDB
```bash
# Terminal 1: Start QEMU with GDB stub
cd /home/kiss/OmniBus
timeout 120 qemu-system-x86_64 -m 256 -drive format=raw,file=./build/omnibus.iso \
  -serial mon:stdio -gdb tcp::1234,server,wait

# Terminal 2: Connect GDB
gdb build/kernel.elf
(gdb) target remote localhost:1234
(gdb) set architecture i386:x86-64
```

### Step 2: Set Breakpoints
```gdb
# Break just before BlockchainOS scheduling (around cycle 256)
(gdb) break *0x100000+0x4d5

# Break at actual call location
(gdb) break *0x100000+0x4d8

# Add module symbols
(gdb) add-symbol-file build/grid_os.elf 0x110000
(gdb) add-symbol-file build/blockchain_os.elf 0x250000
(gdb) add-symbol-file build/neuro_os.elf 0x2d0000
```

### Step 3: Inspect State Before Failed Call
When breakpoint hits, run these commands:

```gdb
# CPU state
(gdb) info registers
(gdb) print/x $cs
(gdb) print/x $ss
(gdb) print/x $ds
(gdb) print/x $es
(gdb) print/x $fs
(gdb) print/x $gs

# Check GDT (assuming GDT at 0x100000+offset)
(gdb) x/16gx 0x100110

# Check IDT
(gdb) x/16gx 0x100110+0x6c0

# Read from target address (should work)
(gdb) x/8i 0x250a20

# Check paging
(gdb) print/x $cr3
(gdb) print/x $cr0
```

### Step 4: Step Through the Call
```gdb
# Step to the actual call instruction
(gdb) si

# If CPU state shows issue, inspect:
(gdb) disassemble $pc-20,$pc+20

# Check exception flags
(gdb) print/x $eflags
```

## Expected Findings

### Good Scenario
- CS selector points to valid code descriptor
- RIP advances to 0x250a20
- No exception flags set

### Bad Scenario (What We Expect)
- Exception flag set in EFLAGS
- CPU exception occurred but not caught
- GDT descriptor issues visible
- Page fault indication

## Key Registers to Watch

| Register | Meaning | Expected |
|----------|---------|----------|
| CS | Code segment selector | 0x08 (kernel code) |
| SS | Stack segment selector | 0x10 (kernel data) |
| RIP | Instruction pointer | Should advance to 0x250a20 |
| CR0.PE | Protected mode | 1 (enabled) |
| CR0.PG | Paging | 1 (enabled) |
| EFLAGS.IF | Interrupts enabled | 1 |
| EFLAGS.TF | Trap flag | 0 (unless stepping) |

## Possible Root Causes

### 1. GDT Descriptor Issue
```gdb
# Check code descriptor at offset CS>>3 in GDT
# For CS=0x08: offset is 0x08, GDT entry 1
(gdb) x/2gx 0x100000+0x110+0x08
# Should show: 00AF9A000000FFFF (L=1 for 64-bit)
```

### 2. Page Fault on Execute
```gdb
# Check if module pages are mapped
(gdb) print/x *(unsigned long*)0x201000  # PML4[0]
(gdb) print/x *(unsigned long*)0x202000  # PDPT[0]
(gdb) print/x *(unsigned long*)0x203008  # PD[1] (covers 0x200000-0x3FFFFF)
# Should show: 0x200083 (PS=1, RW=1, P=1, NX=0)
```

### 3. Exception Not Caught
```gdb
# Check if IDT is properly loaded
(gdb) info registers gdtr
(gdb) x/16gx 0x100000+IDT_OFFSET
# All gates should point to exception_handler_stub
```

## Commands to Add to GDB Script

```gdb
define show-state
  printf "=== CPU STATE ===\n"
  printf "RIP: 0x%lx\n", $rip
  printf "RSP: 0x%lx\n", $rsp
  printf "CS:  0x%x  DS: 0x%x  SS: 0x%x\n", $cs, $ds, $ss
  printf "CR0: 0x%lx\n", $cr0
  printf "CR3: 0x%lx\n", $cr3
  printf "EFLAGS: 0x%lx\n", $eflags
end

define check-gdt
  printf "=== GDT CHECK ===\n"
  printf "Code desc (offset 0x08): "
  print/x *(unsigned long*)(0x100000+0x110+0x08)
  printf "Data desc (offset 0x10): "
  print/x *(unsigned long*)(0x100000+0x110+0x10)
end

define check-paging
  printf "=== PAGING CHECK ===\n"
  printf "PML4[0]: "
  print/x *(unsigned long*)0x201000
  printf "PDPT[0]: "
  print/x *(unsigned long*)0x202000
  printf "PD[1]:   "
  print/x *(unsigned long*)0x203008
end
```

## Next Steps After Debugging

Based on findings:
1. **If GDT issue:** Fix descriptor (set L bit, verify limit)
2. **If page fault:** Enable execute permission or reload TLB
3. **If exception not caught:** Fix IDT or exception handler
4. **If something else:** Implement Phase 19B workaround

## References
- GDB x86-64 debugging: https://sourceware.org/gdb/
- x86-64 System V ABI: https://refspecs.linuxfoundation.org/
- Intel SDM (§ 4.5 Paging, § 5 Protection)
