; LillyOS Bootloader
;
; This is the LillyOS Bootloader for 32-bit, x86 systems.  It is a small program that is placed into the boot sector
; (sector 0) of a floppy disk or other bootable drive.  Its purpose is to record any information the kernel requires
; from the CPU while in Real Mode, switch the CPU to Protected Mode, load the kernel into memory, and hand execution
; over to the kernel.
;
; As the bootloader is placed in a single sector, it is imparative that, when compiled, it fits within 512 bytes.  The
; last two bytes of the sector are reserved for the standard BIOS boot code 0xAA55.

	; Tell NASM we're working in 16-bit mode

	BITS 16

	; Set up 4k of stack space after the bootloader

	mov ax, 0x7c00						; Segment 0 starts at 0x7c00 for BIOS
	add ax, 288							; Add the paragraph size (288 bytes) or ((4096 + 512) / 16) to the A register
	mov ss, ax							; Store 1984 into the 2nd segment register (SS)
	mov sp, 4096						; Set the stack pointer (SP) to the 4096th byte

	mov ax, 07C0h						; Move the A register (AX) back to the beginning of the segment
	mov ds, ax							; Move the segment location 1984 into the data segment (DS)

	; Prints "Hello World" on the screen

	mov si, text_string					; Put the pointer of text_string into the source index register (SI)
	call print_string					; Call our string-printing routine

	; Halts the computer in an infinite loop

	jmp $								; Jump to this line (infinite loop)


	; Variables

	text_string db 'Hello World', 0		; Define bytes (DB) for test_string


;
; Routine - output string in SI to string
;
print_string:
	mov ah, 0Eh		; interrupt 10h 'print char' function

.repeat:
	lodsb			; Get character from string
	cmp al, 0		; If 0, jump to .done
	je .done
	int 10h			; Else, print the character
	jmp .repeat

.done:
	ret

	; Create the BIOS boot signature (0x55 and 0xAA in offsets 510 and 511 respectively) in sector 0.  This tells the
	; BIOS to load the first sector into memory at 0x0000:0x7c00 (segment 0) to be executed.  This is our bootloader.
	;
	; For floppy drives, 512 bytes of the boot record are executable.  For hard drives, the Master Boot Record (MBR)
	; holds executable code at offset 0x0000 - 0x01bd, followed by table entries for the four primary partitions,
	; using sixteen bytes per entry (0x01be - ox01fd) and the two-byte signature (0x01fe - 0x01ff).
	;
	; This platform emulates a floppy drive (as all external bootable devices do), so we place them at 510 and 511.

	times 510-($-$$) db 0	; Pad the remainder of the boot sector with 0s
	dw 0xAA55				; Standard PC boot signature for sector
