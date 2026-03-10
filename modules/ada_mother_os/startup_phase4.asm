; ============================================================================
; OmniBus Phase 4: 32-bit Protected Mode → 64-bit Long Mode
; startup_phase4.asm — verified flat binary, ORG 0x100000
; ============================================================================
; CORRECTIONS vs attempt 1:
;   1. LGDT moved BEFORE CR0.PG (avoids accessing GDT through new page tables)
;   2. Use standard 64-bit GDT: 0x00AF9A000000FFFF (G=1, Limit=FFFFF)
;   3. CR0 or eax, 0x80000000 only (PE already set, not 0x80000001)
;   4. UART 'P' probe immediately after mov cr0,eax to catch exact fault point
;   5. Page tables at 0x201000/0x202000/0x203000 (away from old 0x200000 dir)
; ============================================================================

[BITS 32]
[ORG 0x100000]

; --- Header: ENDBR32 magic + 44 NOP padding ---
db 0xF3, 0x0F, 0x1E, 0xFA
times (0x30 - 4) db 0x90

; ============================================================================
; STARTUP_BEGIN at 0x100030 (stage2 push/retf target)
; ============================================================================
startup_begin:

    ; UART 'K' = Kernel reached
    mov dx, 0x3F8
    mov al, 'K'
    out dx, al

    ; VGA 'S' yellow
    mov word [0xB8000], 0x0E53

    ; ========================================================================
    ; STEP 1: Enable PAE (must be before EFER.LME and CR0.PG)
    ; ========================================================================
    mov eax, cr4
    or  eax, 0x20               ; CR4.PAE = bit 5
    mov cr4, eax

    ; UART 'T'
    mov dx, 0x3F8
    mov al, 'T'
    out dx, al
    mov word [0xB8002], 0x0E54

    ; ========================================================================
    ; STEP 2: Build 4-level page tables
    ; PML4 @ 0x201000, PDPT @ 0x202000, PD @ 0x203000
    ; (Use 0x201xxx to avoid overwriting old 32-bit dir at 0x200000)
    ; Mapping: identity 0x000000-0x1FFFFF (2MB, covers kernel + VGA)
    ; ========================================================================

    ; Clear PML4 (4KB = 1024 dwords)
    mov edi, 0x201000
    xor eax, eax
    mov ecx, 1024
    rep stosd

    ; Clear PDPT (4KB)
    mov edi, 0x202000
    xor eax, eax
    mov ecx, 1024
    rep stosd

    ; Clear PD (4KB)
    mov edi, 0x203000
    xor eax, eax
    mov ecx, 1024
    rep stosd

    ; PML4[0] → PDPT @ 0x202000 (present + writable)
    mov dword [0x201000], 0x202003
    mov dword [0x201004], 0

    ; PDPT[0] → PD @ 0x203000 (present + writable)
    mov dword [0x202000], 0x203003
    mov dword [0x202004], 0

    ; PD[0] → 2MB page @ phys 0x000000 (PS=1 bit7, RW=1, P=1)
    ; Covers virtual 0x000000-0x1FFFFF → physical 0x000000-0x1FFFFF
    ; Includes: kernel code (0x100000), VGA (0xB8000), page tables
    mov dword [0x203000], 0x000083  ; bits: PS|RW|P
    mov dword [0x203004], 0

    ; PD[1] → 2MB page @ phys 0x200000 (covers 0x200000-0x3FFFFF)
    ; Includes: old page dir (0x200000), new page tables (0x201000-0x203FFF)
    mov dword [0x203008], 0x200083  ; phys 0x200000, PS|RW|P
    mov dword [0x20300C], 0

    ; UART 'C'
    mov dx, 0x3F8
    mov al, 'C'
    out dx, al
    mov word [0xB8004], 0x0E43

    ; ========================================================================
    ; STEP 3: Load CR3 with PML4 address
    ; ========================================================================
    mov eax, 0x201000
    mov cr3, eax

    ; ========================================================================
    ; STEP 4: Load 64-bit GDT BEFORE enabling paging
    ; (avoids needing to read GDT through new page tables)
    ; ========================================================================
    lgdt [gdt64_ptr]

    ; ========================================================================
    ; STEP 5: Set EFER.LME via WRMSR (MSR 0xC0000080)
    ; Must have: CR4.PAE=1, CR0.PG=0 (currently no paging)
    ; ========================================================================
    mov ecx, 0xC0000080
    rdmsr
    or  eax, 0x100              ; EFER.LME = bit 8
    wrmsr

    ; UART 'R' = about to enable paging → long mode
    mov dx, 0x3F8
    mov al, 'R'
    out dx, al
    mov word [0xB8006], 0x0E52

    ; ========================================================================
    ; STEP 6: Enable paging (CR0.PG=1)
    ; PE is already 1 (set by stage2). Only set PG.
    ; With PAE=1 and LME=1, setting PG activates long mode (LMA=1).
    ; CPU transitions to IA-32e compatibility mode (CS.L=0 until far jump).
    ; ========================================================================
    mov eax, cr0
    or  eax, 0x80000000         ; CR0.PG only (bit 31); PE already set
    mov cr0, eax

    ; UART probe: if we get here, CR0.PG succeeded
    mov dx, 0x3F8
    mov al, 'P'
    out dx, al

    ; VGA 'P' GREEN = Paging + long mode active
    mov word [0xB8008], 0x0A50

    ; ========================================================================
    ; STEP 7: Far jump to 64-bit CS → enters 64-bit long mode
    ; Selector 0x08 = gdt64_code (L=1, 64-bit descriptor)
    ; NASM [BITS 32] encodes this as: EA [4-byte IP] [2-byte CS]
    ; ========================================================================
    jmp 0x08:long_mode_entry

