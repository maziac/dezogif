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
	ld a,.free_slot+0x50
	call read_tbblue_reg
	push af		; Remember

	; Write
	ld a,.free_slot+0x50
	ld d,29	; bank 29
	call write_tbblue_reg 

	; Read
	ld a,.free_slot+0x50
	call read_tbblue_reg 

	; Test
	TEST_A 29

	; Restore previous used bank
	pop de
	ld a,.free_slot+0x50
	call write_tbblue_reg 

    ret 



    ENDMODULE
    