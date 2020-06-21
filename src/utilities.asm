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


; The address of the original ZX Spectrum character set in ROM.
ROM_FONT:  equ 0x3D00
ROM_FONT_SIZE: equ 0x0300  ; 96 chars, [0x20..0x7F]

; The ROM start address and the ROM size (16k) of the Spectrum.
ROM_START:  equ 0x0000
ROM_SIZE: equ 0x4000  ; 16k


; DivMMC, see https://velesoft.speccy.cz/zx/divide/divide-memory.htm
; DivIDE control register (write only) 227 ($E3) in original DivIDE mode:
; D7		D6		D5	D4	D3	D2	D1		D0
; CONMEM	MAPRAM	X	X	X	X	BANK1	BANK0
; This register is write-only (readed data will be unknown).
; All bits are reset to '0' after each power-on. Unimplemented bits, marked 'X', should be zeroed.
; Bits BANK1 and BANK0 select the 8k bank, which normally appears in area 2000-3fffh, when divide memory is mapped.
DIVIDE_CTRL_REG:	EQU 0xE3


;===========================================================================
; Reads a TBBLUE register.
; Parameters:
;   A = The register to read
; Returns:
;   A = The value
; Changes:
;   BC, F
;===========================================================================
read_tbblue_reg:
	; Select register in A
	ld bc,IO_NEXTREG_REG
	out (c),a
	; Read register
	inc b	; IO_NEXTREG_DAT
	in a,(c)
	ret

;===========================================================================
; Reads a TBBLUE register.
; This is meant for multiple use. You need to set BC to IO_NEXTREG_REG
; before the first call.
; Is slighlty faster than read_tbblue_reg.
; Parameters:
;   A = The register to read
;   BC = IO_NEXTREG_REG
; Returns:
;   A = The value
; Changes:
;   F
;===========================================================================
read_tbblue_reg_multiple:
	; Select register in A
	out (c),a
	; Read register
	inc b	; IO_NEXTREG_DAT
	in a,(c)
	dec b
	ret


;===========================================================================
; Writes a color to the border and waits on press
; of SPACE.
; Changes:
;   A
;===========================================================================
	MACRO WAIT_SPACE color?
	ld a,color?
	out (BORDER),a
	; Wait on key press
.not_pressed:
	ld a,HIGH PORT_KEYB_BNMSHIFTSPACE
	in a,(LOW PORT_KEYB_BNMSHIFTSPACE)
	bit 0,a	; SPACE
	jr nz,.not_pressed
	; Wait on key release
.pressed:
	ld a,HIGH PORT_KEYB_BNMSHIFTSPACE
	in a,(LOW PORT_KEYB_BNMSHIFTSPACE)
	bit 0,a	; SPACE
	jr z,.pressed
	ENDM


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
