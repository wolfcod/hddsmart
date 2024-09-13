[BITS 16]
[ORG 0x0000]

%define BOOT_SEG        800h
%define BOOT_STACK_TOP  07beh

%define KERNEL_DS 18h
%define KERNEL_CS 10h

setup:
    ; load extended 
    call    disable_cursor
    call    kill_motor

    cli     ; disable interrupts
    mov al, 80h
    out 070h, al

    call    enable_a20

    ; initialize GDT and IDT
    xor eax, eax
    mov ax, cs
    shl eax, 4
    add dword [gdt_descr - setup + 2], eax
    lgdt [gdt_descr - setup]
    lidt [idt_descr - setup]

    mov eax, cr0
    or eax, 1
    mov cr0, eax
    jmp flush

flush:
    mov ax, KERNEL_DS
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov fs, ax
    mov gs, ax
switch:
    jmp KERNEL_CS:0

    hlt

    ; enable A20
enable_a20:
    in      al, 092h
    test    al, 2
    jnz     @2
    or      al, 2
    and     al, 0feh
    out     092h, al
@2:
    ret


; PROCEDURE kill_motor
; disable floppy drive motor
;*************************************************************************
kill_motor:
    push    dx
    mov     dx, 03f2h
    xor     al, al
    out     dx, al
    pop     dx
    ret

; PROCEDURE disable_cursor
; disable the cursor via BIOS
;*************************************************************************
disable_cursor:
    mov ah, 01h
    mov bh, 00h
    mov cx, 2000h   ;  
    int 10h
    ret

; A minimal GDT and IDT.

TIMES   440 - ($ - $$) db 0
gdt:
	dq	0x0000000000000000	; NULL descriptor
	dq	0x0000000000000000	; not used
	dq	0x00c09a0000007fff	; 128MB 32-bit code at 0x000000
	dq	0x00c0920000007fff	; 128MB 32-bit code at 0x000000
gdt_end:

	dw	0			; for alignment
gdt_descr:
	dw 	gdt_end - gdt - 1	; gdt limit
	dd	gdt - setup		; gdt base - relocated at run time

	dw	0			; for alignment
idt_descr:
	dw	0			; idt limit=0
	dd	0			; idt base=0

