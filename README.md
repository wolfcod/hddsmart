# hddsmart

HDD-Smart is a POC for dealing with Hard Drive and their firmware.

Structure of this project
    - /boot:    bootsect for FAT12 prepared to 1.44Mb, as floppy. The output file must be placed as entry of a fat12 disk.
    - /kernel:  16bit loader to initialize 32-bit application which contains all application and logic

## boot sector details
Starts at 0:7C00 (physical address 07c000).
The boot loader jump to 7c0:0 (same physical address), initialize stack, code data and extra segment to same value.
Stack initialized to ss:sp 7cbe (two bytes below boot sector code)
DL initially contains the boot drive number, used to understand if it's starting from hard drive or floppy disk.

The next step is to load in memory at address 800:0 (512 bytes upper boot code in memory) a copy of fat12 (only a single copy, not both), usually only 9 sectors.
At address C00:0 the root directory is loaded, where the file "KERNEL.SYS" must be present.

From the root directory entry, the file is loaded cluster per cluster in memory at address 1000:0 and the code is transferred to the next step.

## kernel.sys
Kernel.sys is a binary file responsible to map the main application (hddsmart.exe) in memory, which will require an access to the file system, and for this reason
the routine of disk i/o (and fat access) must be shared with kernel or duplicated.

When "kernel" is ready, the main application must be mapped in memory at a physical address present in IMAGEBASE address of PE file, the cpu will be in protected mode,
cs/ds/es/ss initialized and any 16bit interaction will be forbidden.

