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

test_memory_write_bank:
.bank:	
	defb 0	; Bank
.end:
	defb 0	; WPMEM

test_memory_write_mem:
	defb 0	; Reserved
.address:	
	defw 0  ; Address
.values:
	defb 0, 0, 0	; Values
.end:
	defb 0	; WPMEM

test_memory_output:	defs 40
	defb 0 	; WPMEM


; Helper function that inits all backup values to 0xFF.
cmd_data_init:
	ld hl,backup
	ld de,backup+1
	ld (hl),0xFF
	ld bc,backup_top-backup-1
	ldir
	ret 


; Helper function to redirect the uart input/output.
redirect_uart:
	; Also redirect read_uart_byte function call
	ld hl,read_uart_byte
	ldi (hl),0xC3	; JP
	ldi (hl),redirected_read_uart_byte&0xFF
	ld (hl),redirected_read_uart_byte>>8
.common:
	; Redirect write_uart_byte function call
	ld hl,write_uart_byte
	ldi (hl),0xC3	; JP
	ldi (hl),redirected_write_uart_byte&0xFF
	ld (hl),redirected_write_uart_byte>>8
	ret


; Helper function to redirect the uart input/output.
redirect_uart_write_bank:
	; Also redirect read_uart_byte function call
	ld hl,read_uart_byte
	ldi (hl),0xC3	; JP
	ldi (hl),redirected_read_uart_byte_bank&0xFF
	ld (hl),redirected_read_uart_byte_bank>>8
	jr redirect_uart.common


; Return values read from (iy)
redirected_read_uart_byte:
	ld e,0
	ld bc,PORT_UART_TX
	ld a,(iy)
	inc iy
	ret


; Return same values.
redirected_read_uart_byte_bank:
	ld e,0
	ld bc,PORT_UART_TX
.bank:	equ $+1
	ld a,0	; is overwritten
	ld bc,.second
	ld (read_uart_byte+1),bc
	ret
.second:
	ld e,0
	ld bc,PORT_UART_TX
.fill_data:	equ $+1
	ld a,0	; is overwritten
	ret


; Simulated write_uart_byte.
; Write at ix.
redirected_write_uart_byte:
	ld (ix),a
	inc ix
	ret


; Test response of cmd_init.
UT_1_cmd_init:
	; Redirect
	call redirect_uart

	; Prepare
	ld hl,5+.cmd_data_end-.cmd_data
	ld (receive_buffer.length),hl

	; Test
	ld iy,.cmd_data
	ld ix,test_memory_output
	call cmd_init

	; Test length
	TEST_MEMORY_WORD test_memory_output, 5+PROGRAM_NAME.end-DZRP_VERSION
	TEST_MEMORY_WORD test_memory_output+2, 0

	; Test error
	TEST_MEMORY_BYTE test_memory_output+5, 0	; no error
	
	; Test DZRP version
	TEST_MEM_CMP test_memory_output+6, DZRP_VERSION, 3

	; Test program name
	TEST_STRING_PTR test_memory_output+6+3, PROGRAM_NAME
	
	ret

.cmd_data:
	defb 1, 2, 3	; Version 1.2.3
	defb "host_program", 0	; Remote program name
.cmd_data_end


; Test cmd_get_registers.
UT_2_cmd_get_registers:	
	; Redirect
	call redirect_uart

	; Prepare
	ld hl,2
	ld (receive_buffer.length),hl

	; Copy data
	MEMCOPY backup, .cmd_data, .cmd_data_end-.cmd_data
	; Test
	ld iy,.cmd_data
	ld ix,test_memory_output
	call cmd_get_registers

	; Test length
	TEST_MEMORY_WORD test_memory_output, 29
	TEST_MEMORY_WORD test_memory_output+2, 0

	; Test returned data
	TEST_MEM_CMP test_memory_output+5, .cmp_data, .cmp_data_end-.cmp_data

	ret

.cmd_data:	; WPMEM, 28, W
	defw 1001, 1002, 1003, 1004, 1005, 1006, 1007
	defw 2001, 2002, 2003, 2004, 2005, 2006, 2007
.cmd_data_end
.cmp_data:	; Order is vice versa
	defw 2007, 2006, 2005, 2004, 2003, 2002, 2001
	defw 1007, 1006, 1005, 1004, 1003, 1002, 1001
.cmp_data_end


; Test that register is set correctly.
UT_3_cmd_set_register.UT_pc:
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
    call cmd_set_register.inner

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
    call cmd_set_register.inner
    ret 



; Test that register SP to HL' are set correctly.
UT_3_cmd_set_register.UT_SP_to_HL2:
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
    call cmd_set_register.inner
	; Set second byte
	pop af
	pop hl
	ld l,h
	ld h,0x55  ; should not be used
	ld (payload_set_reg.register_value),hl	; value
	inc a
	ld (payload_set_reg.register_number),a	; register number
    ; Set first byte
    call cmd_set_register.inner
    ret 


