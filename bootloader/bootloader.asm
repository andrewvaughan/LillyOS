; ====================================================================================================================
; LillyOS Bootloader for 32-bit x86 Systems
; --------------------------------------------------------------------------------------------------------------------
;
; This bootloader is loaded into the first sector of the disk (0000:7c00).  It is built for compilation using the NASM
; assembler.
;
; Once loaded, execution is passed to the bootloader with the machine in Real Mode.  Using a series of BIOS interrupts
; and memory modifications, this simple bootloader does the following:
;
;   1. Create 4k bytes of stack space above the first segment
;   2. Store a table of data in memory that is only accessible while in Real Mode (RAM count, video modes, etc...)
;   3. Load the kernel into executable memory
;   4. Transition the CPU from Real Mode to Protected Mode
;   5. Transfer execution to the kernel
;
; Memory Map
;
;   The memory for this system uses FAT12, emulating that of a floppy disk.  This should be usable across all media,
;   and works well for the small size of the operating system.  This *may* need to change to support larger file
;   transfers later, at which time FAT32 (or, more likely, ExFAT) should be used.
;
;   0000:0002    Jump to Boot Code
;   0003:0023    BIOS Parameter Block (BPB)
;   0024:003D    Extended Boot Record (EBPB)
;   003E:01FD    Boot Code
;   01FE:01FF    Bootable Partition Signature (0xAA55)
; --------------------------------------------------------------------------------------------------------------------




; --------------------------------------------------------------------------------------------------------------------
; Assembler Flags
; --------------------------------------------------------------------------------------------------------------------

; Tell the assembler we're working in 16-bit mode

[BITS 16]




; --------------------------------------------------------------------------------------------------------------------
; Bootloader Jump
; --------------------------------------------------------------------------------------------------------------------

; 3 Bytes (0000:0002)
;
; The first three bytes (EB 3C 90) disassemble to JMP SHORT 3C NOP. (The 3C value may be different.) The reason for
; this is to jump over the disk format information (the BPB and EBPB). Since the first sector of the disk is loaded
; into ram at location 0x0000:0x7c00 and executed, without this jump, the processor would attempt to execute data that
; isn't code

    jmp short bootloader
    nop




; --------------------------------------------------------------------------------------------------------------------
; BIOS Parameter Block (BPB)
; --------------------------------------------------------------------------------------------------------------------

; This is a non-executable portion of the disk that informs the system what type of media is being used.  In LillyOS,
; we emulate the FAT12 system as it supports most of our needs while emulating a floppy disk.  Eventually, this
; system may be upgraded to FAT32 (or ExFAT) to support larger filenames and directories.
;
; All numbers in this area are in little-endian format.
;
; Most commentary is compiled from the following sources:
;   * https://support.microsoft.com/en-us/help/140418/detailed-explanation-of-fat-boot-sector
;   * http://wiki.osdev.org/FAT


; OEM Identifier
;
; 8 Bytes (0003:000A)
;
; The first 8 Bytes (3-10) is the version of DOS being used. The next eight Bytes read out the name of the version.
; The official FAT Specification from Microsoft says that this field is really meaningless and is ignored by MS FAT
; Drivers, however it does recommend the value "MSWIN4.1" as some 3rd party drivers supposedly check it and expect it
; to have that value. Older versions of dos also report MSDOS5.1 and linux-formatted floppy will likely to carry
; "mkdosfs" here. If the string is less than 8 bytes, it is padded with spaces.

OEMLabel db "LILLY0.1"


; Bytes Per Sector
;
; 2 Bytes (000B:000C)
;
; This is the size of a hardware sector and, for most disks in the United States, this is set to 512.

BytesPerSector dw 512


; Sectors Per Cluster
;
; 1 Byte (000D:000D)
;
; Because FAT is limited in the number of clusters (or "allocation units") that it can track, large volumes are
; supported by incresing the number of sectors per cluster.  The cluster factor for a FAT volume is entirely dependent
; on the size of the volume.  Valid values for this field are 1, 2, 4, 8, 16, 32, 64, and 128.

SectorsPerCluster db 1


; Reserved Sectors
;
; 2 Bytes (000E:000F)
;
; This is the number of sectors reserved for the media, preceeding the first FAT, including the boot sector.

ReservedSectors dw 1


; Number of FATs
;
; 1 Byte (0010:0010)
;
; This is the number of copies of the FAT table stored on disk.  Thsi vlaue is usually 2.

