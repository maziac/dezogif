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

; Temporary data area to be used by several subroutines.
tmp_data:   defb 4



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
