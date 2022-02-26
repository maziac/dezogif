;===========================================================================
; zx.asm
;
; Some ZX Spectrum constants.
;===========================================================================


;===========================================================================
; Constants
;===========================================================================


; Start of the color attribute screen
SCREEN:   		equ 0x4000
SCREEN_SIZE:	equ 0x1800

; Start of the color attribute screen
COLOR_SCREEN:   equ 0x5800
COLOR_SCREEN_WIDTH:	equ 32
COLOR_SCREEN_HEIGHT:	equ 24
COLOR_SCREEN_SIZE:	equ COLOR_SCREEN_WIDTH*COLOR_SCREEN_HEIGHT	; 768=0x300

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