; Test that register A to H' are set correctly.
UT_3_cmd_set_register.UT_A_to_IR:
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
UT_3_cmd_set_register.UT_im:
	ld a,13	; IM register
	ld (payload_set_reg.register_number),a
	; IM 0
	ld hl,0
	ld (payload_set_reg.register_value),hl	; value
	call cmd_set_register.inner
	; IM 1
	ld hl,1
	ld (payload_set_reg.register_value),hl	; value
	call cmd_set_register.inner
	; IM 2
	ld hl,2
	ld (payload_set_reg.register_value),hl	; value
	call cmd_set_register.inner
	; Wrong mode
	ld hl,3
	ld (payload_set_reg.register_value),hl	; value
	call cmd_set_register.inner
	ret


; Test writing a wrong register index.
; The check is simply that no crash happens.
UT_3_cmd_set_register.UT_wrong_register:
	ld a,35	; First non existing register
	ld (payload_set_reg.register_number),a
	ld hl,0xCC55
	ld (payload_set_reg.register_value),hl	; value
	call cmd_set_register.inner
	ld a,0xFF	; Last non existing register
	ld (payload_set_reg.register_number),a
	ld hl,0xCC55
	ld (payload_set_reg.register_value),hl	; value
	call cmd_set_register.inner
	ret





; Test writing data to a memory bank.
; The test simulates the receive_bytes function call.
UT_4_cmd_write_bank:
	; Remember current bank for slot
	ld a,REG_MMU+SWAP_SLOT0
	call read_tbblue_reg	; Result in A
	push af	; remember

	; Redirect
	call redirect_uart_write_bank

	; Set bank to use
	ld a,28
	ld (redirected_read_uart_byte_bank.bank),a

	; Set fill byte
	ld a,0x55
	ld (redirected_read_uart_byte_bank.fill_data),a

	; Test A
	ld iy,test_memory_write_bank
	ld ix,test_memory_output
	call cmd_write_bank

	; Check that slot/bank has been restored
	ld a,REG_MMU+SWAP_SLOT0
	call read_tbblue_reg	; Result in A
	pop de		; Get original bank in D 
	push de
	TEST_A D

	; Page in the memory bank
;.slot:	equ ((cmd_write_bank+2*0x2000)>>13)&0x07
	nextreg REG_MMU+SWAP_SLOT0,28
	
	ld hl,SWAP_SLOT0*0x2000	; .slot<<13	; Start address
	ld a,(hl)
	TEST_A 0x55
	add hl,0x2000-1
	ld a,(hl)
	TEST_A 0x55
	

	; Redirect again
	call redirect_uart_write_bank

	; Set fill byte
	ld a,0xAA
	ld (redirected_read_uart_byte_bank.fill_data),a

	; Test A
	ld iy,test_memory_write_bank
	ld ix,test_memory_output
	call cmd_write_bank

	; Page in the memory bank
	nextreg REG_MMU+SWAP_SLOT0,28
	
	ld hl,SWAP_SLOT0*0x2000	;.slot<<13	; Start address
	ld a,(hl)
	TEST_A 0xAA
	add hl,0x2000-1
	ld a,(hl)
	TEST_A 0xAA
	

	; Restore slot/bank (D)
	pop de
	;ld a,.slot+REG_MMU
	;call write_tbblue_reg	; A=register, D=value
	WRITE_TBBLUE_REG REG_MMU+SWAP_SLOT0,d
	ret


; Test cmd_continue
UT_5_continue:

	; Redirect
	call redirect_uart

	; Prepare
	;ld hl,5+.cmd_data_end-.cmd_data
	ld (receive_buffer.length),hl

	; Test
	;ld iy,.cmd_data
	ld ix,test_memory_output
	call cmd_init

	; Test length
	TEST_MEMORY_WORD test_memory_output, 5+PROGRAM_NAME.end-DZRP_VERSION
	TEST_MEMORY_WORD test_memory_output+2, 0

	ret


; Test cmd_pause
UT_6_pause:
	TEST_FAIL
	ret


; Test reading memory.
UT_7_cmd_read_mem.UT_normal:
	; Redirect
	call redirect_uart

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


; Test reading memory in each relevant bank.
; Note: The locations should not contain any code/data of
; the tested program which is around 0x7000 for unit testing.
UT_7_cmd_read_mem.UT_banks:
	; Page in different bank in ROM area 
	nextreg REG_MMU+0,80	; Bank 80
	nextreg REG_MMU+1,81	; Bank 81

	; Redirect
	call redirect_uart

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
UT_8_cmd_write_mem.UT_normal:
	; Redirect
	call redirect_uart

	; Prepare
	ld hl,5+3
	ld (receive_buffer.length),hl

	; Test
	ld hl,test_memory_dst
	ld (test_memory_write_mem.address),hl
	ld iy,test_memory_write_mem.values
	ld (iy),0xD1
	ld (iy+1),0xD2
	ld (iy+2),0xD3
	ld iy,test_memory_write_mem
	ld ix,test_memory_output
	call cmd_write_mem

	TEST_MEMORY_BYTE test_memory_dst, 0xD1
	TEST_MEMORY_BYTE test_memory_dst+1, 0xD2
	TEST_MEMORY_BYTE test_memory_dst+2, 0xD3
	ret
	
	

