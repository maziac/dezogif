;========================================================
; ut_breakpoints.asm
;
; Unit tests for testing the breakpoints.
;========================================================


    MODULE ut_breakpoints

; Test value
breakpoint_test_address:	defb  0

; Test that subroutine returns correctly.
UT_add_breakpoint:
    ; Init
	call clear_breakpoints
	ld hl,breakpoint_test_address
	ld (hl),0xA5

	; Test
	ld hl, breakpoint_test_address
	call add_breakpoint

	TEST_FLAG_Z

	; Test memory
	TEST_MEMORY_WORD breakpoint_list+BREAKPOINT.address, breakpoint_test_address
	TEST_MEMORY_BYTE breakpoint_list+BREAKPOINT.opcode, 0xA5
    ret 


    ENDMODULE
    