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

; Keyboard ports: Bits 0-4. Bit is low if pressed.
; Example: in PORT_KEYB_54321, 2 is bit 1. in PORT_KEYB_67890, 0 is bit 0
PORT_KEYB_54321:            equ 0xF7FE ; 5, 4, 3, 2, 1
PORT_KEYB_67890:            equ 0xEFFE ; 6, 7, 8, 9, 0
PORT_KEYB_BNMSHIFTSPACE:    equ 0x7FFE ; B, N, M, Symbol Shift, Space
PORT_KEYB_HJKLENTER:        equ 0xBFFE ; H, J, K, L, Enter
PORT_KEYB_YUIOP:            equ 0xDFFE ; Y, U, I, O, P
PORT_KEYB_TREWQ:            equ 0xFBFE ; T, R, E, W, Q
PORT_KEYB_GFDSA:            equ 0xFDFE ; G, F, D, S, A
PORT_KEYB_VCXZCAPS:         equ 0xFEFE ; V, C, X, Z, Caps Shift


; Clears the screen and opens channel 2
ROM_CLS                 EQU  0x0DAF             
; Open a channel
ROM_OPEN_CHANNEL        EQU  0x1601
; Print a string
ROM_PRINT               EQU  0x203C              


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
	MACRO WRITE_TBBLUE_REG tbblue_reg?, z80_reg? 
	ld a,z80_reg?
	nextreg tbblue_reg?,a
	ENDM


;===========================================================================
; Macro to copy a memory area from src to dest.
; Parameters:
;	dest = Pointer to destination
;   src = Pointer to source
;   count = The number of bytes to copy.
; Changes:
;   BC, DE, HL
;===========================================================================
	MACRO MEMCOPY dest?, src?, count?
	ld bc,count?
    ld hl,src?
    ld de,dest?
    ldir
	ENDM


;===========================================================================
; Macro to fill a memory area with a certain value.
; Parameters:
;	dest = Pointer to destination
;   value = The byte value used to fill the area.
;   count = The number of bytes to fill.
; Changes:
;   BC, DE, HL
;===========================================================================
	MACRO MEMFILL dest?, value?, count?
	ld bc,count?-1
    ld hl,dest?
	ld (hl),value?
    ld de,dest?+1
    ldir
	ENDM


;===========================================================================
; Macro to clear a memory area with zeroes.a certain value.
; Parameters:
;	dest = Pointer to destination
;   count = The number of bytes to clear.
; Changes:
;   BC, DE, HL
;===========================================================================
	MACRO MEMCLEAR dest?, count?
	MEMFILL dest?, 0, count?
	ENDM



;===========================================================================
; Creates text data from a number.
; E.g. number 123456 will translate to
;  defb '123456'
; Leading zeroes are skipped.
; Parameters:
;	number = The number to translate.
; Changes:
;   -
;===========================================================================

	MACRO STRINGIFY number?
value = number?
divisor = 1000000
digit = 0
skip = 0
    DUP 7
digit = value / divisor
skip = skip + digit
    IF skip != 0
        defb digit+'0'
    ENDIF
value = value-digit * divisor
divisor = divisor / 10
    EDUP
	ENDM