NumberOfFATs db 2


; Root Entries
;
; 2 Bytes (0011:0012)
;
; This is the total number of file name entries that can be stored in the root directory of the volume.  On a typical
; hard drive, the value of this field is 512.  Note, however, that one entry is always used as a Volume Label, and
; that files with long file names will use up multiple entries per file.  This means the largest number of files in
; the root directory is typically 511, but that you will run out of entries before that, if long file names are used.
;
; Importantly, this number must be set to a value that will fill an entire sector (or sectors).
;
; For LillyOS, we reserve space for about 160 files (taking 32B per file to index) in the root system:
;    160 files at 32B per file = 5,120 (or 10 Sectors at 512B per sector)

RootEntries dw 160


; Logical Sectors
;
; 2 Bytes (0013:0014)
;
; This is the total sectors available in the logical (physical) volume.  If this value is 0, it means there are more
; than 65,535 sectors in the volume, and the actual count is stored in the "Large Sectors" area of the BPB (see
; below).
;
; In this case, 2880 sectors of 512B each is equivalent to a 1.4MB Floppy disk

LogicalSectors dw 2880


; Media Descriptor Type
;
; 1 Byte (0015:0015)
;
; The following bytes are used to tell the system what type of media is being used:
;
; | Byte | Capacity | Media Description             |
; |------|----------|-------------------------------|
; |  F0  | 2.88 MB  | 3.5-inch, 2-sided, 36-sector  |
; |  F0  | 1.44 MB  | 3.5-inch, 2-sided, 18-sector  |
; |  F9  |  720 kB  | 3.5-inch, 2-sided, 9-sector   |
; |  F9  |  1.2 MB  | 5.25-inch, 2-sided, 15-sector |
; |  FD  |  360 kB  | 5.25-inch, 2-sided, 9-sector  |
; |  FF  |  320 kB  | 5.25-inch, 2-sided, 8-sector  |
; |  FC  |  180 kB  | 5.25-inch, 1-sided, 9-sector  |
; |  FE  |  160 kB  | 5.25-inch, 1-sided, 8-sector  |
; |  F8  |  ------  | Fixed Disk                    |

MediumDescriptor db 0xF0


; Sectors Per FAT
;
; 2 Bytes (0016:0017)
;
; Used only for FAT12/FAT16.  This describes the number of sectors occupied by each of the FATs on the volume.  Given
; this information, together with the number of FATs and reserved sectors lised above, the point at which the root
; directory begins can be computed.  Given the number of entries in the root directory, we can also compute where the
; user data area of the disk begins.

SectorsPerFAT dw 9


; Sectors Per Track
;
; 2 Bytes (0018:0019)
;
; These values are part of the disk geometry in use when the disk was formatted.  The medium we identified above lists
; 36 sectors, but as it is two sided, that infers 18 sectors per track.

SectorsPerTrack dw 18


; Sides/Heads
;
; 2 Bytes (001A:001B)
;
; This describes the number of sides (or heads, with a physical disk) that are available on the storage media.  By
; combinging this with the number of sectors per track, the total number of sectors can be calculated.
;
; In this case, we are emulating a double-sided floppy disk.

Sides dw 2


; Hidden Sectors
;
; 4 Bytes (001C:001F)
;
; This is the number of sectors on the physical disk preceding the start of the volume (that is, before the boot
; sector, itself).  It is used during the boot sequence in order to calculate the absolute offset to the root
; directory and data files.  An example of this data might be Logical Block Addressing (LBA) or other addressing
; schemes not part of the basic FAT standard.

HiddenSectors dd 0


; Large Sectors
;
; 4 Bytes (0020:0023)
;
; If the logical sector designation is set to 0 in the BPB, this larger value is used to contain the number of sectors
; used by the FAT volume, instead.  An example of when this might be used is with Logical Block Addressing (LBA).

LargeSectors dd 0




; --------------------------------------------------------------------------------------------------------------------
; Extended BIOS Parameter Block (EBPB)
; --------------------------------------------------------------------------------------------------------------------

; This is an extended amount of information that can come immediately after the BPB.  This data can contain different
; information, depending on the standard being used (i.e., FAT12, FAT16, or FAT32).
;
; The following is for the FAT12 protocol, but also will work with FAT16:


