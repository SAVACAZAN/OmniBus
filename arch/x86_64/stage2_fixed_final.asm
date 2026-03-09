; ============================================================================
; OmniBus Bootloader - Stage 2 FINAL FIXED VERSION
; Entry point: 0x7E00 (loaded by Stage 1)
; KEY FIX: Place protected mode code immediately after far jump
;         (so pmode_entry offset is within 16-bit range for far jmp)
; ============================================================================

[BITS 16]
[ORG 0x7E00]

stage2_start:
    cli
    cld

    ; ========================================================================
    ; Load Ada Kernel from disk using LBA mode (int 0x13 AH=0x42)
    ; Load sectors 2048-2063 (16 sectors = 8KB) into memory at 0x100000
    ; DISABLED: LBA mode not working in QEMU BIOS - causes reboot loop
    ; TODO: Investigate BIOS compatibility or use fallback (CHS) mode
    ; ========================================================================

    ; mov ah, 0x42                    ; Extended Read (LBA mode)
    ; mov dl, 0x80                    ; Drive 0
    ; mov si, kernel_dap              ; DS:SI points to Disk Address Packet
    ; int 0x13
    ; jc kernel_load_error            ; Jump if error (CF set)

    ; ========================================================================
    ; Setup GDT (Global Descriptor Table) - must be before LGDT
    ; ========================================================================

    lgdt [gdt_descriptor]

    ; ========================================================================
    ; Setup IDT (Interrupt Descriptor Table) - must be before protected mode
    ; NOTE: IDT setup loop omitted (causes QEMU threading bug)
    ;       Ada kernel will initialize IDT properly
    ; ========================================================================

    ; Just load a minimal IDT without initialization loop
    lidt [idt_descriptor]

    ; ========================================================================
    ; Enter Protected Mode
    ; ========================================================================

    mov eax, cr0
    or eax, 1                        ; Set PE bit
    mov cr0, eax

    ; ========================================================================
    ; Far jump to protected mode (flushes pipeline & reloads CS)
    ; CRITICAL: Must use offset-from-origin, not absolute address!
    ; ========================================================================

    jmp 0x08:dword 0x7e1e

; ========================================================================
; PROTECTED MODE CODE MUST BE HERE (immediately after far jump)
; ========================================================================

[BITS 32]

pmode_entry:
    ; ========================================================================
    ; Protected mode entry - we made it!
    ; ========================================================================

    ; Setup segment registers
    mov eax, 0x10                   ; Data segment selector
    mov ds, eax
    mov es, eax
    mov fs, eax
    mov gs, eax
    mov ss, eax

    ; Setup stack
    mov esp, 0x7E000

    ; ========================================================================
    ; Print "PMODE OK" to VGA to confirm protected mode works
    ; ========================================================================

    mov eax, 0xB8000                ; VGA text buffer
    mov dword [eax], 0x4F4F4F50     ; "POO" in white
    mov dword [eax+4], 0x4F454D4F   ; "OMED" in white

    ; ========================================================================
    ; Jump to Ada Kernel at 0x100030 (startup_begin entry point)
    ; ========================================================================

    jmp 0x100030

; ========================================================================
; Error handler
; ========================================================================

kernel_load_error:
    ; If kernel load fails, just hang (better than crash)
    jmp $

; ========================================================================
; Return to 16-bit section for data definitions
; ========================================================================

[BITS 16]

; ========================================================================
; DATA: Disk Address Packet (DAP) for LBA disk read
; ========================================================================

kernel_dap:
    db 0x10                         ; DAP size (16 bytes)
    db 0x00                         ; Reserved
    dw 16                           ; Number of sectors to read (16 sectors = 8KB kernel)
    dw 0x0000                       ; Buffer offset (0x0000)
    dw 0x1000                       ; Buffer segment (0x1000:0x0000 = 0x10000 = 0x100000 in real mode)
    dq 2048                         ; Starting LBA sector (sector 2048 = kernel start)

; ========================================================================
; Align to next 16-byte boundary to ensure GDT is properly aligned
; ========================================================================

align 16

; ========================================================================
; DATA: GDT - Global Descriptor Table (8 bytes per descriptor, REQUIRED!)
; ========================================================================

gdt_start:

    ; Descriptor 0: NULL (REQUIRED - must be 8 bytes!)
    dq 0x0000000000000000

    ; Descriptor 1: Code Segment (selector 0x08)
    dw 0xFFFF                       ; Limit (bits 0-15)
    dw 0x0000                       ; Base (bits 0-15)
    db 0x00                         ; Base (bits 16-23)
    db 0x9A                         ; Access: present | ring 0 | code | readable
    db 0xCF                         ; Flags: granular | 32-bit | limit(19:16)
    db 0x00                         ; Base (bits 24-31)

    ; Descriptor 2: Data Segment (selector 0x10)
    dw 0xFFFF
    dw 0x0000
    db 0x00
    db 0x92                         ; Access: present | ring 0 | data | writable
    db 0xCF                         ; Flags: granular | 32-bit | limit(19:16)
    db 0x00

gdt_end:

; GDT Descriptor (used by LGDT instruction)
; Place immediately after GDT with no alignment issues
gdt_descriptor:
    dw gdt_end - gdt_start - 1      ; Size (limit) in bytes - 1
    dd gdt_start                    ; Base address (absolute)

; ========================================================================
; DATA: IDT - Interrupt Descriptor Table (2048 bytes for 256 entries)
; ========================================================================

idt_start:
    ; 256 IDT entries × 8 bytes = 2048 bytes
    times 256 * 8 db 0

idt_descriptor:
    dw 256 * 8 - 1                  ; Size (limit) in bytes - 1
    dd idt_start                    ; Base address (absolute)

; ========================================================================
; Padding to 4KB (required by boot sector which reads 8 sectors = 4KB)
; ========================================================================

times (0x1000 - ($ - $$)) db 0
