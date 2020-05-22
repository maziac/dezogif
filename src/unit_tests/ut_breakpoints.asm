;========================================================
; ut_breakpoints.asm
;
; Unit tests for testing the breakpoints.
;========================================================


    MODULE ut_breakpoints

; Test value
breakpoint_test_address:	defb  0


; Test first entry.
UT_get_free_breakpoint.UT_simple:
    ; Init
	call clear_breakpoints

	; Test
	call get_free_breakpoint

	; Test memory
	TEST_DREG hl, breakpoint_list
    ret 


; Test a few entries.
UT_get_free_breakpoint.UT_few_entries:
    ; Init
	call clear_breakpoints

	; Test
	call get_free_breakpoint
	TEST_DREG hl, breakpoint_list
	MEMFILL breakpoint_list, 0x55, BREAKPOINT

	call get_free_breakpoint
	TEST_DREG hl, breakpoint_list+1*BREAKPOINT
	MEMFILL breakpoint_list, 0x55, 2*BREAKPOINT

	call get_free_breakpoint
	TEST_DREG hl, breakpoint_list+2*BREAKPOINT
    ret 


; Test too many entries.
UT_get_free_breakpoint.UT_too_many_entries:
    ; Init
	call clear_breakpoints
	; Prepare, fill complete list
	MEMFILL breakpoint_list, 0x55, BREAKPOINT_LIST_COUNT*BREAKPOINT

	; Test
	call get_free_breakpoint
	TEST_FLAG_NZ
    ret 





; Test no breakpoint.
UT_find_breakpoint.UT_simple:
    ; Init
	call clear_breakpoints

	; Test
	ld hl,breakpoint_test_address
	call find_breakpoint
	TEST_FLAG_NZ
    ret 


; Test to find the bp at the first location.
UT_find_breakpoint.UT_find_first_entry:
    ; Init
	call clear_breakpoints
	; Prepare
	ld de,breakpoint_test_address
	ld hl,breakpoint_list+BREAKPOINT.address
	ld (hl),de

	; Test
	ld hl,breakpoint_test_address
	call find_breakpoint
	TEST_FLAG_Z
	TEST_DREG hl,breakpoint_list
    ret 


; Test to find the bp at some location.
UT_find_breakpoint.UT_some_entry:
    ; Init
	call clear_breakpoints
	; Prepare
	ld de,breakpoint_test_address
	ld hl,breakpoint_list+3*BREAKPOINT+BREAKPOINT.address
	ld (hl),de

	; Test
	ld hl,breakpoint_test_address
	call find_breakpoint
	TEST_FLAG_Z
	TEST_DREG hl,breakpoint_list+3*BREAKPOINT
    ret 

; Test to find the bp at teh last location.
UT_find_breakpoint.UT_last_entry:
    ; Init
	MEMFILL breakpoint_list, 0xAA, BREAKPOINT_LIST_COUNT*BREAKPOINT
	; Prepare
	ld de,breakpoint_test_address
	ld hl,breakpoint_list+(BREAKPOINT_LIST_COUNT-1)*BREAKPOINT+BREAKPOINT.address
	ld (hl),de

	; Test
	ld hl,breakpoint_test_address
	call find_breakpoint
	TEST_FLAG_Z
	TEST_DREG hl,breakpoint_list+(BREAKPOINT_LIST_COUNT-1)*BREAKPOINT
    ret 



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
	TEST_MEMORY_BYTE breakpoint_test_address, BP_INSTRUCTION
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




; Tests removing a simple entry.
UT_remove_breakpoint.UT_simple:
    ; Init
	call clear_breakpoints
	; Prepare
	ld hl,breakpoint_test_address
	ld (hl),0xA5
	ld hl, breakpoint_test_address
	call add_breakpoint

	; Test
	ld hl,breakpoint_test_address
	call remove_breakpoint
	
	; Test memory
	TEST_MEMORY_WORD breakpoint_list+BREAKPOINT.address, 0
	TEST_MEMORY_BYTE breakpoint_list+BREAKPOINT.instruction_length, 0
	TEST_MEMORY_BYTE breakpoint_list+BREAKPOINT.opcode, 0
	TEST_MEMORY_BYTE breakpoint_test_address, 0xA5
    ret 


; Tests removing an entry in the middle.
UT_remove_breakpoint.UT_middle:
    ; Init
	call clear_breakpoints
	; Prepare
	MEMFILL breakpoint_list, 0xAA, 3*BREAKPOINT
	ld de,breakpoint_test_address
	ld hl,breakpoint_list+BREAKPOINT+BREAKPOINT.address 
	ld (hl),de

	; Test
	ld hl,breakpoint_test_address
	call remove_breakpoint
	
	; Test memory
	TEST_MEMORY_WORD breakpoint_list+BREAKPOINT+BREAKPOINT.address, 0
	TEST_MEMORY_BYTE breakpoint_list+BREAKPOINT+BREAKPOINT.instruction_length, 0
	TEST_MEMORY_BYTE breakpoint_list+BREAKPOINT+BREAKPOINT.opcode, 0
	TEST_MEMORY_BYTE breakpoint_test_address, 0xAA
    ret 



; Tests the instruction length calculation of 1 byte instructions.
UT_get_instruction_length.UT_1byte_instruction:
	; Test
	ld hl,.test_code
	ld b,.test_code_end-.test_code
.loop:
	push hl, bc
	call get_instruction_length
	TEST_A 1
	pop bc, hl 
	inc hl
	djnz .loop
    ret

; Some 1 byte instructions for testing.
.test_code:
	ld a,c
	ld a,b
	nop 
	ld c,a
	inc a
	inc d
	dec e
	sub a
	or l
.test_code_end


; Tests the instruction length calculation of 2 byte instructions.
UT_get_instruction_length.UT_2byte_instruction:
	; Test
	ld hl,.test_code
	ld b,(.test_code_end-.test_code)/2
.loop:
	push hl, bc
	call get_instruction_length
	TEST_A 2
	pop bc, hl 
	inc hl : inc hl
	djnz .loop
    ret

; Some 2 byte instructions for testing.
.test_code:
	ld a,6
	ld c,9
	or 9
	neg
	in (c)
.test_code_end


; Tests the instruction length calculation of 3 byte instructions.
UT_get_instruction_length.UT_3byte_instruction:
	; Test
	ld hl,.test_code
	ld b,(.test_code_end-.test_code)/3
.loop:
	push hl, bc
	call get_instruction_length
	TEST_A 3
	pop bc, hl 
	inc hl : inc hl : inc hl
	djnz .loop
    ret

; Some 2 byte instructions for testing.
.test_code:
	ld ixl,6
	ld iyh,19
.test_code_end

    ENDMODULE
    