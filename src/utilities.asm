;===========================================================================
; utilities.asm
;
; Misc subroutines.
;===========================================================================

    
;===========================================================================
; Constants
;===========================================================================


; Border
BORDER:     equ 0xFE

; Color codes
BLACK:          equ 0
BLUE:           equ 1
RED:            equ 2
MAGENTA:        equ 3
GREEN:          equ 4
CYAN:           equ 5
YELLOW:         equ 6
WHITE:          equ 7


;===========================================================================
; Data. 
;===========================================================================


;===========================================================================
; Reads a TBBLUE register.
; Parameters:
;   A = The register to read
; Returns:
;   A = The value
; Changes:
;   BC
;===========================================================================
read_tbblue_reg:
	; Select register in A
	ld bc,IO_NEXTREG_REG
	out (c),a
	; Read register
	inc b	; TBBLUE_REGISTER_ACCESS
	in a,(c)
	ret


;===========================================================================
; Writes a value to a given TBBLUE register.
; Parameters:
;   A = register
;   D = value
; Returns:
;	-
; Changes:
;   A
;===========================================================================
/*
write_tbblue_reg:
	ld (.register+2),a
	ld a,d
.register:
	nextreg 0,a
	ret
*/

;===========================================================================
; Macro to write a Z80 register to a specific next register.
; E.g. use:  WRITE_TBBLUE_REG 0x13,d
; Writes register to to 0x13.
; Uses 5 bytes.
; Parameters:
;   tbblue_reg = A ZX Next register
;   z80_reg = a Z80 register, e.g. d, e, c etc.
; Changes:
;   A
;===========================================================================
	MACRO WRITE_TBBLUE_REG tbblue_reg, z80_reg 
	ld a,z80_reg
	nextreg tbblue_reg,a
	ENDM
