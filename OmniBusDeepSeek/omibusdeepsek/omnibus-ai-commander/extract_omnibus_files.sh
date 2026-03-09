#!/bin/bash
# extract_omnibus_files.sh - Extrage și organizează toate fișierele OmniBus

# Culori pentru output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     OMNIBUS - EXTRACTOR ȘI ORGANIZATOR FIȘIERE v1.0        ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"

# Verifică argumente
INPUT_FILE="$1"
if [ -z "$INPUT_FILE" ]; then
    echo -e "${YELLOW}📂 Folosire: $0 <fișier_exportat> (html/markdown/json)${NC}"
    echo -e "   Exemplu: $0 conversatie.html"
    exit 1
fi

if [ ! -f "$INPUT_FILE" ]; then
    echo -e "${RED}❌ Fișierul $INPUT_FILE nu există!${NC}"
    exit 1
fi

echo -e "${GREEN}📄 Procesez fișierul: $INPUT_FILE${NC}"

# Creează directorul principal
OUTPUT_DIR="omnibus_extracted_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$OUTPUT_DIR"
echo -e "${GREEN}📁 Director output: $OUTPUT_DIR${NC}"

# Creează subdirectoare pentru fiecare categorie
declare -A categories=(
    ["boot"]="Bootloader (ASM)"
    ["kernel"]="Kernel Ada/SPARK"
    ["engines"]="Engines Zig"
    ["drivers"]="Drivere C/ASM"
    ["plugins"]="Plugin-uri Zig"
    ["blockchain"]="Module Blockchain"
    ["sdk"]="SDK și Bridge"
    ["dashboard"]="Dashboard TypeScript/React"
    ["cloud"]="Cloud și Kubernetes"
    ["tests"]="Scripturi test"
    ["docs"]="Documentație"
    ["scripts"]="Scripturi utilitare"
    ["certificates"]="Certificate și chei"
)

for dir in "${!categories[@]}"; do
    mkdir -p "$OUTPUT_DIR/$dir"
    echo -e "  📁 Creat: ${YELLOW}$dir${NC} - ${categories[$dir]}"
done

# Funcție pentru curățarea numelor de fișiere
clean_filename() {
    echo "$1" | sed 's/[^a-zA-Z0-9._-]/_/g'
}

# Funcție pentru detectarea tipului de fișier din conținut
detect_file_type() {
    local content="$1"
    local filename="$2"
    
    # După extensie
    case "$filename" in
        *.asm|*.S) echo "assembly"; return ;;
        *.adb|*.ads) echo "ada"; return ;;
        *.zig) echo "zig"; return ;;
        *.c|*.h) echo "c"; return ;;
        *.cpp|*.hpp) echo "cpp"; return ;;
        *.ts|*.tsx) echo "typescript"; return ;;
        *.js|*.jsx) echo "javascript"; return ;;
        *.py) echo "python"; return ;;
        *.rs) echo "rust"; return ;;
        *.go) echo "golang"; return ;;
        *.erl|*.hrl) echo "erlang"; return ;;
        *.sh) echo "bash"; return ;;
        *.yaml|*.yml) echo "yaml"; return ;;
        *.json) echo "json"; return ;;
        *.md) echo "markdown"; return ;;
        *.txt) echo "text"; return ;;
    esac
    
    # După conținut (heuristics)
    if [[ "$content" == *"[BITS"* ]] || [[ "$content" == *"section .text"* ]]; then
        echo "assembly"
    elif [[ "$content" == *"with Ada."* ]] || [[ "$content" == *"procedure "* ]]; then
        echo "ada"
    elif [[ "$content" == *"const std = @import"* ]]; then
        echo "zig"
    elif [[ "$content" == *"#include <"* ]] || [[ "$content" == *"int main("* ]]; then
        echo "c"
    elif [[ "$content" == *"import React"* ]] || [[ "$content" == *"export const"* ]]; then
        echo "typescript"
    elif [[ "$content" == *"#!/bin/bash"* ]]; then
        echo "bash"
    elif [[ "$content" == *"apiVersion:"* ]] || [[ "$content" == *"kind: Deployment"* ]]; then
        echo "yaml"
    else
        echo "unknown"
    fi
}

