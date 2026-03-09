#!/bin/bash
# quick_test.sh - Testare rapidă a fișierelor extrase

echo "🧪 Quick Test pentru fișierele extrase"

total=$(find . -type f -name "*.asm" -o -name "*.adb" -o -name "*.zig" -o -name "*.c" | wc -l)
echo "Total fișiere sursă: $total"

# Verifică sintaxa pentru fiecare tip
if command -v nasm &> /dev/null; then
    for f in $(find . -name "*.asm"); do
        nasm -f elf64 "$f" -o /dev/null 2>/dev/null && echo "  ✅ $f" || echo "  ❌ $f"
    done
fi

echo "✅ Test complet"
