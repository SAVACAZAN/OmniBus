; ============================================================================
; PHASE 5D: DISK I/O DRIVER (LBA28 ATA PIO, 64-bit mode)
; ============================================================================
; Uses direct ATA I/O ports (in/out instructions) for reliable sector reads.
; LBA28 mode: supports up to 128GB — sufficient for omnibus.iso

[BITS 64]

; ATA I/O port map (primary channel)
; 0x1F0 = Data register (16-bit)
; 0x1F1 = Error / Features
; 0x1F2 = Sector count
; 0x1F3 = LBA bits 0-7
; 0x1F4 = LBA bits 8-15
; 0x1F5 = LBA bits 16-23
; 0x1F6 = Drive/Head: 1110_0000 | (LBA bits 24-27) for LBA28 master
; 0x1F7 = Command (write) / Status (read)
;         bit 7 = BSY, bit 3 = DRQ

global read_sectors_bios
global read_disk_sector

; ============================================================================
; READ_SECTORS_BIOS: Read sectors via ATA LBA28 PIO in 64-bit mode
; Parameters:
;   RAX = starting LBA sector (28-bit, fits up to ~128GB)
;   RDI = destination buffer
;   RCX = number of sectors to read (512 bytes each)
; Returns:
;   RAX = 0 on success, non-zero on error
; ============================================================================

read_sectors_bios:
    push rbx
    push rcx
    push rdx
    push rsi
    push r8
    push r9
    push r10

    ; Debug: print '1' to confirm read_sectors_bios was entered
    mov dx, 0x3F8
    mov al, '1'
    out dx, al

    ; Save parameters
    mov r8, rax                 ; r8  = LBA sector
    mov r9, rdi                 ; r9  = destination buffer
    mov r10, rcx                ; r10 = sector count
    xor rbx, rbx                ; success flag

.read_loop:
    test r10, r10
    jz .read_done               ; All sectors done → success

    ; -------------------------------------------------------------------------
    ; STEP 1: Wait for BSY=0 (ATA status register via I/O port)
    ; -------------------------------------------------------------------------
    mov rcx, 2000000            ; timeout
.wait_bsy:
    mov dx, 0x1F7
    in al, dx                   ; Read ATA status from I/O port (NOT memory)
    test al, 0x80               ; BSY bit
    jz .bsy_clear
    dec rcx
    jnz .wait_bsy
    mov rax, 1                  ; Error: drive busy timeout
    jmp .read_error

.bsy_clear:
    ; Debug: BSY cleared, print '2'
    mov dx, 0x3F8
    mov al, '2'
    out dx, al

    ; -------------------------------------------------------------------------
    ; STEP 2: Set up LBA28 registers
    ; -------------------------------------------------------------------------

    ; 0x1F6: Drive select + LBA bits 24-27
    ; Bit 6 = 1 (LBA mode), Bit 5 = 1 (obsolete, set for compat), Bit 4 = 0 (master)
    mov rax, r8
    shr rax, 24
    and al, 0x0F                ; bits 24-27
    or  al, 0xE0                ; 1110_xxxx = LBA mode, master
    mov dx, 0x1F6
    out dx, al

    ; 0x1F2: Sector count = 1 (we read one sector at a time)
    mov dx, 0x1F2
    mov al, 1
    out dx, al

    ; 0x1F3: LBA bits 0-7
    mov rax, r8
    mov dx, 0x1F3
    out dx, al

    ; 0x1F4: LBA bits 8-15
    mov rax, r8
    shr rax, 8
    mov dx, 0x1F4
    out dx, al

    ; 0x1F5: LBA bits 16-23
    mov rax, r8
    shr rax, 16
    mov dx, 0x1F5
    out dx, al

    ; 0x1F7: READ SECTORS command (0x20)
    mov dx, 0x1F7
    mov al, 0x20
    out dx, al

    ; -------------------------------------------------------------------------
    ; STEP 3: Wait for DRQ=1 (data ready) — poll ATA status I/O port
    ; -------------------------------------------------------------------------
    mov rcx, 2000000
.wait_drq:
    mov dx, 0x1F7
    in al, dx                   ; Read ATA status from I/O port
    test al, 0x80               ; BSY still set?
    jnz .wait_drq_again
    test al, 0x01               ; ERR bit
    jnz .ata_error
    test al, 0x08               ; DRQ = data ready
    jnz .drq_ready
.wait_drq_again:
    dec rcx
    jnz .wait_drq
    mov rax, 2                  ; Error: DRQ timeout
    jmp .read_error

.ata_error:
    mov rax, 3                  ; Error: ATA reported error
    jmp .read_error

.drq_ready:
    ; Debug: DRQ ready, print '3'
    mov dx, 0x3F8
    mov al, '3'
    out dx, al

    ; -------------------------------------------------------------------------
    ; STEP 4: Read 256 words (512 bytes) from data port 0x1F0 using REP INSW
    ; REP INSW reads CX words from I/O port DX into [RDI], incrementing RDI.
    ; This is a block I/O op — QEMU handles it as one operation (~256x faster).
    ; -------------------------------------------------------------------------
    mov rdi, r9                 ; destination buffer (RDI for string ops)
    mov rcx, 256                ; 256 16-bit words = 512 bytes
    mov dx, 0x1F0
    rep insw                    ; read all 256 words from port 0x1F0 into [RDI++]

    ; -------------------------------------------------------------------------
    ; STEP 5: Advance to next sector
    ; -------------------------------------------------------------------------
    mov r9, rdi                 ; update buffer pointer (RDI advanced by rep insw)
    inc r8                      ; next LBA
    dec r10                     ; decrement remaining count
    jmp .read_loop

.read_done:
    xor rax, rax                ; success

.read_error:
    pop r10
    pop r9
    pop r8
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    ret

; ============================================================================
; READ_DISK_SECTOR: Single sector read
; RAX = LBA, RDI = destination buffer
; ============================================================================
read_disk_sector:
    mov rcx, 1
    call read_sectors_bios
    ret
