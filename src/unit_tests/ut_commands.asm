;========================================================
; ut_commands.asm
;
; Unit tests for the different UART commands.
;========================================================


    MODULE ut_commands


; Data area for testing
test_stack:		defw 0
	
	defb 0	; WPMEM
test_memory_src:	defb 1, 2, 3, 4, 5, 6, 7, 8
test_memory_src_end:
	defb 0	; WPMEM

test_memory_dst:	defb 0, 0, 0, 0, 0, 0, 0, 0
test_memory_dst_end:
	defb 0	; WPMEM

; Helper function that inits all backup values to 0xFF.
cmd_data_init:
	ld hl,backup
	ld de,backup+1
	ld (hl),0xFF
	ld bc,backup_top-backup-1
	ldir
	ret 


; Test that register is set correctly.
UT_cmd_write_reg.UT_pc:
	; Init values
	call cmd_data_init
    ; Init
	ld hl,test_stack
	ld (backup.sp),hl
	ld hl,0x1112
	ld (payload_set_reg.register_value),hl
	ld a,0	; PC
	ld (payload_set_reg.register_number),a
	
    ; Test
    call cmd_set_reg.inner

	ld hl,(backup.pc)
	TEST_DREG hl, 0x1112

    ret 


; Helper function to set a double register.
; A = register number
; HL = value
cmd_set_dreg:
    ; Init
	ld (payload_set_reg.register_value),hl	; value
	ld (payload_set_reg.register_number),a	; register number
    ; set
    call cmd_set_reg.inner
    ret 


; Test that register SP to HL' are set correctly.
UT_cmd_write_reg.UT_SP_to_HL2:
	; Init values
	call cmd_data_init
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
set_reg:
    ; Init
	push hl
	push af
	ld h,0x55  ; should not be used
	ld (payload_set_reg.register_value),hl	; value
	ld (payload_set_reg.register_number),a	; register number
    ; Set first byte
    call cmd_set_reg.inner
	; Set second byte
	pop af
	pop hl
	ld l,h
	ld h,0x55  ; should not be used
	ld (payload_set_reg.register_value),hl	; value
	inc a
	ld (payload_set_reg.register_number),a	; register number
    ; Set first byte
    call cmd_set_reg.inner
    ret 


; Test that register A to H' are set correctly.
UT_cmd_write_reg.UT_A_to_IR:
	; Init values
	call cmd_data_init
	; First set all single registers
    ; AF
	ld hl,0x1A1F
	ld a,14	; AF
	call set_reg
    ; BC
	ld hl,0x1B1C
	ld a,16	; BC
	call set_reg
    ; DE
	ld hl,0x1D1E
	ld a,18	; DE
	call set_reg
    ; HL
	ld hl,0x1112
	ld a,20	; HL
	call set_reg
    ; IX
	ld hl,0x1314
	ld a,22	; IX
	call set_reg
    ; IY
	ld hl,0x1516
	ld a,24	; IY
	call set_reg
    ; AF2
	ld hl,0x2A2F
	ld a,26	; AF2
	call set_reg
     ; BC2
	ld hl,0x2B2C
	ld a,28	; BC2
	call set_reg
    ; DE2
	ld hl,0x2D2E
	ld a,30	; DE2
	call set_reg
    ; HL2
	ld hl,0x2122
	ld a,32	; HL2
	call set_reg
    ; IR
	ld hl,0x9876
	ld a,34	; R
	call set_reg

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
	TEST_MEMORY_BYTE backup.r, 0x76
	TEST_MEMORY_BYTE backup.i, 0x98
	ret



; Test setting of interrupt modes.
; A real check is not possible, IM cannot be read.
; The check only allows a visual check that all lines have been covered.
UT_cmd_write_reg.UT_im:
	ld a,13	; IM register
	ld (payload_set_reg.register_number),a
	; IM 0
	ld hl,0
	ld (payload_set_reg.register_value),hl	; value
	call cmd_set_reg.inner
	; IM 1
	ld hl,1
	ld (payload_set_reg.register_value),hl	; value
	call cmd_set_reg.inner
	; IM 2
	ld hl,2
	ld (payload_set_reg.register_value),hl	; value
	call cmd_set_reg.inner
	; Wrong mode
	ld hl,3
	ld (payload_set_reg.register_value),hl	; value
	call cmd_set_reg.inner
	ret


