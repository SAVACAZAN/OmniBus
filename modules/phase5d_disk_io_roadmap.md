# Phase 5D: Real Disk I/O Implementation Roadmap
## From Pattern Fill to BIOS-based Sector Reading

---

## Current Status (Iteration 1)

### What Works ✅
- Disk I/O module compiles and links (`disk_io.asm`)
- `read_sectors_bios()` exported as callable function
- Kernel calls disk I/O via `load_sectors_pio()` → `read_sectors_bios()`
- Currently: Fills memory with 0xABCD pattern (recognizable marker)

### Current Limitations ❌
- No actual disk reads (pattern fill placeholder)
- Real-mode BIOS INT 0x13 wrapper not yet implemented
- Requires switching CPU modes (long mode → real mode → long mode)

---

## Implementation Strategy

### Phase 5D-1: Real-Mode Stub (Current)
```c
// In disk_io.asm
read_sectors_bios(u64 lba, void* buffer, u64 count) -> u64 {
    // Step 1: Save 64-bit state
    // Step 2: Set up trampoline to real mode
    // Step 3: Load real-mode registers from parameters
    // Step 4: Call BIOS INT 0x13 (disk read service 0x02)
    // Step 5: Restore 64-bit long mode
    // Step 6: Return error code or success
}
```

### Phase 5D-2: Real-Mode Trampoline
Required steps to switch modes:

1. **Disable paging** (clear CR0.PG)
2. **Load real-mode GDT** (16-bit selectors)
3. **Load real-mode IDT** (interrupt vectors)
4. **Clear CR4.PAE** (disable physical address extension)
5. **Switch to real mode** (clear CR0.PE)
6. **Far jump to real mode code** (CS:IP in real mode)
7. **Execute INT 0x13** (BIOS disk service)
8. **Switch back**: CR0.PE=1 → protected mode → CR4.PAE=1 → paging → long mode

### Phase 5D-3: BIOS INT 0x13 Parameters
```
Register Setup (for read service 0x02):
AH = 0x02           ; Read sector service
AL = sector_count   ; How many sectors to read
CH = cylinder       ; LBA must be converted to CHS (Cylinder/Head/Sector)
CL = sector
DH = head
DL = drive          ; 0x80 = first hard disk
ES:BX = buffer      ; Physical address in first 1MB
```

---

## Technical Challenges

### 1. Mode Switching Complexity
Switching from 64-bit long mode to real mode and back is non-trivial:
- Must flush TLB (Translation Lookaside Buffer)
- Must update GDT/IDT for real mode
- Requires careful register management
- Stack must be in real-mode addressable memory

**Estimated effort**: 200-300 lines assembly

### 2. LBA to CHS Conversion
Modern systems use LBA (Logical Block Addressing), but BIOS INT 0x13 expects CHS:
```
CHS = LBA to CHS conversion
// For 512-byte sectors:
cylinder = lba / (heads * sectors_per_track)
head = (lba / sectors_per_track) % heads
sector = (lba % sectors_per_track) + 1
```

### 3. Buffer Constraints
BIOS I/O only works with buffers in first 1MB of physical memory:
- Our modules load at 0x110000+ (outside BIOS reach)
- Solution: Use temporary buffer in first 1MB, then copy
- Or: Place modules in first 1MB during early boot only

### 4. Error Handling
BIOS returns error codes in AH:
```
AH = 0x00  : Success
AH = 0x01  : Invalid command
AH = 0x02  : Address mark not found
AH = 0x04  : Sector not found
AH = 0x08  : DMA overrun
AH = 0x09  : DMA crossed 64K boundary
AH = 0x0C  : Invalid media
```

---

## Alternative Approaches

### Option A: AHCI Driver (Recommended for real hardware)
- Modern SATA standard
- Requires PCI enumeration
- Complex but industry-standard
- 500+ lines of code
- Better performance

### Option B: BIOS INT 0x13 Wrapper (Current approach)
- Works on any BIOS-compatible hardware
- Simpler than AHCI (200-300 lines)
- Slower than AHCI
- Reliable for booting

### Option C: Ramdisk / Preload
- Kernel loads all modules into RAM at boot
- No real-time disk I/O needed
- Requires larger boot image
- Simpler to implement

### Option D: Simplified I/O (QEMU-specific)
- QEMU supports BIOS INT 0x13 well
- Can hardcode QEMU drive geometry
- Won't work on real hardware

---

## Next Steps (Phase 5D-2)

### 1. Implement Real-Mode Transition
```asm
; Save current 64-bit state
; Disable paging & protected mode
; Load real-mode GDT
; Load real-mode IDT
; Make far jump to real mode
```

### 2. Implement BIOS Call Wrapper
```asm
; Convert LBA to CHS
; Set up registers for INT 0x13
; Call INT 0x13 (sector read)
; Check error codes
```

### 3. Restore Long Mode
```asm
; Re-enable protected mode
; Reload 64-bit GDT
; Reload 64-bit IDT
; Re-enable paging
; Far jump back to 64-bit code
```

### 4. Testing Strategy
1. Test single sector read (LBA 0 → 0x100000)
2. Test multi-sector reads (Grid OS: LBA 4096, 256 sectors)
3. Verify sector checksums
4. Load actual module binaries, verify magic numbers

---

## Success Criteria

✅ Real disk reads working
- `make qemu` boots with actual module binaries from disk
- No pattern fill (0xABCD), real data instead
- Magic numbers verified: "BLKO" @ 0x250000, "NERO" @ 0x2D0000

✅ Error handling
- Graceful handling of bad sectors
- Timeout recovery
- Retry logic for transient errors

✅ Performance
- Sub-100ms to load all 5 modules
- Deterministic read times

---

## Timeline Estimate

- Phase 5D-1 (current): Mode switching + INT 0x13 wrapper: **3-4 hours**
- Phase 5D-2: Testing + error handling: **1-2 hours**
- Phase 5D-3: Real hardware verification: **2+ hours** (if available)

Total: 6-8 hours for full disk I/O implementation

---

## Current Code

- `disk_io.asm` (105 lines): Placeholder with pattern fill
- `startup_phase4.asm` calls `read_sectors_bios()` at lines 361-378
- Makefile compiles and links disk_io module

Ready for 5D-1 implementation when needed.