# Funcție pentru determinarea categoriei după nume
get_category() {
    local filename="$1"
    
    case "$filename" in
        *boot*|*stage2*|*gdt*|*context*) echo "boot" ;;
        *mother_os*|*pqc_vault*|*governance*|*arbiter*|*legacy*) echo "kernel" ;;
        *grid_os*|*analytic_os*|*neuro_os*|*consensus*) echo "engines" ;;
        *nic_driver*|*uart_driver*|*crypto_sign*|*network_ghost*) echo "drivers" ;;
        *multi_exchange*|*stealth_ghost*|*egld*|*private_strategy*|*chaos_monkey*|*arb_engine*|*netcool*) echo "plugins" ;;
        *btc*|*eth*|*sol*|*egld*|*icp*) echo "blockchain" ;;
        *bridge*|*omnibus_sdk*|*setup*|*hot_swap*) echo "sdk" ;;
        *App*|*Chart*|*Panic*|*Neuro*|*RealTime*) echo "dashboard" ;;
        *deployment*|*sel4*|*omnibus_sup*|*chaos_monitor*) echo "cloud" ;;
        *test*|*benchmark*|*gdb_script*) echo "tests" ;;
        *CLAUDE*|*IMPLEMENTATION*|*DSL*|*PROTECTION*|*API*|*TUTORIALS*|*Genesis*|*architecture*|*final_report*) echo "docs" ;;
        *generate*|*build*|*clean*|*ipfs*|*join*|*legacy_activate*) echo "scripts" ;;
        *cert*|*master_key*|*legacy_config*) echo "certificates" ;;
        *) echo "unknown" ;;
    esac
}

# Contorizare
total_files=0
declare -A category_count

# Citește fișierul linie cu linie și extrage blocurile de cod
echo -e "${BLUE}🔍 Extrag fișierele din conversație...${NC}"

# Pattern pentru blocuri de cod (funcționează pentru HTML, Markdown, JSON)
in_code_block=0
current_filename=""
current_content=""
line_num=0