; Test writing memory in each relevant bank.
; Note: The locations should not contain any code/data of
; the tested program which is around 0x7000 for unit testing.
UT_8_cmd_write_mem.UT_banks:
	; Page in different bank in ROM area 
	nextreg REG_MMU+0,80	; Bank 80
	nextreg REG_MMU+1,81	; Bank 81

	; Redirect
	call redirect_uart

	; Prepare
	ld hl,5+1
	ld (receive_buffer.length),hl
	
	; Location 0x1FFF
	ld hl,test_memory_write_mem.address
	ld de,0x1FFF
	ldi (hl),de
	ld hl,test_memory_write_mem.values
	ld (hl),0xB1
	ld iy,test_memory_write_mem
	ld ix,test_memory_output
	call cmd_write_mem
	TEST_MEMORY_BYTE 0x1FFF,0xB1

	; Location 0x2000
	ld hl,test_memory_write_mem.address
	ld de,0x2000
	ldi (hl),de
	ld hl,test_memory_write_mem.values
	ld (hl),0xB2
	ld iy,test_memory_write_mem
	ld ix,test_memory_output
	call cmd_write_mem
	TEST_MEMORY_BYTE 0x2000,0xB2

	; Location 0x3FFF
	ld hl,test_memory_write_mem.address
	ld de,0x3FFF
	ldi (hl),de
	ld hl,test_memory_write_mem.values
	ld (hl),0xB3
	ld iy,test_memory_write_mem
	ld ix,test_memory_output
	call cmd_write_mem
	TEST_MEMORY_BYTE 0x3FFF,0xB3

	; Location 0x4000
	ld hl,test_memory_write_mem.address
	ld de,0x4000
	ldi (hl),de
	ld hl,test_memory_write_mem.values
	ld (hl),0xB4
	ld iy,test_memory_write_mem
	ld ix,test_memory_output
	call cmd_write_mem
	TEST_MEMORY_BYTE 0x4000,0xB4

	; Location 0x5123
	ld hl,test_memory_write_mem.address
	ld de,0x5123
	ldi (hl),de
	ld hl,test_memory_write_mem.values
	ld (hl),0xB5
	ld iy,test_memory_write_mem
	ld ix,test_memory_output
	call cmd_write_mem
	TEST_MEMORY_BYTE 0x5123,0xB5

	; Location 0xFFFF
	ld hl,test_memory_write_mem.address
	ld de,0xFFFF
	ldi (hl),de
	ld hl,test_memory_write_mem.values
	ld (hl),0xB6
	ld iy,test_memory_write_mem
	ld ix,test_memory_output
	call cmd_write_mem
	TEST_MEMORY_BYTE 0xFFFF,0xB6

	; Cleanup
	nextreg REG_MMU+0,ROM_BANK
	nextreg REG_MMU+1,ROM_BANK
	ret


; Test retrieving the slot/bank association.
; Note: This will also fail if some other test that changes the default
; slot/bank association fails.
UT_9_cmd_get_slots:
	; Set standard config
	nextreg REG_MMU, ROM_BANK
	nextreg REG_MMU+1, ROM_BANK
	nextreg REG_MMU+2, 10
	nextreg REG_MMU+3, 11
	nextreg REG_MMU+4, 4
	nextreg REG_MMU+5, 5
	nextreg REG_MMU+6, 0
	nextreg REG_MMU+7, 1
	; Redirect
	call redirect_uart

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
	

; Test cmd_set_slot
UT_10_set_slot:
	TEST_FAIL
	ret


; Test cmd_get_tbblue_reg
UT_11_cmd_get_tbblue_reg:
	TEST_FAIL
	ret


; Test cmd_set_border
UT_12_cmd_set_border:
	TEST_FAIL
	ret


; Test cmd_set_breakpoints
UT_13_cmd_set_breakpoints:
	TEST_FAIL
	ret


; Test cmd_restore_mem
UT_14_cmd_restore_mem:
	TEST_FAIL
	ret


; Test cmd_get_sprites_palette
UT_15_cmd_get_sprites_palette:
	TEST_FAIL
	ret


; Test cmd_get_sprites_clip_window_and_control
UT_16_cmd_get_sprites_clip_window_and_control:
	TEST_FAIL
	ret


    ENDMODULE
    