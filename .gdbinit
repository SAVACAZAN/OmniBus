# OmniBus Bootloader Debugger Setup
# Auto-switches GDB architecture between Real Mode (16-bit) and Protected Mode (32-bit)

# Connect to QEMU GDB stub
target remote localhost:1234

# Start in 16-bit Real Mode
set architecture i8086
set $in_pm = 0

# Auto-switch architecture based on CR0.PE bit
define hook-stop
    # Check bit 0 of CR0 (PE bit)
    if ($cr0 & 1)
        if $in_pm == 0
            set architecture i386
            set $in_pm = 1
            printf "\n!!! PROTECTED MODE DETECTED - Switched to 32-bit !!!\n"
        end
    else
        if $in_pm == 1
            set architecture i8086
            set $in_pm = 0
            printf "\n!!! REAL MODE DETECTED - Switched to 16-bit !!!\n"
        end
    end
    # Always show current instruction and registers on stop
    printf ">>> PC: 0x%lx\n", $pc
    x/i $pc
end

# Breakpoints for OmniBus memory map
break *0x7c00
commands
silent
printf "\n=== BREAKPOINT: Stage 1 Bootloader (0x7C00) ===\n"
printf "A20 enabled? DL register (drive): 0x%02x\n", $dl & 0xFF
printf "About to load Stage 2...\n"
continue
end

break *0x7e00
commands
silent
printf "\n=== BREAKPOINT: Stage 2 Entry (0x7E00) ===\n"
printf "Stage 2 loaded, about to setup GDT...\n"
continue
end

break *0x100030
commands
silent
printf "\n=== BREAKPOINT: Ada Kernel Entry (0x100030) ===\n"
printf "Protected mode successful! Ada kernel starting...\n"
continue
end

# Special breakpoint for the critical protected mode transition
# Set at the far jump instruction
break *0x7e1a
commands
silent
printf "\n=== CRITICAL: About to execute FAR JUMP to protected mode ===\n"
printf "Current state:\n"
printf "  CR0 = 0x%lx (PE bit: %d)\n", $cr0, ($cr0 & 1)
printf "  CS:IP = 0x%04x:0x%04x\n", $cs, $pc
printf "  GDTR will be loaded from 0x7e00 + offset\n"
end

# Info display
echo \n
echo === OmniBus Bootloader Debugger Loaded ===
echo \n
echo Memory Map:
echo "  0x7C00-0x7DFF:  Stage 1 Bootloader (512B)"
echo "  0x7E00-0x7FFF:  Stage 2 (4KB)"
echo "  0x100000+:      Ada Kernel + OS Layers"
echo \n
echo Key Commands:
echo "  si               Step one instruction (tracks Real/Protected mode)"
echo "  ni               Next instruction (steps over calls)"
echo "  info registers   Show all CPU registers"
echo "  info all-registers  Show even more detailed register info"
echo "  x/i \$pc         Disassemble current instruction"
echo "  x/16i \$pc       Disassemble next 16 instructions"
echo "  monitor info registers  Show QEMU register state including GDTR"
echo \n
echo To debug the triple fault:
echo "  si               Step through protected mode transition"
echo "  When it crashes, use 'info registers' to see final state"
echo \n
