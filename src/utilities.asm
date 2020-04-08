;===========================================================================
; utilities.asm
;
; Misc subroutines.
;===========================================================================

    
;===========================================================================
; Constants
;===========================================================================

; Feature control registers
TBBLUE_REGISTER_SELECT:   	equ 0x243B
TBBLUE_REGISTER_ACCESS:  	equ 0x253B

; Turbo control
TURBO_CONTROL_REGISTER:		equ 0x07

; Max. clock
CLOCK_28MHZ:	equ 0b00000011


;===========================================================================
; Data. 
;===========================================================================


/*
;===========================================================================
; Reads the bank used currently for a given slot.
; Parameters:
;   A = slot (0-7)
; Returns:
;   A = bank (0-223)
; Changes:
;   A, BC
;===========================================================================
read_slot_bank:
	; Select register
	add a,0x50	; Slot
	ld bc,TBBLUE_REGISTER_SELECT
	out (c),a
	; Read bank
	ld b,TBBLUE_REGISTER_ACCESS>>8
	in a,(c)
	ret

;===========================================================================
; Writes the bank to use for a given slot.
; Parameters:
;   A = slot (0-7)
;   D = the bank to use (0-223)
; Returns:
;	-
; Changes:
;   BC
;===========================================================================
write_slot_bank:
	; Select register
	add a,0x50	; Slot
	ld bc,TBBLUE_REGISTER_SELECT
	out (c),a
	; write bank
	ld b,TBBLUE_REGISTER_ACCESS>>8
	out (c),d
	ret
*/


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
	ld bc,TBBLUE_REGISTER_SELECT
	out (c),a
	; Read register
	ld b,TBBLUE_REGISTER_ACCESS>>8
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
write_tbblue_reg:
	ld (.register+2),a
	ld a,d
.register:
	nextreg 0,a
	ret