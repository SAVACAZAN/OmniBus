; ============================================================================
; PHASE 5D-1: REAL-MODE BIOS DISK I/O STUB
; ============================================================================
; This code runs in 16-bit real mode to invoke BIOS INT 0x13 for disk reads
; Linked at a fixed address that kernel can reach via mode switch

[BITS 16]
ORG 0x8000  ; Real-mode stub at 0x8000 (below 1MB, accessible to BIOS)

; ============================================================================
; REAL-MODE ENTRY POINT (called from kernel after mode switch)
; ============================================================================

realmode_disk_read:
    ; Parameters passed via registers (from 64-bit kernel):
    ; EAX = LBA sector number
    ; EDX = drive number (0x80 = first hard disk)
    ; ECX = sector count
    ; ES:BX = destination buffer address (must be < 1MB)

    ; Convert LBA to CHS (Cylinder/Head/Sector)
    ; Formula:
    ;   C = LBA / (heads * sectors_per_track)
    ;   H = (LBA / sectors_per_track) % heads
    ;   S = (LBA % sectors_per_track) + 1

    ; For standard BIOS geometry: 63 sectors/track, 16 heads
    mov cx, 63                  ; sectors_per_track
    xor dx, dx
    div cx                      ; EAX = cylinder*heads, EDX = remainder
    mov cl, dl                  ; CL = remainder (sector offset)
    inc cl                      ; S = offset + 1

    mov dx, 16                  ; heads count
    xor dx, dx
    mov ax, ax                  ; reload quotient
    div dx                      ; EAX = cylinder, EDX = head
    mov dh, dl                  ; DH = head

    ; Load sector parameters into BIOS registers
    mov ah, 0x02                ; BIOS read sector service
    mov al, 1                   ; Read 1 sector at a time
    ; CL already has sector number
    ; CH = low 8 bits of cylinder (already in place)
    mov ch, al                  ; TODO: fix cylinder encoding
    ; DH = head (already set)
    ; DL = drive (already from parameter)

    ; ES:BX = buffer address (already set from parameter)

    ; Call BIOS disk read
    int 0x13

    ; Return: AH = status (0 = success)
    mov al, ah                  ; Move status to AL for return

    ; Switch back to long mode (kernel will do this)
    retf                        ; Far return to caller

; ============================================================================
; REAL-MODE END
; ============================================================================

align 512
