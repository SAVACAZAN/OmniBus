; ============================================================================
; OmniBus Bootloader - Stage 1
; Entry point: 0x7C00 (BIOS loads us here)
; Target: Load Stage 2 at 0x7E00 and jump to protected mode
; ============================================================================

[BITS 16]                           ; 16-bit real mode
[ORG 0x7C00]                        ; BIOS loads boot sector at 0x7C00

; ============================================================================
; BOOT SECTOR HEADER (512 bytes total)
; ============================================================================

boot_start:
    ; Disable interrupts - we're taking over
    cli

    ; Clear data segment registers
    xor eax, eax
    mov ds, ax
    mov es, ax
    mov ss, ax

    ; Setup stack (grows downward from 0x7C00)
    mov sp, 0x7C00

    ; Clear screen (CGA mode 0x03 = 80x25 text)
    mov al, 0x03
    mov ah, 0x00
    int 0x10

    ; Enable A20 line (required for >1MB addressing)
    ; Using fast method: OUT 0x92
    in al, 0x92
    or al, 0x02
    out 0x92, al

    ; Load Stage 2 bootloader + kernel from disk
    ; BIOS has already loaded sector 0 (boot sector) into 0x7C00
    ; Load sectors 1-9 (9 sectors = ~4.5KB for Stage 2 + space for kernel stub prep)
    ; Sector layout:
    ;   0       = Boot sector (0x7C00, 512 bytes)
    ;   1-8     = Stage 2 (0x7E00, 4KB)
    ;   2048+   = Kernel (0x100000, will be loaded when paging enabled)

    mov ah, 0x02                    ; int 0x13 AH=2: Read Sectors
    mov al, 8                       ; Read 8 sectors (4KB for Stage 2)
    mov ch, 0                       ; Cylinder 0
    mov cl, 2                       ; Sector 2 (sectors 2-9; sector 1 is this boot sector)
    mov dh, 0                       ; Head 0
    mov dl, 0x80                    ; Drive 0 (first HDD)
    mov bx, 0x7E00                  ; Load into 0x7E00
    int 0x13

    ; Check for read error
    jc disk_error

    ; Print "OmniBus Booting..." to screen
    mov si, boot_message
    call print_string

    ; Jump to Stage 2 at 0x7E00
    ; Set CS:IP = 0x0000:0x7E00 (absolute address 0x7E00)
    jmp 0x0000:0x7E00

    ; ========================================================================
    ; HELPER FUNCTIONS
    ; ========================================================================

disk_error:
    mov si, error_message
    call print_string

    ; Infinite loop
    jmp $

; --------
; print_string - Print null-terminated string at DS:SI
; --------
print_string:
    mov ah, 0x0E                    ; int 0x10 AH=0x0E: Write character in TTY mode

.loop:
    lodsb                           ; Load byte at [DS:SI] into AL, increment SI
    cmp al, 0                       ; Check for null terminator
    je .done
    int 0x10                        ; BIOS: print character
    jmp .loop

.done:
    ret

    ; ========================================================================
    ; DATA SECTION
    ; ========================================================================

boot_message:
    db "OmniBus: Boot Stage 1 loaded. Jumping to Stage 2...", 0x0D, 0x0A, 0

error_message:
    db "ERROR: Failed to load Stage 2 from disk!", 0x0D, 0x0A, 0

    ; ========================================================================
    ; BOOT SECTOR SIGNATURE (required by BIOS)
    ; Must be exactly 512 bytes. Pad with zeros if needed.
    ; ========================================================================

    ; Pad to 510 bytes, then add magic signature
    times (510 - ($ - $$)) db 0
    dw 0xAA55                       ; Boot signature (BIOS checks for this)

; ============================================================================
; END OF STAGE 1 BOOT SECTOR (exactly 512 bytes)
; ============================================================================
