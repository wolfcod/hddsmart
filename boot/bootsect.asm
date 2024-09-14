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
heads_per_cylinder:
    dw 02h
hidden_sectors:
    dd 00h
total_sectors2:
    dd 00h
DriveNumber:
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
    mov     [DriveNumber], dl   ; 
    
    mov     ax, cs
    mov     ds, ax
    mov     es, ax
    xor     ax, ax
    mov     ss, ax
    mov     ax, BOOT_STACK_TOP
    mov     sp, ax
    
    push    dx

    mov     si, boot_msg
    call    printf
    pop     dx

    or      dl, dl
    jns     skip_geometry
detect_geometry:
    mov     di, 200h    ;
    mov     ah, 08h
    int     13h         ; dl already initialized
    mov     ax, cx
    shr     ax, 6
    and     cx, 63      
    mov     [sectors_per_track], cx
    mov     cl, dh
    inc     cx
    mov     [heads_per_cylinder], cx

skip_geometry:
    sub     sp, 10h
    mov     bp, sp      ; we are using bp to store some data
    xor     dx, dx
    xor     ax, ax
    mov     [bp+2], ax
    mov     [bp+4], ax
    mov     bx, 800h
    mov     es, bx
    mov     [bp+6], bx
    xor     cx, cx
    xor     bx, bx

    mov     cx, [sectors_per_fat]       ; read sectors_per_fat from sector 0 (+ reserved + hidden) to ES:BX (800:0)
    call    read_sector
    
    xor     dx, dx
    mov     ax, 20h
    mov     cx, [entries_in_root]
    mul     cx
    shr     ax, 9   ; convert size in bytes to sectors
    mov     [bp+2], ax  ; number of sectors for root directory

    mov     di, 0c00h
    mov     es, di
    mov     bx, ax

    mov     al, [sectors_per_fat]   
    xor     cx, cx
    mov     cl, [number_of_fat]
    mul     cx
    add     [bp+2], ax              ; size in sectors of fat

    xor     bx, bx
    call    read_sector             ; read root

    mov     ah,9
    mov     al,64
    mov     bh, 0                            ; display page 0
    mov     bl,4
    mov     cx,1
    int     010h
    mov     di, 0c00h
    mov     es, di
    xor     di, di
    mov     dx, [entries_in_root]

find_file:
    mov     si, kernel_sys
    mov     cx, 11
    push    di
    repe    cmpsb
    pop     di
    je      found
    add     di, 32
    dec     dx
    jnz     find_file

    mov     si, not_found
    call    printf
    hlt
    int     19h

found:
    mov     di, es:[di+1ah]     ; cluster no.
    mov     ax, 1000h
    mov     es, ax
    xor     bx, bx

; Read a FAT12 cluster
; ES:BX => buffer address
; DI => Cluster no
; BP => FAT table
; BP-4 => 
read_cluster:
    lea     ax, [di-2]  ;
    xor     ch, ch
    mov     cl, [sectors_per_cluster]
    mul     cx
    add     ax, [bp+2]
    adc     dx, [bp+4]
    call    read_sector
    mov     ax, 3
    mul     di
    shr     ax, 1
    xchg    ax, di
    push    ds
    mov     ds, [bp+6]
    mov     di, [di]
    pop     ds
    mov     cl, 4
    jc      read_cluster_odd
    shl     di, cl
read_cluster_odd:
    shr     di, cl
    cmp     di, 0ff8h
    jc      read_cluster

    cli
    jmp     1000h:0h        ; Jump to the entry point

; Reads a sector using BIOS Int13h AH 02
; DX:AX = LBA
; CX = sector count
; cylinder = (LBA / SPT) / HPC
; head = (LBA / SPT) % HPC 
read_sector:
    push    ax
    push    dx
    push    cx
    add     ax, [reserved_sector]
    adc     dx, bx
    add     ax, [hidden_sectors]
    adc     dx, [hidden_sectors+2]
    jc      read_error
    test    dh, dh
    jnz     read_error

    xchg    ax, cx   ; save lba low word in cx
    xchg    ax, dx   ; LBA hi word

    cwd
    div     word [sectors_per_track]
    xchg    ax, cx
    div     word [sectors_per_track]
    xchg    cx, dx
    inc     cx
    div     word [heads_per_cylinder]
    mov     ch, al
    cmp     ah, 4
    jae     read_error
    ror     ah, 1
    ror     ah, 1
    or      cl, ah
    mov     dh, dl
    mov     ax, 201h
    mov     dl, [DriveNumber]
    int     13h

read_error:
    pop     cx
    pop     dx
    pop     ax

    mov     ax, es
    add     ax, 20h
    mov     es, ax
    
    loop    read_sector
    ret 

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

boot_msg db "Loading HDDsmart", 0dh, 0ah, 0
not_found db "File not found", 0dh, 0ah, 0

kernel_sys:
    db "KERNEL  SYS"

TIMES 510- ($ - $$) db 0

signature:
    db 055h, 0aah
 
; alignment for bochsdbg
; TIMES 1474560 - ($ - $$) db 0

