;========================================================
; ut_utilities.asm
;
; Unit tests for the miscelleanous subroutines.
;========================================================


    MODULE ut_utilities

; Data area for testing

	nop

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
	nop ; TEST ASSERTION A == 29

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
	nop ; TEST ASSERTION HL == 0

	ld hl,2*3
	ld e,3
	call div_hl_e
	nop ; TEST ASSERTION HL == 2

	ld hl,2*3+1
	ld e,3
	call div_hl_e
	nop ; TEST ASSERTION HL == 2

	ld hl,2*3+2
	ld e,3
	call div_hl_e
	nop ; TEST ASSERTION HL == 2

	ld hl,7*89
	ld e,89
	call div_hl_e
	nop ; TEST ASSERTION HL == 7

	ld hl,65535
	ld e,1
	call div_hl_e
	nop ; TEST ASSERTION HL == 65535

	ld hl,65535
	ld e,2
	call div_hl_e
	nop ; TEST ASSERTION HL == 32767

 TC_END


; Test integer to ascii routine (2 digits).
UT_itoa_2digits:
	ld hl,.output
	ld a,7
	call itoa_2digits
	nop ; TEST ASSERTION HL == ut_utilities.UT_itoa_2digits.output
	TEST_MEMORY_BYTE .output, '0'
	TEST_MEMORY_BYTE .output+1, '7'
	TEST_MEMORY_BYTE .output+2, 0

	ld a,0
	call itoa_2digits
	nop ; TEST ASSERTION HL == ut_utilities.UT_itoa_2digits.output
	TEST_MEMORY_BYTE .output, '0'
	TEST_MEMORY_BYTE .output+1, '0'
	TEST_MEMORY_BYTE .output+2, 0

	ld a,10
	call itoa_2digits
	nop ; TEST ASSERTION HL == ut_utilities.UT_itoa_2digits.output
	TEST_MEMORY_BYTE .output, '1'
	TEST_MEMORY_BYTE .output+1, '0'
	TEST_MEMORY_BYTE .output+2, 0

	ld a,21
	call itoa_2digits
	nop ; TEST ASSERTION HL == ut_utilities.UT_itoa_2digits.output
	TEST_MEMORY_BYTE .output, '2'
	TEST_MEMORY_BYTE .output+1, '1'
	TEST_MEMORY_BYTE .output+2, 0

	ld a,21
	call itoa_2digits
	nop ; TEST ASSERTION HL == ut_utilities.UT_itoa_2digits.output
	TEST_MEMORY_BYTE .output, '2'
	TEST_MEMORY_BYTE .output+1, '1'
	TEST_MEMORY_BYTE .output+2, 0

	ld a,99
	call itoa_2digits
	nop ; TEST ASSERTION HL == ut_utilities.UT_itoa_2digits.output
	TEST_MEMORY_BYTE .output, '9'
	TEST_MEMORY_BYTE .output+1, '9'
	TEST_MEMORY_BYTE .output+2, 0

	; Invalid input: check that only 2 bytes are written
	ld a,100
	call itoa_2digits
	nop ; TEST ASSERTION HL == ut_utilities.UT_itoa_2digits.output
	TEST_MEMORY_BYTE .output, '?'
	TEST_MEMORY_BYTE .output+1, '?'
	TEST_MEMORY_BYTE .output+2, 0

	; Invalid input: check that only 2 bytes are written
	ld a,255
	call itoa_2digits
	nop ; TEST ASSERTION HL == ut_utilities.UT_itoa_2digits.output
	TEST_MEMORY_BYTE .output, '?'
	TEST_MEMORY_BYTE .output+1, '?'
	TEST_MEMORY_BYTE .output+2, 0
 TC_END
.output:	defb 0,0,0



; Test integer to ascii routine (5 digits).
UT_itoa_5digits:
	ld de,.output
	ld hl,7
	call itoa_5digits
	nop ; TEST ASSERTION DE == ut_utilities.UT_itoa_5digits.output+4
	TEST_MEMORY_BYTE .output, '0'
	TEST_MEMORY_BYTE .output+1, '0'
	TEST_MEMORY_BYTE .output+2, '0'
	TEST_MEMORY_BYTE .output+3, '0'
	TEST_MEMORY_BYTE .output+4, '7'
	TEST_MEMORY_BYTE .output+5, 0

	ld de,.output
	ld hl,0
	call itoa_5digits
	TEST_MEMORY_BYTE .output, '0'
	TEST_MEMORY_BYTE .output+1, '0'
	TEST_MEMORY_BYTE .output+2, '0'
	TEST_MEMORY_BYTE .output+3, '0'
	TEST_MEMORY_BYTE .output+4, '0'
	TEST_MEMORY_BYTE .output+5, 0

	ld de,.output
	ld hl,99
	call itoa_5digits
	TEST_MEMORY_BYTE .output, '0'
	TEST_MEMORY_BYTE .output+1, '0'
	TEST_MEMORY_BYTE .output+2, '0'
	TEST_MEMORY_BYTE .output+3, '9'
	TEST_MEMORY_BYTE .output+4, '9'
	TEST_MEMORY_BYTE .output+5, 0

	ld de,.output
	ld hl,100
	call itoa_5digits
	TEST_MEMORY_BYTE .output, '0'
	TEST_MEMORY_BYTE .output+1, '0'
	TEST_MEMORY_BYTE .output+2, '1'
	TEST_MEMORY_BYTE .output+3, '0'
	TEST_MEMORY_BYTE .output+4, '0'
	TEST_MEMORY_BYTE .output+5, 0

	ld de,.output
	ld hl,2345
	call itoa_5digits
	TEST_MEMORY_BYTE .output, '0'
	TEST_MEMORY_BYTE .output+1, '2'
	TEST_MEMORY_BYTE .output+2, '3'
	TEST_MEMORY_BYTE .output+3, '4'
	TEST_MEMORY_BYTE .output+4, '5'
	TEST_MEMORY_BYTE .output+5, 0

	ld de,.output
	ld hl,0xFFFF
	call itoa_5digits
	TEST_MEMORY_BYTE .output, '6'
	TEST_MEMORY_BYTE .output+1, '5'
	TEST_MEMORY_BYTE .output+2, '5'
	TEST_MEMORY_BYTE .output+3, '3'
	TEST_MEMORY_BYTE .output+4, '5'
	TEST_MEMORY_BYTE .output+5, 0

 TC_END
.output:	defb 0,0,0,0,0,0


    ENDMODULE
