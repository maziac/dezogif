;========================================================
; ut_commands.asm
;
; Unit tests for the different UART commands.
;========================================================


    MODULE ut_commands

; Data area for testing
test_stack:	defw 0


; Test that register is set correctly.
cmd_read_regs.UT_pc:
    ; Init
	ld hl,test_stack
	ld (backup.sp),hl
	ld hl,0x1112
	ld (receive_buffer.register_value),hl
	ld a,0	; PC
	ld (receive_buffer.register_number),a
	
    ; Test
    call cmd_write_reg.test

	ld hl,(backup.sp)
	ldi a,(hl)
	ld h,(hl)
	ld l,a
	TEST_DREG hl, 0x1112

    ret 



    ENDMODULE
    