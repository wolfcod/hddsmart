@echo off
del bin\floppy.img
c:\tools\nasm.exe boot\loader.asm -o bin\loader.bin

c:\tools\nasm.exe boot\boot16.asm -o bin\floppy.img

:buildbx
cl /c tools\bxwriter.c /Fobin\bxwriter.obj
link /OUT:bin\bxwriter.exe bin\bxwriter.obj
