; ============================================================================
; PHASE 5D: DISK I/O DRIVER (PIO ATA disk reading in 64-bit mode)
; ============================================================================
; Provides sector-level disk reading directly via ATA PIO commands
; Works in 64-bit long mode without mode switching complexity

[BITS 64]

; ============================================================================
; ATA PIO COMMAND REGISTERS (I/O ports for first IDE channel)
; ============================================================================

; ATA_DATA = 0x1F0          ; Data register (read/write sectors)
; ATA_ERROR = 0x1F1         ; Error register (read only)
; ATA_SECTOR_COUNT = 0x1F2  ; Sector count
; ATA_SECTOR_NUM = 0x1F3    ; Starting sector number (LBA low byte)
; ATA_CYL_LOW = 0x1F4       ; Cylinder low byte (LBA mid byte)
; ATA_CYL_HIGH = 0x1F5      ; Cylinder high byte (LBA high byte)
; ATA_DRIVE_HEAD = 0x1F6    ; Drive and head select
; ATA_STATUS = 0x1F7        ; Status register (read)
; ATA_COMMAND = 0x1F7       ; Command register (write)

global read_sectors_bios
global read_disk_sector

; ============================================================================
; READ_SECTORS_BIOS: Read sectors via ATA PIO in 64-bit mode
; Parameters:
;   RAX = starting LBA sector
;   RDI = destination buffer
;   RCX = number of sectors to read (512 bytes each)
; Returns:
;   RAX = 0 on success, non-zero on error
; ============================================================================

read_sectors_bios:
    ; ============================================================================
    ; PHASE 5D: ATA PIO Read Implementation
    ; ============================================================================
    ;
    ; For QEMU, this reads actual sectors from the virtual disk via ATA PIO
    ; commands. The kernel loader (Stage 2) already uses similar code, so
    ; we follow the same pattern for consistency.
    ;
    ; NOTE: This is simplified for QEMU. Real hardware requires:
    ; - Proper CHS conversion or 48-bit LBA
    ; - DMA or additional timing/IRQ handling
    ; - Error recovery and retry logic
    ; ============================================================================

    push rbx
    push rcx
    push rdx
    push rsi

    ; Save parameters
    mov r8, rax                 ; R8 = LBA sector
    mov r9, rdi                 ; R9 = destination buffer
    mov r10, rcx                ; R10 = sector count

    xor rax, rax                ; RAX = 0 (success by default)

.read_loop:
    ; For each sector, use ATA PIO to read
    ; In QEMU, we can use CHS addressing or LBA (28-bit)

    ; Convert LBA to CHS for ATA PIO:
    ; Sector = (LBA % 63) + 1
    ; Head = ((LBA / 63) % 16)
    ; Cylinder = (LBA / (63 * 16))

    mov rax, r8
    mov rcx, 63
    xor edx, edx
    div rcx                    ; EAX = LBA/63, EDX = LBA%63
    mov cl, dl
    inc cl                      ; CL = sector (1-63)

    mov r11d, eax              ; R11D = cylinder*heads (save before another division)
    xor edx, edx
    mov eax, r11d
    mov r12d, 16
    div r12d                   ; EAX = cylinder, EDX = head
    mov dh, dl                 ; DH = head
    mov bh, al                 ; BH = cylinder low byte (for later use)
    shr eax, 8
    mov bl, al                 ; BL = cylinder high byte (for later use)

    ; ============================================================================
    ; Write ATA PIO registers
    ; ============================================================================

    ; Wait for drive ready
    mov rcx, 1000000
.wait_ready:
    mov al, [0x1F7]            ; Read status
    test al, 0x80              ; Bit 7 = BSY (busy)
    jz .ready
    dec rcx
    jnz .wait_ready

    mov rax, 1                 ; Error: timeout
    jmp .read_error

.ready:
    ; Write sector count (always 1 in this loop)
    mov al, 1
    mov dx, 0x1F2
    out dx, al

    ; Write sector number (LBA low byte)
    mov al, cl                 ; CL = sector number
    mov dx, 0x1F3
    out dx, al

    ; Write cylinder low byte (LBA mid byte)
    mov al, bh                 ; BH = cylinder low byte
    mov dx, 0x1F4
    out dx, al

    ; Write cylinder high byte (LBA high byte)
    mov al, bl                 ; BL = cylinder high byte
    mov dx, 0x1F5
    out dx, al

    ; Write drive/head select
    mov al, dh                 ; DH = head
    or al, 0xA0               ; 0xA0 = drive 0, LBA mode
    mov dx, 0x1F6
    out dx, al

    ; Send READ SECTOR command (0x20)
    mov al, 0x20
    mov dx, 0x1F7
    out dx, al

    ; ============================================================================
    ; Wait for data ready
    ; ============================================================================

    mov rcx, 1000000
.wait_data:
    mov al, [0x1F7]            ; Read status
    test al, 0x80              ; Bit 7 = BSY
    jnz .wait_data_retry

    test al, 0x08              ; Bit 3 = DRQ (data ready)
    jnz .data_ready

.wait_data_retry:
    dec rcx
    jnz .wait_data

    mov rax, 2                 ; Error: data timeout
    jmp .read_error

.data_ready:
    ; ============================================================================
    ; Read 512 bytes (256 words) from data port
    ; ============================================================================

    mov rsi, r9                ; RSI = destination buffer
    mov rcx, 256               ; 256 words (512 bytes)

.read_words:
    in ax, 0x1F0               ; Read word from data port
    mov [rsi], ax
    add rsi, 2
    loop .read_words

    ; ============================================================================
    ; Advance to next sector
    ; ============================================================================

    mov r9, rsi                ; Update buffer pointer
    inc r8                      ; Next sector
    dec r10                    ; Decrement count
    jnz .read_loop

    xor rax, rax               ; Success

.read_error:
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    ret

; ============================================================================
; READ_DISK_SECTOR: Single sector read (for testing)
; Parameters:
;   RAX = LBA sector number
;   RDI = destination buffer (512+ bytes)
; Returns:
;   RAX = 0 on success
; ============================================================================

read_disk_sector:
    mov rcx, 1
    call read_sectors_bios
    ret