; Drive Number
;
; 1 Byte (0024:0024)
;
; This is related to the BIOS physical drive number.  Floppy drives are numbered, starting with 0x00 for the A: drive,
; while physical hard disks are numbered starting with 0x80.  Typically, you would set this value prior to using the
; int 13h BIOS call in order to specify the device to access.  The on-disk value stored in this field is typically
; 0x00 for floppies, and 0x80 for hard disks, regardless of how many physical disk drives exist, because the value is
; only relevant if the device is a boot device.

DriveNumber dd 0


; Current Head
;
; 1 Byte (0025:0025)
;
; This is another field typically used when doing INT13 BIOS calls.  This value would originally have been used to
; store the track on which the boot record was located, but the value stored on disk is not currently used as such.
; Windows systems use this byte, instead, as a bit-flag, determining if chkdisk or surface scans can be run.  As such,
; it can safely be set to 0.

CurrentHead dd 0


; Signature
;
; 1 Byte (0026:0026)
;
; The extended boot record signature must be set to 0x28 or 0x29 to be recognized in Windows.  Setting it as such
; makes it easier to use with those systems.

Signature db 0x29


; Volume ID
;
; 4 Bytes (0027:002A)
;
; This is a random serial number, assigned at format time, in order to aid in distinguishing between one disk and
; another.  It is entirely optional.

VolumeID dd 0x0


; Volume Label
;
; 11 Bytes (002B:0035)
;
; This is an old area in which volume labels were originally stored.  In most modern systems, volume labels are now
; stored as a special file in the root directory.  Short names in this field should be padded with spaces.

VolumeLabel db "LILLYOS-0.1"


; System ID
;
; 8 Bytes (0036:003D)
;
; This field is either FAT12 or FAT16, depending on the format of the disk.  Any extra length should be padded by
; spaces.

FileSystem db "FAT12   "




; --------------------------------------------------------------------------------------------------------------------
; Main Bootloader
; --------------------------------------------------------------------------------------------------------------------

; Reserve 8k bytes of space after the boot sector as a buffer
bootloader:
    mov ax, 0x07C0     ; Move the A register (AX) to the end of the buffer
    add ax, 32         ; 32 Paragraphs for boot sector (512 bytes)
    add ax, 512        ; 512 Paragraphs for buffer (8,192 bytes)

; Reserve 4k bytes of space after the buffer for the stack
create_stack:
    cli                ; Disable interrupts during stack modification
    mov ss, ax         ; Move the stack segment register (SS) to just after the end of the buffer
    mov sp, 4096       ; Move the stack pointer (SP) to the 4,096th byte
    sti                ; Restore interrupts

    mov ax, 0x7c0      ; Move the data segment register (DS) to the beginning of segment 0
    mov ds, ax

; Prints "Hello World" on the screen
hello_world:
	mov si, str_hello  ; Put the pointer of text_string into the source index register (SI)
	call print_string  ; Call our string-printing routine

; Halts the computer in an infinite loop
halt:
	jmp $              ; Jump to this line (infinite loop)




; --------------------------------------------------------------------------------------------------------------------
; Constants
; --------------------------------------------------------------------------------------------------------------------

	str_hello db 'Hello World', 0




; --------------------------------------------------------------------------------------------------------------------
; Subroutines
; --------------------------------------------------------------------------------------------------------------------

; Outputs a string pointed to by SI to the screen
print_string:
	mov ah, 0Eh  ; interrupt 10h 'print char' function

; Keeps printing out characters until a null byte is encountered
.repeat:
	lodsb        ; Get character from string
	cmp al, 0    ; If 0, jump to .done
	je .done
	int 10h      ; Else, print the character
	jmp .repeat

; Generic return statement
.done:
	ret




; --------------------------------------------------------------------------------------------------------------------
; Boot Signature
; --------------------------------------------------------------------------------------------------------------------

; This tells the BIOS that this is a boot sector, so that it will load it into memory at 0x0000:0x7c00 (segment 0) to
; be executed.  This completes our bootloader.
;
; For floppy drives, 512 bytes of the boot record are executable.  For hard drives, the Master Boot Record (MBR) holds
; executable code at offset 0x0000 - 0x01bd, followed by table entries for the four primary partitions, using sixteen
; bytes per entry (0x01be - ox01fd) and the two-byte signature (0x01fe - 0x01ff).
;
; This platform emulates a floppy drive (as all external bootable devices do), so we place them at 510 and 511.

	times 510-($-$$) db 0  ; Pad the remainder of the boot sector with 0s
	dw 0xAA55              ; Standard PC boot signature for sector
