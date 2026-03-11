# 📊 OMNIBUS - SUMAR FIȘIERE EXTRASE

**Data extragerii:** Mon Mar  9 19:34:19 EET 2026
**Fișier sursă:** deepseek_html_20260308_063444.html
**Total fișiere extrase:** 0

## Distribuție pe categorii

| Categorie | Număr fișiere | Descriere |
|-----------|---------------|-----------|

## Structura directoarelor

```
omnibus_extracted/
└── SUMMARY.md (acest fișier)
```

## Cum să folosești aceste fișiere

1. **Bootloader** - pentru compilare: `nasm -f bin boot/...`
2. **Kernel** - pentru compilare Ada: `gnatmake kernel/...`
3. **Engines** - pentru compilare Zig: `zig build-obj engines/...`
4. **Drivere** - pentru compilare C: `gcc -c drivers/...`
5. **Dashboard** - pentru instalare: `cd dashboard && npm install`

Pentru instrucțiuni complete, consultați documentația din directorul `docs/`.

---

*Generat automat cu script-ul extract_omnibus_files.sh*
