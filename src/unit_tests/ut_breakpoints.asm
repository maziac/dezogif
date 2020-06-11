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
 TC_END


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
 TC_END


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
 TC_END


; Test not setting a breakpoint position.
UT_set_tmp_breakpoint.UT_not_set_bp:
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
 TC_END


; Test setting a breakpoint position.
UT_set_tmp_breakpoint.UT_set_bp:
   ; Init
    MEMCLEAR tmp_breakpoint_1, 2*TMP_BREAKPOINT
    ld hl,testdata1
    ld (hl),0xFF
    ld de,tmp_breakpoint_1

    ; TEST
    call set_tmp_breakpoint

    TEST_MEMORY_BYTE testdata1, BP_INSTRUCTION
    TEST_MEMORY_BYTE tmp_breakpoint_1.opcode, 0xFF
    TEST_MEMORY_WORD tmp_breakpoint_1.bp_address, testdata1
 TC_END



; Test check address for tmp breakpoint.
; No breakpoint found.
UT_check_tmp_breakpoints.UT_no_bp:
   ; Init
    MEMCLEAR tmp_breakpoint_1, 2*TMP_BREAKPOINT
    ld hl,testdata1
    ld (tmp_breakpoint_1.bp_address),hl
    ld (tmp_breakpoint_2.bp_address),hl
    inc hl
    ex de,hl    ; de = bp address, does not match

    ; TEST
    call check_tmp_breakpoints

    TEST_FLAG_NZ
 TC_END


; Test check address for tmp breakpoint.
; First breakpoint found.
UT_check_tmp_breakpoints.UT_first_bp:
   ; Init
    MEMCLEAR tmp_breakpoint_1, 2*TMP_BREAKPOINT
    ld hl,testdata1
    ld (tmp_breakpoint_1.bp_address),hl
    inc hl
    ld (tmp_breakpoint_2.bp_address),hl
    dec hl
    ex de,hl    ; de = bp address, matches first

    ; TEST
    call check_tmp_breakpoints

    TEST_FLAG_Z
 TC_END


; Test check address for tmp breakpoint.
; Second breakpoint found.
UT_check_tmp_breakpoints.UT_second_bp:
   ; Init
    MEMCLEAR tmp_breakpoint_1, 2*TMP_BREAKPOINT
    ld hl,testdata1
    inc hl
    ld (tmp_breakpoint_1.bp_address),hl
    dec hl
    ld (tmp_breakpoint_2.bp_address),hl
    ex de,hl    ; de = bp address, matches second

    ; TEST
    call check_tmp_breakpoints

    TEST_FLAG_Z
 TC_END
    

    ENDMODULE
    