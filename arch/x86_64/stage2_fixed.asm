; ============================================================================
; OmniBus Bootloader - Stage 2 (Fixed Protected Mode Entry)
; Entry point: 0x7E00 (loaded by Stage 1)
; Fixed: Use register-indirect addressing to avoid segment base doubling
; ============================================================================

[BITS 16]
[ORG 0x7E00]

entry:
    ; 1. Ensure segments are synchronized
    cli
    cld
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00                ; Stack safely below Stage 2

    ; ========================================================================
    ; LOAD KERNEL FROM DISK (Using LBA Extended Read with error checking)
    ; Load from sector 2048 to temporary buffer at 0x8000
    ; ========================================================================

    mov si, kernel_dap              ; SI points to Disk Address Packet
    mov ah, 0x42                    ; int 0x13 AH=0x42: Extended Read (LBA)
    mov dl, 0x80                    ; Drive 0 (first HDD)
    int 0x13

    ; Check for read failure (Carry Flag set)
    jc kernel_load_error

    ; Verify we got valid kernel data by checking magic number
    ; Expected: 0xfa1e0ff3 (ENDBR32 instruction at start of kernel)
    mov eax, [0x8000]
    cmp eax, 0xfa1e0ff3
    jne kernel_not_found

    ; 2. Calculate linear address of GDT descriptor using register
    ; This avoids NASM displacement assumptions
    mov bx, gdt_descriptor
    lgdt [bx]

    ; 3. Load IDT descriptor similarly
    mov bx, idt_descriptor
    lidt [bx]

    ; 4. Enter Protected Mode
    mov eax, cr0
    or eax, 1                      ; Set PE bit
    mov cr0, eax

    ; 5. Far jump to clear prefetch queue and reload CS
    jmp 0x08:pm_entry

[BITS 32]

pm_entry:
    ; 6. Update data segments for protected mode
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

    ; 7. Setup stack in protected mode
    mov esp, 0x7E000

    ; 8. Visual confirmation: Write "PM OK" to VGA buffer
    ; This proves we successfully entered protected mode
    mov dword [0xB8000], 0x0F4F0F50   ; "PO" in white
    mov dword [0xB8004], 0x0F4B0F4D   ; "MK" in white

    ; DEBUG: Write 'C' to VGA at offset 8 to show we're copying
    mov byte [0xB8008], 'C'

    ; ========================================================================
    ; 9. Copy kernel from temporary buffer 0x8000 to final location 0x100000
    ; In protected mode, we can now access memory >1MB directly
    ; ========================================================================

    mov esi, 0x8000                 ; Source: kernel at 0x8000
    mov edi, 0x100000               ; Destination: kernel location
    mov ecx, 4096                   ; Copy 4096 dwords = 16KB (32 sectors × 512 bytes)
    cld                             ; Clear direction flag (forward copy)
    rep movsd                       ; Copy kernel to proper location

    ; DEBUG: Write 'D' to VGA at offset 10 to show copy complete
    mov byte [0xB800A], 'D'

    ; DEBUG: Write 'J' to VGA at offset 12 to show we're about to jump
    mov byte [0xB800C], 'J'

    ; ========================================================================
    ; 10. Jump to Ada Kernel at 0x100030 (startup_begin)
    ; Using push/retf for guaranteed 32-bit far jump
    ; ========================================================================

    ; Force 32-bit absolute jump to kernel entry
    ; Push CS selector (0x08 = code segment)
    ; Push EIP (0x100030 = kernel entry point)
    ; retf = "return far" acts as a 32-bit jump with CS reload
    push dword 0x08
    push dword 0x100030
    retf

    ; If we get here, something went wrong
    ; (Infinite loop with 'F' for failure)
    mov byte [0xB800E], 'F'
    jmp $

; ========================================================================
; KERNEL LOAD ERROR HANDLERS (16-bit code)
; ========================================================================

kernel_load_error:
    ; Disk read failed - print "E" and halt
    mov ah, 0x0E                    ; BIOS print character function
    mov al, 'E'                     ; Error = 'E'
    xor bh, bh                      ; Page 0
    mov bl, 0x04                    ; Red text
    int 0x10
    hlt
    jmp $

kernel_not_found:
    ; Kernel data is corrupted/missing - print "M" and halt
    mov ah, 0x0E
    mov al, 'M'                     ; Missing = 'M'
    xor bh, bh
    mov bl, 0x0E                    ; Yellow text
    int 0x10
    hlt
    jmp $

; ========================================================================
; DATA SECTION - Disk Address Packet (DAP) for LBA read
; Properly aligned to avoid BIOS errors
; ========================================================================

align 4                             ; 4-byte alignment for DAP

kernel_dap:
    db 0x10                         ; DAP size (16 bytes, required)
    db 0x00                         ; Reserved (must be 0)
    dw 16                           ; Number of sectors to read (16 sectors = 8KB kernel)
    dw 0x8000                       ; Offset of buffer in segment
    dw 0x0000                       ; Segment of buffer (0x0000:0x8000 = absolute 0x8000)
    dq 2048                         ; LBA sector (sector 2048 = kernel start)

; ========================================================================
; DATA SECTION - GDT Definition
; ========================================================================

align 16

gdt_start:
    dq 0x0                          ; Null descriptor (required)

gdt_code:
    ; Code segment (selector 0x08)
    ; Base: 0x00000000, Limit: 0xFFFFF, Type: Code, Present, Ring 0, 32-bit
    dw 0xFFFF                       ; Limit (bits 0-15)
    dw 0x0000                       ; Base (bits 0-15)
    db 0x00                         ; Base (bits 16-23)
    db 0x9A                         ; P=1, DPL=0, S=1, Type=1010 (code)
    db 0xCF                         ; G=1 (granular), DB=1 (32-bit), Limit(19:16)=1111
    db 0x00                         ; Base (bits 24-31)

gdt_data:
    ; Data segment (selector 0x10)
    ; Base: 0x00000000, Limit: 0xFFFFF, Type: Data, Present, Ring 0, 32-bit
    dw 0xFFFF
    dw 0x0000
    db 0x00
    db 0x92                         ; P=1, DPL=0, S=1, Type=0010 (data)
    db 0xCF                         ; G=1 (granular), DB=1 (32-bit), Limit(19:16)=1111
    db 0x00

gdt_end:

; GDT Descriptor (for LGDT instruction)
gdt_descriptor:
    dw gdt_end - gdt_start - 1      ; Limit (size - 1)
    dd gdt_start                    ; Base address (absolute linear address)

; ========================================================================
; IDT Definition (minimal, filled with zeros)
; ========================================================================

idt_start:
    ; 256 IDT entries × 8 bytes = 2048 bytes (all zeros for now)
    times 256 * 8 db 0

idt_descriptor:
    dw 256 * 8 - 1                  ; Limit (size - 1)
    dd idt_start                    ; Base address

; ========================================================================
; Padding to 4KB (required by Stage 1 which reads 8 sectors)
; ========================================================================

times (0x1000 - ($ - $$)) db 0