; ============================================================================
; GDT64 — 64-bit Global Descriptor Table
; Placed in [BITS 32] section — simple data, no execution needed here
; ============================================================================
align 16
gdt64_start:
    dq 0x0000000000000000      ; [0x00] Null descriptor
gdt64_code:
    ; [0x08] 64-bit kernel code: Base=0, Limit=0xFFFFF, G=1, L=1, D=0, P=1
    dq 0x00AF9A000000FFFF      ; Standard 64-bit code (L=1, G=1)
gdt64_data:
    ; [0x10] Kernel data: Base=0, Limit=0xFFFFF, G=1, DB=1, P=1
    dq 0x00CF92000000FFFF      ; Standard 32/64-bit data
gdt64_end:

gdt64_ptr:
    dw gdt64_end - gdt64_start - 1    ; GDT limit (size - 1)
    dd gdt64_start                     ; GDT base (32-bit linear address)

; ============================================================================
; LONG MODE ENTRY [BITS 64]
; CPU is in 64-bit mode after the far jump to gdt64_code (L=1)
; ============================================================================
align 32
[BITS 64]
long_mode_entry:

    ; Reload data segments
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

    ; Set 64-bit stack
    mov rsp, 0x7E000

    ; VGA 'M' GREEN = long mode confirmed alive
    mov word [0xB800A], 0x0A4D

    ; UART "LONG_MODE_OK\r\n"
    mov dx, 0x3F8
    mov al, 'L'
    out dx, al
    mov al, 'O'
    out dx, al
    mov al, 'N'
    out dx, al
    mov al, 'G'
    out dx, al
    mov al, '_'
    out dx, al
    mov al, 'M'
    out dx, al
    mov al, 'O'
    out dx, al
    mov al, 'D'
    out dx, al
    mov al, 'E'
    out dx, al
    mov al, '_'
    out dx, al
    mov al, 'O'
    out dx, al
    mov al, 'K'
    out dx, al
    mov al, 0x0D
    out dx, al
    mov al, 0x0A
    out dx, al

    ; VGA 'I' GREEN
    mov word [0xB800C], 0x0A49

    ; Auth gate
    mov byte [0x100050], 0x70

    ; === ADA INIT STUB (Phase 4A) ===
    call ada64_stub_initialize

    ; VGA 'L' GREEN
    mov word [0xB800E], 0x0A4C

    ; === ADA EVENT LOOP STUB (Phase 4A) ===
    call ada64_stub_event_loop

    cli
    hlt
    jmp $ - 2

; ============================================================================
; 64-bit Ada Initialization Stub
; ============================================================================
ada64_stub_initialize:
    push rax
    push rdx
    mov dx, 0x3F8
    mov al, 'A'
    out dx, al
    mov al, 'D'
    out dx, al
    mov al, 'A'
    out dx, al
    mov al, '6'
    out dx, al
    mov al, '4'
    out dx, al
    mov al, '_'
    out dx, al
    mov al, 'I'
    out dx, al
    mov al, 'N'
    out dx, al
    mov al, 'I'
    out dx, al
    mov al, 'T'
    out dx, al
    mov al, 0x0D
    out dx, al
    mov al, 0x0A
    out dx, al
    pop rdx
    pop rax
    ret

; ============================================================================
; 64-bit Ada Event Loop Stub
; ============================================================================
ada64_stub_event_loop:
    push rax
    push rdx
    mov dx, 0x3F8
    mov al, 'M'
    out dx, al
    mov al, 'O'
    out dx, al
    mov al, 'T'
    out dx, al
    mov al, 'H'
    out dx, al
    mov al, 'E'
    out dx, al
    mov al, 'R'
    out dx, al
    mov al, '_'
    out dx, al
    mov al, 'O'
    out dx, al
    mov al, 'S'
    out dx, al
    mov al, '_'
    out dx, al
    mov al, '6'
    out dx, al
    mov al, '4'
    out dx, al
    mov al, '_'
    out dx, al
    mov al, 'O'
    out dx, al
    mov al, 'K'
    out dx, al
    mov al, 0x0D
    out dx, al
    mov al, 0x0A
    out dx, al
    pop rdx
    pop rax
    cli
.halt:
    hlt
    jmp .halt

; --- Pad to 8KB ---
times (0x2000 - ($ - $$)) db 0
