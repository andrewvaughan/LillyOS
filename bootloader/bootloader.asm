; ====================================================================================================================
; LillyOS Bootloader for 32-bit x86 Systems
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
; MEMORY MAP (El Torito)
;   * 16 Bytes = Paragraph
;   *  2 Bytes = Word
;
;   0000:07bf    1,984 Paragraphs (31,744 Bytes)    Unknown
;   07c0:09bf    32 Paragraphs (512 Bytes)          Boot Sector (this code)
;   09c0:29bf    512 Paragraphs (8,192 Bytes)       8k Buffer
;   29c0:39bf    256 Paragraphs (4,096 Bytes)       4k Stack
; ====================================================================================================================


; Tell NASM we're working in 16-bit mode
[BITS 16]


; --------------------------------------------------------------------------------------------------------------------
; Main Bootloader
; --------------------------------------------------------------------------------------------------------------------

; Reserve 8k bytes of space after the boot sector as a buffer
create_buffer:
    mov ax, 0x7c0        ; Move the A register (AX) to the end of the buffer
    add ax, 32           ; 32 Paragraphs for boot sector (512 bytes)
    add ax, 512          ; 512 Paragraphs for buffer (8,192 bytes)

; Reserve 4k bytes of space after the buffer for the stack
create_stack:
    cli                  ; Disable interrupts during stack modification
    mov ss, ax           ; Move the stack segment register (SS) to just after the end of the buffer
    mov sp, 4096         ; Move the stack pointer (SP) to the 4,096th byte
    sti                  ; Restore interrupts

    mov ax, 0x7c0        ; Move the data segment register (DS) to the beginning of segment 0
    mov ds, ax


load_root_from_disk:

    ; Prints "Hello World" on the screen

    mov si, str_reboot  ; Put the pointer of text_string into the source index register (SI)
    call string_print    ; Call our string-printing routine


    ; Halts the computer in an infinite loop

    jmp $                ; Jump to this line (infinite loop)


; --------------------------------------------------------------------------------------------------------------------
; Constants
; --------------------------------------------------------------------------------------------------------------------

.DATA
    str_reboot db 'Press any key to restart...', 0


; --------------------------------------------------------------------------------------------------------------------
; Common Subroutines
; --------------------------------------------------------------------------------------------------------------------

; Reboot the machine
reboot:
    mov ax, 0
    int 0x19   ; Reboot (interrupt 0x19)


; Outputs the string pointed to by SI to the screen
string_print:
    mov ah, 0xE  ; Teletype (interrupt 0x10)


; Prints out characters one at a time until a null (0) is reached
.string_print_loop:
    lodsb           ; Get character from string

    cmp al, 0       ; If we hit a 0 (null), the string has finished...
    je .done        ; ...So jump to .done

    int 0xE         ; Else, print the character
    jmp .string_print_loop


; Common return subroutine
.done:
    ret


; --------------------------------------------------------------------------------------------------------------------
; Boot section buffer and BIOS boot code
; --------------------------------------------------------------------------------------------------------------------

    times 510-($-$$) db 0	; Pad the remainder of the boot sector with 0s
    dw 0xAA55				; Standard BIOS boot signature for sector


; Disk buffer begins (8k after this, disk stack starts)
buffer:
