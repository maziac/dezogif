;===========================================================================
; utilities.asm
;
; Misc subroutines.
;===========================================================================

    
;===========================================================================
; Constants
;===========================================================================

; Feature control registers
TBBLUE_REGISTER_SELECT:   equ 0x243B
TBBLUE_REGISTER_ACCESS:   equ 0x253B


;===========================================================================
; Data. 
;===========================================================================


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

write_tbblue_reg:
	ld (.register+2),a
.register:
	nextreg 0,a
	ret