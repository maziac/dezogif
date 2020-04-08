;===========================================================================
; utilities.asm
;
; Misc subroutines.
;===========================================================================

    
;===========================================================================
; Constants
;===========================================================================




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
	add a,REG_MMU	; Slot
	ld bc,IO_NEXTREG_REG
	out (c),a
	; Read bank
	ld b,IO_NEXTREG_DAT>>8
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
	add a,REG_MMU	; Slot
	ld bc,IO_NEXTREG_REG
	out (c),a
	; write bank
	ld b,IO_NEXTREG_DAT>>8
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
write_tbblue_reg:
	ld (.register+2),a
	ld a,d
.register:
	nextreg 0,a
	ret