; Test writing a wrong register index.
; The check is simply that no crash happens.
UT_cmd_write_reg.UT_wrong_register:
	ld a,35	; First non existing register
	ld (payload_set_reg.register_number),a
	ld hl,0xCC55
	ld (payload_set_reg.register_value),hl	; value
	call cmd_set_reg.inner
	ld a,0xFF	; Last non existing register
	ld (payload_set_reg.register_number),a
	ld hl,0xCC55
	ld (payload_set_reg.register_value),hl	; value
	call cmd_set_reg.inner
	ret





; Test writing data to a memory bank.
; The test simulates the receive_bytes function call.
UT_cmd_write_bank:
	; Remember current bank for slot
	ld a,.slot+REG_MMU
	call read_tbblue_reg	; Result in A
	push af	; remember

	; Redirect receive_bytes funtion call
	ld hl,receive_bytes
	ldi (hl),0xC3	; JP
	ldi (hl),redirected_receive_bytes&0xFF
	ld (hl),redirected_receive_bytes>>8

	; Set bank to use
	ld a,28
	ld (payload_write_bank.bank_number),a 


	; Set fill byte
	ld a,0x55
	ld (redirected_receive_bytes.fill_data),a

	; Test A
	call cmd_write_bank.inner

	; Check that slot/bank has been restored
	ld a,.slot+REG_MMU
	call read_tbblue_reg	; Result in A
	pop de		; Get original bank in D 
	push de
	TEST_A D

	; Page in the memory bank
.slot:	equ ((cmd_write_bank+2*0x2000)>>13)&0x07
	nextreg .slot+REG_MMU,28
	
	ld hl,.slot<<13	; Start address
	ld a,(hl)
	TEST_A 0x55
	add hl,0x2000-1
	ld a,(hl)
	TEST_A 0x55
	

	; Set fill byte
	ld a,0xAA
	ld (redirected_receive_bytes.fill_data),a

	; Test A
	call cmd_write_bank.inner

	; Page in the memory bank
	nextreg .slot+REG_MMU,28
	
	ld hl,.slot<<13	; Start address
	ld a,(hl)
	TEST_A 0xAA
	add hl,0x2000-1
	ld a,(hl)
	TEST_A 0xAA
	

	; Restore slot/bank (D)
	pop de
	;ld a,.slot+REG_MMU
	;call write_tbblue_reg	; A=register, D=value
	WRITE_TBBLUE_REG .slot+REG_MMU,d
	ret

; Simulated receive bytes.
; Writes a fix value into bank.
redirected_receive_bytes:
	push af
.loop:
.fill_data:	equ $+1
	ld (hl),0
	inc hl
	dec de
	ld a,e
	or d
	jr nz,.loop
	pop af
	ret



; Test reading memory.
UT_cmd_read_mem.UT_normal:
	; Redirect write_uart_byte function call
	ld hl,write_uart_byte
	ldi (hl),0xC3	; JP
	ldi (hl),redirected_write_uart_byte&0xFF
	ld (hl),redirected_write_uart_byte>>8

	; Pointer to write to
	ld ix,test_memory_dst

	; Test
	ld hl,test_memory_src
	ld (payload_read_mem.mem_start),hl
	ld hl,test_memory_src_end-test_memory_src
	ld (payload_read_mem.mem_size),hl
	call cmd_read_mem.inner

	; Compare src against dst
	ld hl,test_memory_src
	ld de,test_memory_dst
	ld b,test_memory_src_end-test_memory_src
.loop:
	ldi a,(de)
	TEST_A (HL)
	inc hl
	djnz .loop

	ret

; Simulated write_uart_byte.
redirected_write_uart_byte:
	ld (ix),a
	inc ix
	ret