while IFS= read -r line; do
    line_num=$((line_num + 1))
    
    # Detectare început bloc cod în HTML
    if [[ "$line" =~ \<div\ class=\"code-header\"\>📄\ ([^\<]+)\<\/div\> ]]; then
        current_filename=$(clean_filename "${BASH_REMATCH[1]}")
        in_code_block=1
        current_content=""
        continue
    fi
    
    # Detectare început bloc cod în Markdown (```lang)
    if [[ "$line" =~ ^\`\`\`[a-zA-Z0-9]*$ ]] && [ $in_code_block -eq 0 ]; then
        in_code_block=1
        current_content=""
        continue
    fi
    
    # Detectare început bloc cod în JSON (câmp "content")
    if [[ "$line" =~ \"content\"[:space:]*\"(.*) ]] && [ $in_code_block -eq 0 ]; then
        in_code_block=1
        current_content="${BASH_REMATCH[1]}"
        continue
    fi
    
    # Dacă suntem în bloc de cod, adunăm conținutul
    if [ $in_code_block -eq 1 ]; then
        # Detectare sfârșit bloc cod în HTML
        if [[ "$line" == *"</div>"* ]] || [[ "$line" == *"</pre>"* ]]; then
            in_code_block=0
            if [ -n "$current_filename" ] && [ -n "$current_content" ]; then
                # Determină categoria
                category=$(get_category "$current_filename")
                file_type=$(detect_file_type "$current_content" "$current_filename")
                
                # Salvează fișierul
                echo "$current_content" > "$OUTPUT_DIR/$category/$current_filename"
                
                # Actualizează contoare
                total_files=$((total_files + 1))
                category_count[$category]=$((category_count[$category] + 1))
                
                echo -e "  ✅ Salvat: ${YELLOW}$current_filename${NC} → ${GREEN}$category/${NC} [$file_type]"
                
                current_filename=""
                current_content=""
            fi
        # Detectare sfârșit bloc cod în Markdown
        elif [[ "$line" =~ ^\`\`\`$ ]] && [ $in_code_block -eq 1 ]; then
            in_code_block=0
            if [ -n "$current_filename" ] && [ -n "$current_content" ]; then
                # Determină categoria
                category=$(get_category "$current_filename")
                file_type=$(detect_file_type "$current_content" "$current_filename")
                
                # Salvează fișierul
                echo "$current_content" > "$OUTPUT_DIR/$category/$current_filename"
                
                # Actualizează contoare
                total_files=$((total_files + 1))
                category_count[$category]=$((category_count[$category] + 1))
                
                echo -e "  ✅ Salvat: ${YELLOW}$current_filename${NC} → ${GREEN}$category/${NC} [$file_type]"
                
                current_filename=""
                current_content=""
            fi
        else
            # Adună linia la conținut
            if [ -n "$current_content" ]; then
                current_content="$current_content"$'\n'"$line"
            else
                current_content="$line"
            fi
        fi
    fi
    
    # Încercare de a găsi nume de fișier în linii normale
    if [[ "$line" =~ 📄\ ([^\ ]+) ]] && [ $in_code_block -eq 0 ]; then
        potential_filename="${BASH_REMATCH[1]}"
        # Verifică dacă pare un nume valid de fișier
        if [[ "$potential_filename" =~ \.(asm|adb|ads|zig|c|h|cpp|ts|tsx|js|sh|yaml|json|md|txt|erl)$ ]]; then
            current_filename=$(clean_filename "$potential_filename")
        fi
    fi
done < "$INPUT_FILE"

# Creează un fișier README în fiecare director
echo -e "${BLUE}📝 Creez fișiere README pentru fiecare categorie...${NC}"

for dir in "${!categories[@]}"; do
    if [ -d "$OUTPUT_DIR/$dir" ] && [ "$(ls -A "$OUTPUT_DIR/$dir")" ]; then
        cat > "$OUTPUT_DIR/$dir/README.md" << EOF
# 📁 Categoria: ${categories[$dir]}

Acest director conține fișiere pentru categoria **${categories[$dir]}**.

## Fișiere incluse ($(ls "$OUTPUT_DIR/$dir" | wc -l))

$(ls -1 "$OUTPUT_DIR/$dir" | sed 's/^/- /')

## Descriere
${categories[$dir]} - parte a sistemului OmniBus v1.2.

*Generat automat la $(date)*
EOF
    fi
done

# Creează un fișier SUMAR general
cat > "$OUTPUT_DIR/SUMMARY.md" << EOF
# 📊 OMNIBUS - SUMAR FIȘIERE EXTRASE

**Data extragerii:** $(date)
**Fișier sursă:** $INPUT_FILE
**Total fișiere extrase:** $total_files

## Distribuție pe categorii

| Categorie | Număr fișiere | Descriere |
|-----------|---------------|-----------|
EOF

for dir in "${!categories[@]}"; do
    count=${category_count[$dir]:-0}
    if [ $count -gt 0 ]; then
        echo "| **${dir}** | $count | ${categories[$dir]} |" >> "$OUTPUT_DIR/SUMMARY.md"
    fi
done

cat >> "$OUTPUT_DIR/SUMMARY.md" << EOF

## Structura directoarelor

\`\`\`
omnibus_extracted/
EOF

for dir in "${!categories[@]}"; do
    count=${category_count[$dir]:-0}
    if [ $count -gt 0 ]; then
        echo "├── $dir/ ($(printf "%3d" $count) fișiere)" >> "$OUTPUT_DIR/SUMMARY.md"
    fi
done

cat >> "$OUTPUT_DIR/SUMMARY.md" << EOF
└── SUMMARY.md (acest fișier)
\`\`\`

## Cum să folosești aceste fișiere

1. **Bootloader** - pentru compilare: \`nasm -f bin boot/...\`
2. **Kernel** - pentru compilare Ada: \`gnatmake kernel/...\`
3. **Engines** - pentru compilare Zig: \`zig build-obj engines/...\`
4. **Drivere** - pentru compilare C: \`gcc -c drivers/...\`
5. **Dashboard** - pentru instalare: \`cd dashboard && npm install\`

Pentru instrucțiuni complete, consultați documentația din directorul \`docs/\`.

---

*Generat automat cu script-ul extract_omnibus_files.sh*
EOF

# Creează un script de compilare rapidă
cat > "$OUTPUT_DIR/quick_build.sh" << 'EOF'
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
EOF

chmod +x "$OUTPUT_DIR/quick_build.sh"

# Creează un script pentru testare rapidă
cat > "$OUTPUT_DIR/quick_test.sh" << 'EOF'
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
EOF

chmod +x "$OUTPUT_DIR/quick_test.sh"

# Rezumat final
echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                         REZUMAT                              ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo -e "${GREEN}📁 Director principal: $OUTPUT_DIR${NC}"
echo -e "${GREEN}📊 Total fișiere extrase: $total_files${NC}"
echo ""

echo -e "${YELLOW}Distribuție pe categorii:${NC}"
for dir in "${!categories[@]}"; do
    count=${category_count[$dir]:-0}
    if [ $count -gt 0 ]; then
        printf "  %-15s: %3d fișiere → %s\n" "$dir" "$count" "${categories[$dir]}"
    fi
done

echo ""
echo -e "${GREEN}✅ Fișiere importante create:${NC}"
echo "   📄 $OUTPUT_DIR/SUMMARY.md - Sumar general"
echo "   📄 $OUTPUT_DIR/quick_build.sh - Script compilare rapidă"
echo "   📄 $OUTPUT_DIR/quick_test.sh - Script testare rapidă"
for dir in "${!categories[@]}"; do
    if [ -f "$OUTPUT_DIR/$dir/README.md" ]; then
        echo "   📄 $OUTPUT_DIR/$dir/README.md"
    fi
done

echo ""
echo -e "${BLUE}📂 Structura directoarelor:${NC}"
tree -L 2 "$OUTPUT_DIR" 2>/dev/null || find "$OUTPUT_DIR" -type d | sed -e "s/[^-][^\/]*\//  |/g" -e "s/|\([^ ]\)/|-\1/"

echo ""
echo -e "${GREEN}🎉 Extracție completă! Pentru a folosi:${NC}"
echo "   cd \"$OUTPUT_DIR\""
echo "   ./quick_build.sh   # pentru compilare rapidă"
echo "   ./quick_test.sh    # pentru testare rapidă"
echo ""
echo -e "${YELLOW}📌 NOTĂ: Verifică fișierul SUMMARY.md pentru detalii complete.${NC}"