; ============================================================================
; OmniBus Kernel Stub (Ada Mother OS Entry Point)
; Located at: 0x100000 (1MB mark)
; Purpose: Stub that validates Stage 2 worked, prepares for Ada kernel
; ============================================================================

[BITS 64]
[ORG 0x100000]

kernel_stub:
    ; We're in 64-bit long mode!

    ; Setup a basic IDT (Interrupt Descriptor Table) for now
    ; IDT at 0x100100

    ; Print to VGA: "Kernel@1MB"
    mov rax, 0x000000000000004B    ; 'K'
    mov [0xB8028], ax

    mov rax, 0x0000000000000065    ; 'e'
    mov [0xB802A], ax

    mov rax, 0x0000000000000072    ; 'r'
    mov [0xB802C], ax

    mov rax, 0x000000000000006E    ; 'n'
    mov [0xB802E], ax

    ; Setup UART for debugging at 0x3F8 (COM1)
    mov dx, 0x3F8 + 1              ; Line Control Register
    mov al, 0x80                   ; Divisor Latch Access Bit
    out dx, al

    ; Set baud rate divisor to 1 (115200 baud)
    mov dx, 0x3F8                  ; DLL
    mov al, 0x01
    out dx, al

    mov dx, 0x3F8 + 1              ; DLM
    mov al, 0x00
    out dx, al

    ; LCR: 8 bits, no parity, 1 stop bit
    mov dx, 0x3F8 + 3
    mov al, 0x03
    out dx, al

    ; Write "O" to UART – kernel activ
    mov al, 'O'
    mov dx, 0x3F8
    out dx, al

    ; =========================================================================
    ; Încărcăm OmniBus Blockchain OS din disc via ATA PIO
    ; Sector LBA 7888 → 0x5D0000 (120 sectoare = 60KB, binary e ~40KB)
    ; =========================================================================

    ; Drive/Head: LBA mode, drive 0
    mov dx, 0x1F6
    mov al, 0xE0
    out dx, al

    ; Sector count: 120
    mov dx, 0x1F2
    mov al, 120
    out dx, al

    ; LBA = 7888 = 0x001ED0
    mov dx, 0x1F3
    mov al, 0xD0        ; bits  0-7
    out dx, al
    mov dx, 0x1F4
    mov al, 0x1E        ; bits  8-15
    out dx, al
    mov dx, 0x1F5
    mov al, 0x00        ; bits 16-23
    out dx, al

    ; Comandă: READ SECTORS
    mov dx, 0x1F7
    mov al, 0x20
    out dx, al

    mov rdi, 0x5D0000   ; Destinaţie în RAM
    mov rcx, 120        ; Sectoare rămase

.ata_sector:
    ; Aşteptăm BSY=0 şi DRQ=1
.ata_busy:
    mov dx, 0x1F7
    in al, dx
    test al, 0x80
    jnz .ata_busy
    test al, 0x08
    jz .ata_busy

    ; Citim 256 words (512 bytes) din portul de date 0x1F0
    push rcx
    mov rcx, 256
    mov dx, 0x1F0
.ata_words:
    in ax, dx
    mov [rdi], ax
    add rdi, 2
    loop .ata_words
    pop rcx
    loop .ata_sector

    ; "B" pe UART – Blockchain OS încărcat în RAM
    mov al, 'B'
    mov dx, 0x3F8
    out dx, al

    ; Salt la entry point: 0x5D0000 (_start din libc_stubs.asm)
    jmp 0x5D0000

    ; Padding
    times (0x1000 - ($ - $$)) db 0
