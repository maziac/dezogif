;========================================================
; ut_breakpoints.asm
;
; Unit tests for testing the breakpoints.
;========================================================


    MODULE ut_breakpoints

; Test value
;breakpoint_test_address:	defb  0

testdata1:  defb 0
testdata2:  defb 0


; Test with no temp bp.
UT_clear_tmp_breakpoints.UT_simple:
    ; Init
    ld hl,0
    ld (tmp_breakpoint_1.bp_address),hl
    ld (tmp_breakpoint_2.bp_address),hl
    ld a,0xFF
    ld (tmp_breakpoint_1.opcode),a
    ld (tmp_breakpoint_2.opcode),a

	; Test 
    call clear_tmp_breakpoints

    TEST_MEMORY_BYTE tmp_breakpoint_1.opcode, 0
    TEST_MEMORY_WORD tmp_breakpoint_1.bp_address, 0
    TEST_MEMORY_BYTE tmp_breakpoint_2.opcode, 0
    TEST_MEMORY_WORD tmp_breakpoint_2.bp_address, 0
    ret 


; Test clearing first temporary breakpoint.
UT_clear_tmp_breakpoints.UT_first:
    ; Init
    ld a,0xF0
    ld (testdata2),a    ; not used
    ld hl,testdata1
    ld (hl),0xC7
    ld (tmp_breakpoint_1.bp_address),hl
    ld hl,0
    ld (tmp_breakpoint_2.bp_address),hl
    ld a,0xAA
    ld (tmp_breakpoint_1.opcode),a
    ld a,0x55
    ld (tmp_breakpoint_2.opcode),a  ; not used

	; Test 
    call clear_tmp_breakpoints

    TEST_MEMORY_BYTE tmp_breakpoint_1.opcode, 0
    TEST_MEMORY_WORD tmp_breakpoint_1.bp_address, 0
    TEST_MEMORY_BYTE tmp_breakpoint_2.opcode, 0
    TEST_MEMORY_WORD tmp_breakpoint_2.bp_address, 0

    TEST_MEMORY_BYTE testdata1, 0xAA
    TEST_MEMORY_BYTE testdata2, 0xF0
    ret 


; Test clearing second temporary breakpoint.
UT_clear_tmp_breakpoints.UT_second:
    ; Init
    ld a,0xF0
    ld (testdata1),a    ; not used
    ld hl,testdata2
    ld (hl),0xC7
    ld (tmp_breakpoint_2.bp_address),hl
    ld hl,0
    ld (tmp_breakpoint_1.bp_address),hl
    ld a,0xAA
    ld (tmp_breakpoint_2.opcode),a
    ld a,0x55
    ld (tmp_breakpoint_1.opcode),a  ; not used

	; Test 
    call clear_tmp_breakpoints

    TEST_MEMORY_BYTE tmp_breakpoint_1.opcode, 0
    TEST_MEMORY_WORD tmp_breakpoint_1.bp_address, 0
    TEST_MEMORY_BYTE tmp_breakpoint_2.opcode, 0
    TEST_MEMORY_WORD tmp_breakpoint_2.bp_address, 0

    TEST_MEMORY_BYTE testdata2, 0xAA
    TEST_MEMORY_BYTE testdata1, 0xF0
    ret 


; Test not setting a a breakpoint position.
UT_set_tmp_breakpoint.UT_few_entries:
    ; Init
    MEMCLEAR tmp_breakpoint_1, 2*TMP_BREAKPOINT
    ld hl,testdata1
    ld (hl),BP_INSTRUCTION
    ld de,tmp_breakpoint_1

    ; TEST
    call set_tmp_breakpoint

    TEST_MEMORY_BYTE testdata1, BP_INSTRUCTION
    TEST_MEMORY_BYTE tmp_breakpoint_1.opcode, 0
    TEST_MEMORY_WORD tmp_breakpoint_1.bp_address, 0
    ret 


; Test too many entries.
UT_get_free_breakpoint.UT_too_many_entries:
    ; Init
    ret 





; Test no breakpoint.
UT_find_breakpoint.UT_simple:
    ; Init
	
    ret 


; Test to find the bp at the first location.
UT_find_breakpoint.UT_find_first_entry:
    ; Init
    ret 


; Test to find the bp at some location.
UT_find_breakpoint.UT_some_entry:
    ; Init
    ret 

; Test to find the bp at teh last location.
UT_find_breakpoint.UT_last_entry:
    ; Init
    ret 



    ENDMODULE
    