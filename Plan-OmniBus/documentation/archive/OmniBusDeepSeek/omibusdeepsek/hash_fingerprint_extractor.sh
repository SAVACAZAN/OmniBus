#!/bin/bash
# hash_fingerprint_extractor.sh

extract_fingerprint() {
    local hash=$1
    local method=$2
    
    case $method in
        "prefix")
            # Primele 8 caractere
            echo "${hash:0:8}"
            ;;
        "suffix")
            # Ultimele 8 caractere
            echo "${hash: -8}"
            ;;
        "middle")
            # Mijloc (caracterele 16-24)
            echo "${hash:16:8}"
            ;;
        "crc32")
            # CRC32
            echo -n "$hash" | gzip -c | tail -c8 | xxd -p
            ;;
        "pattern")
            # Pattern recognizer (first and last 4)
            echo "${hash:0:4}${hash: -4}"
            ;;
    esac
}

echo "👆 Extragere amprente hash"

for agent in chatgpt claude deepseek gemini; do
    hash=$(grep "H1_1" "agent_hashes/$agent/identity.cfg" | cut -d= -f2)
    
    echo -e "\n📌 $agent:"
    echo "  Hash complet: $hash"
    
    for method in prefix suffix middle crc32 pattern; do
        fp=$(extract_fingerprint "$hash" "$method")
        echo "    $method: $fp"
    done
done