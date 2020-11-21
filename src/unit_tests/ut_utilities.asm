;========================================================
; ut_utilities.asm
;
; Unit tests for the miscelleanous subroutines.
;========================================================


    MODULE ut_utilities

; Data area for testing


; Test that register is set correctly.
UT_write_read_slot:
.free_slot:	equ ((UT_write_read_slot+2*0x2000)>>13)&0x07
	; Remember currently used bank
	ld a,.free_slot+REG_MMU
	call read_tbblue_reg
	push af		; Remember

	; Write
	;ld a,.free_slot+REG_MMU
	;ld d,29	; bank 29
	;call write_tbblue_reg
	WRITE_TBBLUE_REG .free_slot+REG_MMU,29	; bank 29

	; Read
	ld a,.free_slot+REG_MMU
	call read_tbblue_reg

	; Test
	TEST_A 29

	; Restore previous used bank
	pop de
	;ld a,.free_slot+REG_MMU
	;call write_tbblue_reg
	WRITE_TBBLUE_REG .free_slot+REG_MMU,d
 TC_END


; Test division routine.
; HL = HL/E
UT_div_hl_e:

	ld hl,0
	ld e,7
	call div_hl_e
	TEST_DREG HL, 0

	ld hl,2*3
	ld e,3
	call div_hl_e
	TEST_DREG HL, 2

	ld hl,2*3+1
	ld e,3
	call div_hl_e
	TEST_DREG HL, 2

	ld hl,2*3+2
	ld e,3
	call div_hl_e
	TEST_DREG HL, 2

	ld hl,7*89
	ld e,89
	call div_hl_e
	TEST_DREG HL, 7

	ld hl,65535
	ld e,1
	call div_hl_e
	TEST_DREG HL, 65535

	ld hl,65535
	ld e,2
	call div_hl_e
	TEST_DREG HL, 32767

 TC_END



    ENDMODULE
