#!/bin/bash
# quick_build.sh - Compilare rapidă pentru verificare

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo "🚀 Quick Build pentru fișierele extrase"

# Verifică toolchain
for tool in nasm gcc gnat zig; do
    if command -v $tool &> /dev/null; then
        echo "  ✅ $tool"
    else
        echo "  ❌ $tool (lipsește)"
    fi
done

# Test bootloader
if [ -f boot/boot.asm ]; then
    echo -n "Bootloader: "
    nasm -f bin boot/boot.asm -o /tmp/boot.bin 2>/dev/null
    if [ $? -eq 0 ] && [ $(stat -c%s /tmp/boot.bin 2>/dev/null || stat -f%z /tmp/boot.bin) -eq 512 ]; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗${NC}"
    fi
fi

# Test kernel Ada
if [ -f kernel/mother_os.adb ]; then
    echo -n "Kernel Ada: "
    gnatmake -c kernel/mother_os.adb -o /dev/null 2>/dev/null
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗${NC}"
    fi
fi

# Test Zig engines
if [ -f engines/grid_os.zig ]; then
    echo -n "Zig engines: "
    zig build-obj engines/grid_os.zig -fno-emit-bin 2>/dev/null
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗${NC}"
    fi
fi

echo "✅ Quick build complet"
