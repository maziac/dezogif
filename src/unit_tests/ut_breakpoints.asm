;========================================================
; ut_breakpoints.asm
;
; Unit tests for testing the breakpoints.
;========================================================


    MODULE ut_breakpoints

; Test value
breakpoint_test_address:	defb  0


; Test a simple entry.
UT_add_breakpoint.UT_simple:
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


; Tests filling all entries.
UT_add_breakpoint.UT_fill_list:
    ; Init
	call clear_breakpoints
	ld hl,breakpoint_test_address
	ld (hl),0xA5

	; Test
	ld b,BREAKPOINT_LIST_COUNT
.loop:
	push bc
	ld hl, breakpoint_test_address
	call add_breakpoint
	TEST_FLAG_Z
	pop bc 
	djnz .loop
	
	; Test one more, should not work
	ld hl, breakpoint_test_address
	call add_breakpoint
	TEST_FLAG_NZ
    ret 


    ENDMODULE
    