; Test reading memory in each relevant bank.
; Note: The locations should not contain any code/data of
; the tested program which is around 0x7000 for unit testing.
UT_cmd_read_mem.UT_banks:
	; Page in different bank in ROM area 
	nextreg REG_MMU+0,80	; Bank 80
	nextreg REG_MMU+1,81	; Bank 81

	; Redirect write_uart_byte function call
	ld hl,write_uart_byte
	ldi (hl),0xC3	; JP
	ldi (hl),redirected_write_uart_byte&0xFF
	ld (hl),redirected_write_uart_byte>>8

	; Test
	ld hl,1
	ld (payload_read_mem.mem_size),hl
	
	; Location 0x1FFF
	ld ix,test_memory_dst	; Pointer to write to
	ld hl,0x1FFF
	ld (hl),0xA1
	ld (payload_read_mem.mem_start),hl
	call cmd_read_mem.inner
	TEST_MEMORY_BYTE test_memory_dst,0xA1

	; Location 0x2000
	ld ix,test_memory_dst	; Pointer to write to
	ld hl,0x2000
	ld (hl),0xA2
	ld (payload_read_mem.mem_start),hl
	call cmd_read_mem.inner
	TEST_MEMORY_BYTE test_memory_dst,0xA2

	; Location 0x3FFF
	ld ix,test_memory_dst	; Pointer to write to
	ld hl,0x3FFF
	ld (hl),0xA3
	ld (payload_read_mem.mem_start),hl
	call cmd_read_mem.inner
	TEST_MEMORY_BYTE test_memory_dst,0xA3

	; Location 0x4000
	ld ix,test_memory_dst	; Pointer to write to
	ld hl,0x4000
	ld (hl),0xA4
	ld (payload_read_mem.mem_start),hl
	call cmd_read_mem.inner
	TEST_MEMORY_BYTE test_memory_dst,0xA4

	; Location 0x5123
	ld ix,test_memory_dst	; Pointer to write to
	ld hl,0x5123
	ld (hl),0xA5
	ld (payload_read_mem.mem_start),hl
	call cmd_read_mem.inner
	TEST_MEMORY_BYTE test_memory_dst,0xA5

	; Location 0xFFFF
	ld ix,test_memory_dst	; Pointer to write to
	ld hl,0xFFFF
	ld (hl),0xA6
	ld (payload_read_mem.mem_start),hl
	call cmd_read_mem.inner
	TEST_MEMORY_BYTE test_memory_dst,0xA6

	; Cleanup
	nextreg REG_MMU+0,ROM_BANK
	nextreg REG_MMU+1,ROM_BANK
	ret


; Test writing memory.
UT_cmd_write_mem:
	; Redirect receive_bytes funtion call
	ld hl,receive_bytes
	ldi (hl),0xC3	; JP
	ldi (hl),redirected_receive_bytes&0xFF
	ld (hl),redirected_receive_bytes>>8

	; Set fill byte
	ld a,0x5C
	ld (redirected_receive_bytes.fill_data),a

	; Test
	ld hl,test_memory_dst
	ld (payload_write_mem.mem_start),hl
	ld hl,test_memory_dst_end-test_memory_dst+5
	ld (receive_buffer.length),hl
	call cmd_write_mem.inner

	TEST_MEMORY_BYTE test_memory_dst, 0x5C
	TEST_MEMORY_BYTE test_memory_dst_end-1, 0x5C
	
	ret
	

; Test retrieving the slot/bank association.
; Note: This will also fail if some other test that changes the default
; slot/bank association fails.
UT_cmd_get_slots:
	; Redirect write_uart_byte funtion call
	ld hl,write_uart_byte
	ldi (hl),0xC3	; JP
	ldi (hl),redirected_write_uart_byte&0xFF
	ld (hl),redirected_write_uart_byte>>8

	; Pointer to write to
	ld ix,test_memory_dst

	; Test
	call cmd_get_slots.inner

	; Compare with standard slots
	TEST_MEMORY_BYTE test_memory_dst, 	0xFF	; ROM
	TEST_MEMORY_BYTE test_memory_dst+1, 0xFF	; ROM
	TEST_MEMORY_BYTE test_memory_dst+2, 10
	TEST_MEMORY_BYTE test_memory_dst+3, 11
	TEST_MEMORY_BYTE test_memory_dst+4, 4
	TEST_MEMORY_BYTE test_memory_dst+5, 5
	TEST_MEMORY_BYTE test_memory_dst+6, 0
	TEST_MEMORY_BYTE test_memory_dst+7, 1

	ret
	

    ENDMODULE
    