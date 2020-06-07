;===========================================================================
; print.asm
;
; Simple text printing.
;===========================================================================

    
;===========================================================================
; Constants
;===========================================================================

COLOR_SCREEN:   equ 0x5800  ; Start of the color attribute screen

VAR_ERRNR:	    equ 0x5c3a	; ERRNR: iy points 
ROM_PRINT_RST10h:	equ 0x15F2	; This is the address of the printing routine called by rst 16h
    
; For printing
INK:            equ 0x10 ; ZX Spectrum ASCII Control code: INK, color (Bits 0-2)
PAPER:          equ 0x11 ; ZX Spectrum ASCII Control code: PAPER, color (Bits 3-5)
PRN_FLASH:      equ 0x12 ; ZX Spectrum ASCII Control code: FLASH, on/off (Bit 7)
PRN_BRIGHT:     equ 0x13 ; ZX Spectrum ASCII Control code: BRIGHT, on/off (Bit 6)
INVERSE:        equ 0x14 ; ZX Spectrum ASCII Control code: IVERSE, on/off
OVER:           equ 0x15 ; ZX Spectrum ASCII Control code: OVER, ON=XOR/OFF=replace
AT:             equ 0x16 ; ZX Spectrum ASCII Control code: AT, y, x
TAB:            equ 0x17 ; ZX Spectrum ASCII Control code: TAB

; Color codes
BLACK:          equ 0
BLUE:           equ 1
RED:            equ 2
MAGENTA:        equ 3
GREEN:          equ 4
CYAN:           equ 5
YELLOW:         equ 6
WHITE:          equ 7
TRANSPARENT:    equ 8
FLASH:      equ 10000000b ; (Bit 7)
BRIGHT:     equ 01000000b ; (Bit 6)

; End of string
EOS:        equ 0xff



;===========================================================================
; Simple print routine.
;===========================================================================
print:
    ld a,(hl)
    cp EOS
    ret z   ; Return at 0
	push hl
	rst 10h
;    call ROM_PRINT_RST10h
	pop hl
    inc hl
    jr print 

