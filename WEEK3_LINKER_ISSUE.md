# Week 3: UART Output Linker Issue - Debugging Notes

**Date**: 2026-03-10
**Issue**: OUT instruction mysteriously stripped during linking
**Status**: Investigation Required
**Severity**: BLOCKING (prevents UART output, delays testing)

---

## Problem Statement

The OUT x86 instruction (opcode 0xEE) for UART output is present in object files but disappears in the final linked binary.

### Evidence

**In startup_new.o (object file):**
```
Disassembly:
00000000000000db <uart_write_byte>:
  db:	40 88 f8             	mov    %dil,%al
  de:	66 ba f8 03          	mov    $0x3f8,%dx
  e2:	ee                	out    %al,(%dx)      ← Instruction EXISTS
  e3:	c3                	ret

Hexdump:
00000290  ... 40 88 f8 66 ba f8 03 ee c3 ...
                                   ^^
```

**In kernel_test.elf (final binary):**
```
Disassembly:
00000000001000eb <uart_write_byte>:
  1000eb:	40 88 f8             	mov    %dil,%al
  1000ee:	66 ba f8 03          	mov    $0x3f8,%dx
  1000f2:	c3                	ret
                           ↑ Instruction MISSING, jumps straight to ret

Hexdump:
 1000e0: ... 40 88 f8 66 ba f8 03 c3 ...
                                 ^^ (no 0xee before c3)
```

### Impact

- `ada_kernel__uart_write_char` calls `uart_write_byte` (verified in disassembly)
- Calls execute but produce no output
- Bootloader messages work (proves UART port is accessible)
- Ada kernel initializes but no "[KERN]" messages appear

---

## Theories & Investigation Steps

### Theory 1: Linker Script Stripping Sections
**Hypothesis**: kernel.ld is not including all sections from startup_new.o

**Investigation**:
```bash
# Check what sections are in object file
objdump -h startup_new.o | grep -E "\.text|\.rodata"

# Check final sections
objdump -h kernel_test.elf | grep -E "\.text|\.rodata"

# Compare sizes to see if data is missing
```

**Result**: .text section size in final ELF appears correct (0x1129 bytes)

### Theory 2: GCC/LD Garbage Collection
**Hypothesis**: Linker is removing "unreachable" code

**Investigation**:
```bash
# Try linking without garbage collection
ld --help | grep -i "gc-section"
# Regenerate with: ld -T kernel.ld ... --noinhibit-exec --verbose

# Check for linker warnings
ld -T kernel.ld ... 2>&1 | grep -i "warning\|error\|discard"
```

**Result**: No GC-related warnings observed

### Theory 3: Address/Relocation Issue
**Hypothesis**: Linker relocating code and discarding stub bytes

**Investigation**:
```bash
# Check relocations in object file
readelf -r startup_new.o | grep uart_write_byte

# Check symbol addresses
nm -n startup_new.o | grep uart_write_byte
nm -n kernel_test.elf | grep uart_write_byte

# Detailed objdump with addresses
objdump -d -M intel startup_new.o | grep -A10 uart_write_byte
objdump -d -M intel kernel_test.elf | grep -A10 uart_write_byte
```

### Theory 4: NASM/Assembly Issue
**Hypothesis**: The `out dx, al` instruction isn't being encoded correctly

**Investigation**:
```bash
# Create minimal test file
cat > /tmp/uart_test.asm << 'EOF'
BITS 64
mov al, 0x41
mov dx, 0x3F8
out dx, al
ret
EOF

# Assemble and check
nasm -f elf64 /tmp/uart_test.asm -o /tmp/uart_test.o
objdump -d /tmp/uart_test.o

# Compare with our version
objdump -d startup_new.o | grep -A5 "uart_write_byte"
```

**Result**: Minimal test assembles correctly with 0xEE instruction present

---

## Attempted Fixes (Failed)

### Attempt 1: Inline Assembly in Ada
```ada
Asm ("out %0, %1",
     Inputs => (Unsigned_8'Asm_Input ("a", B),
                Unsigned_16'Asm_Input ("d", Port)),
     Volatile => True);
```
**Result**: Assembler truncated 0x3F8 to 0xF8

### Attempt 2: AT&T Syntax
```ada
Asm ("outb %%al, %%dx", ...)
```
**Result**: Multiple assembly errors with operand format

### Attempt 3: Raw Machine Code in Ada
```ada
db 0xEE;  -- in Ada syntax
```
**Result**: Ada doesn't support this syntax

### Attempt 4: Assembly External Procedure
```asm
GLOBAL uart_write_byte
uart_write_byte:
    mov al, dil
    mov dx, 0x3F8
    out dx, al      ← This line vanishes
    ret
```
**Result**: Instruction present in .o file but stripped during linking

---

## Diagnostic Commands

Use these to investigate further:

```bash
# Full comparison of both files
cd /home/kiss/OmniBus/modules/ada_mother_os
echo "=== Object file ===" && objdump -d startup_new.o | grep -A6 "uart_write_byte"
echo "=== Final ELF ===" && objdump -d kernel_test.elf | grep -A6 "uart_write_byte"

# Raw bytes
echo "=== Object bytes ===" && hexdump -C startup_new.o | grep -A1 "40 88"
echo "=== ELF bytes ===" && hexdump -C kernel_test.elf | grep -A1 "40 88"

# Symbols
echo "=== Object symbols ===" && nm -n startup_new.o | grep uart
echo "=== ELF symbols ===" && nm -n kernel_test.elf | grep uart

# Relocations
readelf -r startup_new.o | head -20
readelf -r kernel_test.elf | head -20

# Section details
objdump -s -j .text startup_new.o | grep -A3 "1000e"
objdump -s -j .text kernel_test.elf | grep -A3 "1000e"
```

---

## Alternative Approaches to Try

### Option A: Rewrite in C with inline assembly
```c
void uart_write_byte(unsigned char byte) {
    asm volatile("out %%al, %%dx" : : "a"(byte), "d"(0x3F8));
}
```
- Compile with gcc
- Link the C object file
- Call from Ada as C function

**Pros**: More portable, better compiler support
**Cons**: Adds C dependency

### Option B: Use GNAT inline assembly correctly
- Research GNAT-specific inline asm syntax
- Try pragma Export_Function with C calling convention
- Use volatile attribute correctly

### Option C: Skip UART, Use GDB Instead
- Boot in QEMU with GDB stub
- Connect gdb and examine memory/registers
- Verify kernel is running via CPU state
- Continue development without UART feedback

### Option D: Verify with Simpler Output
- Write pattern to memory address (e.g., 0x100100)
- Boot and use `memory` command in QEMU monitor
- Check if bytes were written (proves code executed)

---

## Resolution Checklist

- [ ] Run diagnostic commands above
- [ ] Check if other procedures with assembly work
- [ ] Try C inline assembly fallback
- [ ] Consult GNAT documentation on inline ASM
- [ ] Verify linker script includes all sections
- [ ] Try alternate linker (ld.gold) if available
- [ ] Use QEMU monitor commands to inspect memory
- [ ] Check for undefined symbols preventing linking

---

## GIT References

**Branch**: main
**Commit with issue**: 262faa5 (Week 3 Phase 1)
**Test files**:
- startup_new.o (good - has 0xEE)
- kernel_test.elf (bad - missing 0xEE)

**Key files**:
- modules/ada_mother_os/startup.asm (uart_write_byte routine)
- modules/ada_mother_os/ada_kernel.adb (UART_Out_Byte wrapper)
- modules/ada_mother_os/kernel.ld (linker script)

---

## Next Session Instructions

1. Start with Diagnostic Commands above to understand current state
2. Try "Option A" (C inline assembly) as quickest fix
3. If UART works after that: run make qemu to test
4. Verify "[KERN]" messages appear in output
5. Continue with Week 3 Task Dispatch Loop testing

---

**Owner**: Claude Haiku 4.5 (Week 3 Phase 1)
**Status**: Awaiting resolution
**Priority**: HIGH (blocking all further testing)
