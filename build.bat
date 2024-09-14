@echo off

if exist bin\floppy.img del floppy.img

c:\tools\nasm.exe boot\bootsect.asm -o bin\floppy.img
c:\tools\nasm.exe kernel\loader.asm -o bin\loader.bin

:buildbx
cl /c tools\bxwriter.c /Fobin\bxwriter.obj
link /OUT:bin\bxwriter.exe bin\bxwriter.obj
