[BITS 16]
[ORG 0x0000]

%define BOOT_SEG    07c0h
%define BOOT_STACK_TOP  7bfeh

%define KERNEL_DS 18h
%define KERNEL_CS 10h

CPU 386

boot:
    jmp prologue                ; 3 reserved bytes for JUMP
    nop                         ; alignment
    
    db 'M', 'S', 'D', 'O', 'S', '5', '.', '0'   ; OEM name of the volume
bytes_per_sector:
    dw 200h ; Bytes per sector                  ; bytes per sector
sectors_per_cluster:
    db 01h   ; Sector per cluster               ; sector per cluster
reserved_sector:
    dw 01h  ; Reserved sector                   ; reserved sectors
number_of_fat:
    db 02h                                      ; Number of allocation fat
entries_in_root:
    dw 0e0h                                     ; Number of entries in the root directory
total_sectors:
    dw 0b40h                                    ; Total sectors (0 total_sectors 2)
media_descriptor:
    db 0f0h                                     ; Media descriptor
sectors_per_fat:
    dw 09h                                      ; Number of sectors per fat
sectors_per_track:
    dw 12h
heads:
    dw 02h
hidden_sectors:
    dd 00h
total_sectors2:
    dd 00h
drive_index:
    db 00h
    db 00h                                      ; reserved
volume_id:
    dd 00h
label:
    db "HDDSMART   "
fat:
    db "FAT12   "

prologue:
    jmp  BOOT_SEG:init

init:
    mov     ax, cs
    mov     ds, ax
    mov     es, ax
    mov     ss, ax
    mov     ax, BOOT_STACK_TOP
    mov     ah,9
    mov     al,64
    mov     bh, 0                            ; display page 0
    mov     bl,4
    mov     cx,1
    int     010h
    ;hlt
    mov     si, boot_msg
    call    printf

; PROCEDURE printf
; display ASCIIZ string at ds:si via BIOS
;*************************************************************************
printf:
    lodsb                                       ; load next character
    or      al, al                              ; test for NUL character
    jz      @1
    mov     ah, 00Eh                            ; BIOS teletype
    mov     bh, 000h                            ; display page 0
    mov     bl, 007h                            ; text attribute
    int     010h                                ; invoke BIOS
    jmp     printf
@1:
    ret

kernel_sys:
    db "KERNEL  SYS"
boot_msg db "Loading HDDsmart", 0dh, 0ah, 0

TIMES 510- ($ - $$) db 0

signature:
    db 055h, 0aah
 
; alignment for bochsdbg
TIMES 1474560 - ($ - $$) db 0

