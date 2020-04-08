;========================================================
; ut_commands.asm
;
; Unit tests for the different UART commands.
;========================================================


    MODULE ut_commands

; Data area for testing
test_stack:	defw 0


; Helper function that inits all backup values to 0xFF.
cmd_init:
	ld hl,backup
	ld de,backup+1
	ld (hl),0xFF
	ld bc,backup_top-backup-1
	ldir
	ret 


; Test that register is set correctly.
cmd_read_regs.UT_pc:
	; Init values
	call cmd_init
    ; Init
	ld hl,test_stack
	ld (backup.sp),hl
	ld hl,0x1112
	ld (receive_buffer.register_value),hl
	ld a,0	; PC
	ld (receive_buffer.register_number),a
	
    ; Test
    call cmd_write_reg.inner

	ld hl,(backup.sp)
	ldi a,(hl)
	ld h,(hl)
	ld l,a
	TEST_DREG hl, 0x1112

    ret 


; Helper function to set a double register.
; A = register number
; HL = value
cmd_set_dreg:
    ; Init
	ld (receive_buffer.register_value),hl	; value
	ld (receive_buffer.register_number),a	; register number
    ; set
    call cmd_write_reg.inner
    ret 


; Test that register SP to HL' are set correctly.
cmd_read_regs.UT_SP_to_HL2:
	; Init values
	call cmd_init
	; First set all double registers
    ; SP
	ld hl,0x1819
	ld a,1	; SP
	call cmd_set_dreg
    ; AF
	ld hl,0x1A1F
	ld a,2	; AF
	call cmd_set_dreg
    ; BC
	ld hl,0x1B1C
	ld a,3	; BC
	call cmd_set_dreg
    ; DE
	ld hl,0x1D1E
	ld a,4	; DE
	call cmd_set_dreg
    ; HL
	ld hl,0x1112
	ld a,5	; HL
	call cmd_set_dreg
    ; IX
	ld hl,0x1314
	ld a,6	; IX
	call cmd_set_dreg
    ; IY
	ld hl,0x1516
	ld a,7	; IY
	call cmd_set_dreg
    ; AF2
	ld hl,0x2A2F
	ld a,8	; AF2
	call cmd_set_dreg
     ; BC2
	ld hl,0x2B2C
	ld a,9	; BC2
	call cmd_set_dreg
    ; DE2
	ld hl,0x2D2E
	ld a,10	; DE2
	call cmd_set_dreg
    ; HL2
	ld hl,0x2122
	ld a,11	; HL2
	call cmd_set_dreg

	; Then test the contents to see that nothing has been overwritten
	TEST_MEMORY_WORD backup.sp, 0x1819
	TEST_MEMORY_WORD backup.af, 0x1A1F
	TEST_MEMORY_WORD backup.bc, 0x1B1C
	TEST_MEMORY_WORD backup.de, 0x1D1E
	TEST_MEMORY_WORD backup.hl, 0x1112
	TEST_MEMORY_WORD backup.ix, 0x1314
	TEST_MEMORY_WORD backup.iy, 0x1516
	TEST_MEMORY_WORD backup.af2, 0x2A2F
	TEST_MEMORY_WORD backup.bc2, 0x2B2C
	TEST_MEMORY_WORD backup.de2, 0x2D2E
	TEST_MEMORY_WORD backup.hl2, 0x2122
	ret


; Helper function to set a single register.
; A = register number
; L = value
cmd_set_reg:
    ; Init
	push hl
	push af
	ld h,0x55  ; should not be used
	ld (receive_buffer.register_value),hl	; value
	ld (receive_buffer.register_number),a	; register number
    ; Set first byte
    call cmd_write_reg.inner
	; Set second byte
	pop af
	pop hl
	ld l,h
	ld h,0x55  ; should not be used
	ld (receive_buffer.register_value),hl	; value
	inc a
	ld (receive_buffer.register_number),a	; register number
    ; Set first byte
    call cmd_write_reg.inner
    ret 


; Test that register A to H' are set correctly.
cmd_read_regs.UT_A_to_H2:
	; Init values
	call cmd_init
	; First set all single registers
    ; AF
	ld hl,0x1A1F
	ld a,15	; AF
	call cmd_set_reg
    ; BC
	ld hl,0x1B1C
	ld a,17	; BC
	call cmd_set_reg
    ; DE
	ld hl,0x1D1E
	ld a,19	; DE
	call cmd_set_reg
    ; HL
	ld hl,0x1112
	ld a,21	; HL
	call cmd_set_reg
    ; IX
	ld hl,0x1314
	ld a,23	; IX
	call cmd_set_reg
    ; IY
	ld hl,0x1516
	ld a,25	; IY
	call cmd_set_reg
    ; AF2
	ld hl,0x2A2F
	ld a,27	; AF2
	call cmd_set_reg
     ; BC2
	ld hl,0x2B2C
	ld a,29	; BC2
	call cmd_set_reg
    ; DE2
	ld hl,0x2D2E
	ld a,31	; DE2
	call cmd_set_reg
    ; HL2
	ld hl,0x2122
	ld a,33	; HL2
	call cmd_set_reg

	; Then test the contents to see that nothing has been overwritten
	TEST_MEMORY_WORD backup.af, 0x1A1F
	TEST_MEMORY_WORD backup.bc, 0x1B1C
	TEST_MEMORY_WORD backup.de, 0x1D1E
	TEST_MEMORY_WORD backup.hl, 0x1112
	TEST_MEMORY_WORD backup.ix, 0x1314
	TEST_MEMORY_WORD backup.iy, 0x1516
	TEST_MEMORY_WORD backup.af2, 0x2A2F
	TEST_MEMORY_WORD backup.bc2, 0x2B2C
	TEST_MEMORY_WORD backup.de2, 0x2D2E
	TEST_MEMORY_WORD backup.hl2, 0x2122
	ret



; Test setting of interrupt modes.
; A real check is not possible, IM cannot be read.
; The check only allows a visual check that all lines have been covered.
cmd_read_regs.UT_im:
	ld a,13	; IM register
	ld (receive_buffer.register_number),a
	; IM 0
	ld hl,0
	ld (receive_buffer.register_value),hl	; value
	call cmd_write_reg.inner
	; IM 1
	ld hl,1
	ld (receive_buffer.register_value),hl	; value
	call cmd_write_reg.inner
	; IM 2
	ld hl,2
	ld (receive_buffer.register_value),hl	; value
	call cmd_write_reg.inner
	; Wrong mode
	ld hl,3
	ld (receive_buffer.register_value),hl	; value
	call cmd_write_reg.inner
	ret


; Test writing a wrong register index.
; The check is simply that no crash happens.
cmd_read_regs.UT_wrong_register:
	ld a,35	; First non existing register
	ld (receive_buffer.register_number),a
	ld hl,0xCC55
	ld (receive_buffer.register_value),hl	; value
	call cmd_write_reg.inner
	ld a,0xFF	; Last non existing register
	ld (receive_buffer.register_number),a
	ld hl,0xCC55
	ld (receive_buffer.register_value),hl	; value
	call cmd_write_reg.inner
	ret


    ENDMODULE
    