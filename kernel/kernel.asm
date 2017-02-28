; LillyOS Kernel
;
; This is the LillyOS main kernel, which is loaded from the Bootloader.  Once in memory, it invokes filesystem
; creation, basic services, and other necessities to make LillyOS function.

	; Tell NASM we're working in 16-bit mode

	BITS 16

	; Prints "Hello World" on the screen

	mov si, text_string  ; Put the pointer of text_string into the source index register (SI)
	call print_string    ; Call our string-printing routine

	; Halts the computer in an infinite loop

	jmp $  ; Jump to this line (infinite loop)


	; Variables

	text_string db 'Hello World', 0  ; Define bytes (DB) for test_string


;
; Routine - output string in SI to string
;
print_string:
	mov ah, 0x0E    ; interrupt 10h 'print char' function

.repeat:
	lodsb           ; Get character from string
	cmp al, 0       ; If 0, jump to .done
	je .done
	int 0x10        ; Else, print the character
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
