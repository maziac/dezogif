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

test_memory_write_mem:
	defb 0	; Reserved
.address:	
	defw 0  ; Address
.values:
	defb 0, 0, 0	; Values
.end:
	defb 0	; WPMEM

test_memory_output:	defs 1024
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
	call cmd_init.inner

	; Test special first byte
	TEST_MEMORY_BYTE test_memory_output, MESSAGE_START_BYTE

	; Test length
	TEST_MEMORY_WORD test_memory_output+1, 5+PROGRAM_NAME.end-PROGRAM_NAME
	TEST_MEMORY_WORD test_memory_output+2, 0

	; Test error
	TEST_MEMORY_BYTE test_memory_output+6, 0	; no error
	
	; Test DZRP version
	TEST_MEM_CMP test_memory_output+7, DZRP_VERSION, 3

	; Test program name
	TEST_STRING_PTR test_memory_output+7+3, PROGRAM_NAME
 TC_END

.cmd_data:
	defb 1, 2, 3	; Version 1.2.3
	defb "host_program", 0	; Remote program name
.cmd_data_end


; Test response of cmd_close.
UT_2_cmd_close:
	; Redirect
	call redirect_uart

	; Test
	ld iy,0	; not used
	ld ix,test_memory_output
	call cmd_close

	; Test length
	TEST_MEMORY_WORD test_memory_output+1, 1
	TEST_MEMORY_WORD test_memory_output+3, 0
 TC_END

; cmd_close jumps here:
@main:
	ret

; Test cmd_get_registers.
UT_3_cmd_get_registers:	
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
	TEST_MEMORY_WORD test_memory_output+1, 29
	TEST_MEMORY_WORD test_memory_output+3, 0

	; Test returned data
	TEST_MEM_CMP test_memory_output+6, .cmp_data, .cmp_data_end-.cmp_data

 TC_END

.cmd_data:	; WPMEM, 28, W
	defw 1001, 1002, 1003, 1004, 1005, 1006, 1007
	defw 2001, 2002, 2003, 2004, 2005, 2006, 2007
.cmd_data_end
.cmp_data:	; Order is vice versa
	defw 2007, 2006, 2005, 2004, 2003, 2002, 2001
	defw 1007, 1006, 1005, 1004, 1003, 1002, 1001
.cmp_data_end


; Test that register is set correctly.
UT_4_cmd_set_register.UT_pc:
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

 TC_END


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
UT_4_cmd_set_register.UT_SP_to_HL2:
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
 TC_END


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
UT_4_cmd_set_register.UT_A_to_IR:
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
 TC_END



; Test setting of interrupt modes.
; A real check is not possible, IM cannot be read.
; The check only allows a visual check that all lines have been covered.
UT_4_cmd_set_register.UT_im:
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
 TC_END


; Test writing a wrong register index.
; The check is simply that no crash happens.
UT_4_cmd_set_register.UT_wrong_register:
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
 TC_END


; Test writing data to a memory bank.
; The test simulates the receive_bytes function call.
UT_5_cmd_write_bank:
	; Remember current bank for slot
	ld a,REG_MMU+SWAP_SLOT
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
	ld ix,test_memory_output
	call cmd_write_bank

	; Check that slot/bank has been restored
	ld a,REG_MMU+SWAP_SLOT
	call read_tbblue_reg	; Result in A
	pop de		; Get original bank in D 
	push de
	TEST_A d

	; Page in the memory bank
	nextreg REG_MMU+SWAP_SLOT,28
	
	ld hl,SWAP_ADDR	; .slot<<13	; Start address
	ld a,(hl)
	TEST_A 0x55
	add hl,0x2000-1
	ld a,(hl)
	TEST_A 0x55
	

	; Redirect
	call redirect_uart_write_bank

	; Set fill byte
	ld a,0xAA
	ld (redirected_read_uart_byte_bank.fill_data),a

	; Test A
	ld ix,test_memory_output
	call cmd_write_bank

	; Page in the memory bank
	nextreg REG_MMU+SWAP_SLOT,28
	
	ld hl,SWAP_ADDR	;.slot<<13	; Start address
	ld a,(hl)
	TEST_A 0xAA
	add hl,0x2000-1
	ld a,(hl)
	TEST_A 0xAA
	

	; Restore slot/bank (D)
	pop de
	;ld a,.slot+REG_MMU
	;call write_tbblue_reg	; A=register, D=value
	WRITE_TBBLUE_REG REG_MMU+SWAP_SLOT,d
 TC_END


; Test cmd_continue
UT_6_continue:
	; Redirect
	call redirect_uart
	; Redirect "return"
	ld a,0xC3	; JP
	ld (restore_registers.ret_jump1),a
	ld hl,.exit_code
	ld (restore_registers.ret_jump1+1),hl
	
	; Prepare
	ld hl,2+PAYLOAD_CONTINUE
	ld (receive_buffer.length),hl

	; Return
    ld hl,.continue     ; The jump address
    ld (backup.pc),hl   ; Continue at return address
    ld (backup.sp),sp

	; Test
	ld iy,.cmd_data
	ld ix,test_memory_output
	call cmd_continue
.continue:

	; Test length
	TEST_MEMORY_WORD test_memory_output+1, 1
	TEST_MEMORY_WORD test_memory_output+3, 0

 TC_END

.cmd_data:	PAYLOAD_CONTINUE 0, 0, 0, 0

.exit_code:
	pop af
	ret 


; Test cmd_pause
UT_7_pause:
	; Redirect
	call redirect_uart
	; Prepare
	ld hl,2
	ld (receive_buffer.length),hl

	; Change jump into ret
	ld a,0xC9	; RET
	ld (cmd_pause.jump),a

	; Test
	ld iy,0		; Not used
	ld ix,test_memory_output
	call cmd_pause

	; Test start byte
	TEST_MEMORY_BYTE test_memory_output, 	MESSAGE_START_BYTE
	; Test length
	TEST_MEMORY_WORD test_memory_output+1, 	1
	TEST_MEMORY_WORD test_memory_output+3, 	0

	; Afterwards the notification is written
	; Length
	TEST_MEMORY_BYTE test_memory_output+6, 	MESSAGE_START_BYTE
	TEST_MEMORY_WORD test_memory_output+7, 	6
	TEST_MEMORY_WORD test_memory_output+9, 	0
	TEST_MEMORY_BYTE test_memory_output+11, 	0
	TEST_MEMORY_BYTE test_memory_output+12, 	1	; NTF_PAUSE
	TEST_MEMORY_BYTE test_memory_output+13, BREAK_REASON.MANUAL_BREAK	; Break reason
	TEST_MEMORY_WORD test_memory_output+14,	0	; BP address
	TEST_MEMORY_BYTE test_memory_output+16, 0	; No error text
 TC_END


; Test reading memory.
UT_8_cmd_read_mem.UT_normal:
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
 TC_END


; Test reading memory in each relevant bank.
; Note: The locations should not contain any code/data.
UT_8_cmd_read_mem.UT_banks:
	; Page in different memory to ROM
	nextreg REG_MMU,81
	nextreg REG_MMU+1,82

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

	; Location 0xC000
	ld ix,test_memory_dst	; Pointer to write to
	ld hl,0xC000
	ld (hl),0xA6
	ld (payload_read_mem.mem_start),hl
	call cmd_read_mem.inner
	TEST_MEMORY_BYTE test_memory_dst,0xA6

	; Location 0xFFFF
	ld ix,test_memory_dst	; Pointer to write to
	ld hl,0xFFFF
	; Page in different bank in slot 7 area 
	ld a,80
	ld (slot_backup.slot7),a
	nextreg REG_MMU+MAIN_SLOT,a
	; Write
	ld (hl),0xA7
	; Restore bank
	nextreg REG_MMU+MAIN_SLOT,LOADED_BANK

	ld (payload_read_mem.mem_start),hl
	call cmd_read_mem.inner
	TEST_MEMORY_BYTE test_memory_dst,0xA7

	; Test that slots are restored
	ld a,REG_MMU
	call read_tbblue_reg
	TEST_A 81
	ld a,REG_MMU+1
	call read_tbblue_reg
	TEST_A 82
 TC_END


; Test writing memory.
UT_9_cmd_write_mem.UT_normal:
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

	TEST_MEMORY_BYTE test_memory_dst,   0xD1
	TEST_MEMORY_BYTE test_memory_dst+1, 0xD2
	TEST_MEMORY_BYTE test_memory_dst+2, 0xD3
 TC_END
	

; Test writing memory in each relevant bank.
; Note: The locations should not contain any code/data of
; the tested program which is around 0x7000 for unit testing.
UT_9_cmd_write_mem.UT_banks:
	; Page in different memory to ROM
	nextreg REG_MMU,81
	nextreg REG_MMU+1,82

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

	; Location 0xC000
	ld hl,test_memory_write_mem.address
	ld de,0xC000
	ldi (hl),de
	ld hl,test_memory_write_mem.values
	ld (hl),0xB6
	ld iy,test_memory_write_mem
	ld ix,test_memory_output
	call cmd_write_mem
	TEST_MEMORY_BYTE 0xC000,0xB6

	; Location 0xFFFF
	ld hl,test_memory_write_mem.address
	ld de,0xFFFF
	ldi (hl),de
	ld hl,test_memory_write_mem.values
	ld (hl),0xB7
	ld iy,test_memory_write_mem
	ld ix,test_memory_output
	ld a,80
	ld (slot_backup.slot7),a
	call cmd_write_mem

	nextreg REG_MMU+MAIN_SLOT,80
	TEST_MEMORY_BYTE 0xFFFF,0xB7

	; Restore
	nextreg REG_MMU+MAIN_SLOT,LOADED_BANK
 TC_END


; Test retrieving the slot/bank association.
; Note: This will also fail if some other test that changes the default
; slot/bank association fails.
UT_10_cmd_get_slots:
	; Redirect
	call redirect_uart

	; Set standard config
	nextreg REG_MMU, ROM_BANK
	nextreg REG_MMU+1, ROM_BANK
	nextreg REG_MMU+2, 10
	nextreg REG_MMU+3, 11
	nextreg REG_MMU+4, 4
	nextreg REG_MMU+5, 5
	nextreg REG_MMU+6, 0
	ld a,70
	ld (slot_backup.slot7),a
	; Redirect
	call redirect_uart

	; Test
	ld ix,test_memory_output
	call cmd_get_slots

	; Check length
	TEST_MEMORY_WORD test_memory_output+1, 	9
	TEST_MEMORY_WORD test_memory_output+3,	0	
	; Compare with standard slots
	TEST_MEMORY_BYTE test_memory_output+6, 0xFF	; ROM
	TEST_MEMORY_BYTE test_memory_output+7, 0xFF	; ROM
	TEST_MEMORY_BYTE test_memory_output+8, 10
	TEST_MEMORY_BYTE test_memory_output+9, 11
	TEST_MEMORY_BYTE test_memory_output+10, 4
	TEST_MEMORY_BYTE test_memory_output+11, 5
	TEST_MEMORY_BYTE test_memory_output+12, 0
	TEST_MEMORY_BYTE test_memory_output+13, 70
 TC_END


; Test cmd_set_slot
UT_11_set_slot:
	; Redirect
	call redirect_uart
	; Prepare
	ld hl,4
	ld (receive_buffer.length),hl

	; Test
	ld iy,.cmd_data
	ld (iy),SWAP_SLOT
	ld (iy+1),75
	ld ix,test_memory_output
	call cmd_set_slot
	; Check bank
	ld a,REG_MMU+SWAP_SLOT
	call read_tbblue_reg
	TEST_A	75
	; Check length
	TEST_MEMORY_WORD test_memory_output+1, 	2
	TEST_MEMORY_WORD test_memory_output+3,	0	

	; Test
	ld iy,.cmd_data
	ld (iy+1),76
	ld ix,test_memory_output
	call cmd_set_slot
	; Check bank
	ld a,REG_MMU+SWAP_SLOT
	call read_tbblue_reg
	TEST_A	76

	; Test
	ld iy,.cmd_data
	ld (iy),MAIN_SLOT
	ld (iy+1),70
	ld ix,test_memory_output
	call cmd_set_slot
	; Check bank
	TEST_MEMORY_BYTE slot_backup.slot7, 70

	; Test ROM in slot 0
	ld iy,.cmd_data
	ld (iy),0
	ld (iy+1),0xFE
	ld ix,test_memory_output
	call cmd_set_slot
	; Check bank
	ld a,REG_MMU+0
	call read_tbblue_reg
	TEST_A	ROM_BANK	
	
	; Test ROM in slot 0
	ld iy,.cmd_data
	ld (iy),0
	ld (iy+1),0xFF
	ld ix,test_memory_output
	call cmd_set_slot
	; Check bank
	ld a,REG_MMU+0
	call read_tbblue_reg
	TEST_A	ROM_BANK
 TC_END

.cmd_data:	defb 0
.bank:		defb 0



; Test cmd_get_tbblue_reg.
; Check a set slot.
UT_12_cmd_get_tbblue_reg:
	; Redirect
	call redirect_uart
	; Prepare
	ld hl,4
	ld (receive_buffer.length),hl

	; Test
	nextreg REG_MMU+SWAP_SLOT, 74
	ld iy,.cmd_data
	ld ix,test_memory_output
	call cmd_get_tbblue_reg

	; Check result
	TEST_MEMORY_WORD test_memory_output+1, 2
	TEST_MEMORY_WORD test_memory_output+3, 0
	TEST_MEMORY_BYTE test_memory_output+6, 74

	; Test
	nextreg REG_MMU+SWAP_SLOT, 73
	ld iy,.cmd_data
	ld ix,test_memory_output
	call cmd_get_tbblue_reg

	; Check result
	TEST_MEMORY_WORD test_memory_output+1, 2
	TEST_MEMORY_WORD test_memory_output+3, 0
	TEST_MEMORY_BYTE test_memory_output+6, 73
 TC_END

.cmd_data:	defb REG_MMU+SWAP_SLOT


; Test cmd_set_border. Test works only on zsim.
UT_13_cmd_set_border:
	; Redirect
	call redirect_uart
	; Prepare
	ld hl,4
	ld (receive_buffer.length),hl

	; Test
	ld iy,.cmd_data
	ld (iy),CYAN
	ld ix,test_memory_output
	call cmd_set_border

	; Check length
	TEST_MEMORY_WORD test_memory_output+1, 1
	TEST_MEMORY_WORD test_memory_output+3, 0

	; Check result - Only works for zsim
	ld a,CYAN ; Required for zsim as it decodes the full 16 bit IO address
	in a,(BORDER)
	and 0x07
	TEST_A CYAN

	; Test
	ld iy,.cmd_data
	ld (iy),BLACK
	ld ix,test_memory_output
	call cmd_set_border

	; Check result
	ld a,BLACK ; Required for zsim as it decodes the full 16 bit IO address
	in a,(BORDER)
	TEST_A BLACK
 TC_END

.cmd_data:	defb 0


; Test cmd_set_breakpoints with no breakpoints.
UT_14_cmd_set_breakpoints.UT_no_bp:
	; Redirect
	call redirect_uart
	; Prepare
	ld hl,2
	ld (receive_buffer.length),hl

	; Test
	ld iy,0		; Not used
	ld ix,test_memory_output
	call cmd_set_breakpoints

	; Check length
	TEST_MEMORY_WORD test_memory_output+1,	1
	TEST_MEMORY_WORD test_memory_output+3,	0
 TC_END


; Test cmd_set_breakpoints.
; 2 breakpoints.
UT_14_cmd_set_breakpoints.UT_2_bps:
	; Redirect
	call redirect_uart
	; Prepare
	ld hl,2+2*2
	ld (receive_buffer.length),hl

	; Test
	xor a
	ld (0xC000),a
	ld (0xC0FF),a
	ld iy,.cmd_data
	ld ix,test_memory_output
	call cmd_set_breakpoints

	; Check length
	TEST_MEMORY_WORD test_memory_output+1, 	1+2
	TEST_MEMORY_WORD test_memory_output+3,	0

	; Test
	TEST_MEMORY_BYTE 0xC000, BP_INSTRUCTION
	TEST_MEMORY_BYTE 0xC0FF, BP_INSTRUCTION
 TC_END

.cmd_data:	defw 0xC000, 0xC0FF


; Test cmd_set_breakpoints.
; Restore slots.
UT_14_cmd_set_breakpoints.UT_restore_slots:
	; Redirect
	call redirect_uart
	; Prepare
	ld hl,2+2*2
	ld (receive_buffer.length),hl

	; Page in banks in ROM area
	ld a,70
	nextreg REG_MMU+0,a
	ld (slot_backup.slot0),a
	nextreg REG_MMU+1,71
	nextreg REG_MMU+SWAP_SLOT,72

	; Test
	xor a
	ld (0x0200),a
	ld (0x3FFF),a
	ld iy,.cmd_data
	ld ix,test_memory_output
	call cmd_set_breakpoints

	; Check length
	TEST_MEMORY_WORD test_memory_output+1, 	1+2
	TEST_MEMORY_WORD test_memory_output+3,	0

	; Test that slots are restored
	ld a,REG_MMU
	call read_tbblue_reg
	TEST_A 70
	ld a,REG_MMU+1
	call read_tbblue_reg
	TEST_A 71
	ld a,REG_MMU+SWAP_SLOT
	call read_tbblue_reg
	TEST_A 72

	TEST_MEMORY_BYTE 0x0200, BP_INSTRUCTION
	TEST_MEMORY_BYTE 0x3FFF, BP_INSTRUCTION
 TC_END

.cmd_data:	defw 0x0200, 0x3FFF


; Test cmd_restore_mem with no values.
UT_15_cmd_restore_mem.UT_no_values:
	; Redirect
	call redirect_uart
	; Prepare
	ld hl,2
	ld (receive_buffer.length),hl

	; Test
	ld iy,0		; Not used
	ld ix,test_memory_output
	call cmd_restore_mem

	; Check length
	TEST_MEMORY_WORD test_memory_output+1,	1
	TEST_MEMORY_WORD test_memory_output+3,	0
 TC_END


; Test cmd_restore_mem.
; 2 values.
UT_15_cmd_restore_mem.UT_2_values:
	; Redirect
	call redirect_uart
	; Prepare
	ld hl,2+2*3
	ld (receive_buffer.length),hl

	; Test
	ld a,0xFF
	ld (0xC000),a
	ld (0xC0FF),a
	ld iy,.cmd_data
	ld ix,test_memory_output
	call cmd_restore_mem

	; Check length
	TEST_MEMORY_WORD test_memory_output+1, 	1
	TEST_MEMORY_WORD test_memory_output+3,	0

	; Test
	TEST_MEMORY_BYTE 0xC000, 0xAA
	TEST_MEMORY_BYTE 0xC0FF, 0x55
 TC_END

.cmd_data:	
	defw 0xC000
	defb 0xAA
	defw 0xC0FF
	defb 0x55


; Test cmd_restore_mem.
; Restore slots.
UT_15_cmd_restore_mem.UT_restore_slots:
	; Redirect
	call redirect_uart
	; Prepare
	ld hl,2+2*3
	ld (receive_buffer.length),hl

	; Page in banks in ROM area
	ld a,70
	nextreg REG_MMU+0,a
	ld (slot_backup.slot0),a
	nextreg REG_MMU+1,71
	nextreg REG_MMU+SWAP_SLOT,72

	; Test
	ld a,0xFF
	ld (0x0200),a
	ld (0x3FFF),a
	ld iy,.cmd_data
	ld ix,test_memory_output
	call cmd_restore_mem

	; Check length
	TEST_MEMORY_WORD test_memory_output+1, 	1
	TEST_MEMORY_WORD test_memory_output+3,	0

	; Test that slots are restored
	ld a,REG_MMU
	call read_tbblue_reg
	TEST_A 70
	ld a,REG_MMU+1
	call read_tbblue_reg
	TEST_A 71
	ld a,REG_MMU+SWAP_SLOT
	call read_tbblue_reg
	TEST_A 72

	TEST_MEMORY_BYTE 0x0200, 0xA5
	TEST_MEMORY_BYTE 0x3FFF, 0x5A
 TC_END

.cmd_data:
	defw 0x0200
	defb 0xA5
	defw 0x3FFF
	defb 0x5A



; Test cmd_loopback.
; Test looping back received data.
UT_16_cmd_loopback:
	; Redirect
	call redirect_uart
	; Prepare
	ld hl,2+30
	ld (receive_buffer.length),hl

	; Test
	nextreg REG_MMU+SWAP_SLOT, 69
	ld iy,.cmd_data
	ld ix,test_memory_output
	call cmd_loopback

	; Test that slot was restored
	ld a,REG_MMU+SWAP_SLOT
	call read_tbblue_reg
	TEST_A 69

	; Check length
	TEST_MEMORY_WORD test_memory_output+1, 	1+30
	TEST_MEMORY_WORD test_memory_output+3,	0
	; Check all value
	TEST_MEM_CMP test_memory_output+6, .cmd_data, .cmd_data_end-.cmd_data
 TC_END

.cmd_data:	defb 0, 1, 2, 3, 4, 5, 6, 7, 8, 9
	defb 10, 11, 21, 13, 14, 15, 16, 17, 18, 19
	defb 20, 21, 22, 23, 24, 25, 26, 27, 28, 29
.cmd_data_end


; Test cmd_get_sprites_palette.
; Test that 513 bytes are send for both palettes.
UT_17_cmd_get_sprites_palette:
	; Redirect
	call redirect_uart
	; Prepare
	ld hl,3
	ld (receive_buffer.length),hl

	; Test
	xor a	; Palette 0
	ld (.cmd_data),a
	ld iy,.cmd_data
	ld ix,test_memory_output
	call cmd_get_sprites_palette

	; Check length
	TEST_MEMORY_WORD test_memory_output+1, 	513
	TEST_MEMORY_WORD test_memory_output+3,	0
	; Note: the values itself are not checked.

	; Test
	ld a,1	; Palette 1
	ld (.cmd_data),a
	ld iy,.cmd_data
	ld ix,test_memory_output
	call cmd_get_sprites_palette:

	; Check length
	TEST_MEMORY_WORD test_memory_output+1, 	513
	TEST_MEMORY_WORD test_memory_output+3,	0
	; Note: the values itself are not checked.
 TC_END

.cmd_data:	defb 0	; palette index


; Test cmd_get_sprites_clip_window_and_control
UT_18_cmd_get_sprites_clip_window_and_control:
	; Redirect
	call redirect_uart
	; Prepare
	ld hl,2
	ld (receive_buffer.length),hl

	/* No zsim support for nextreg
	; Set clip window
    nextreg REG_CLIP_WINDOW_CONTROL, 2
	nextreg REG_CLIP_WINDOW_SPRITES, 55		; xl
	nextreg REG_CLIP_WINDOW_SPRITES, 100	; xr
	nextreg REG_CLIP_WINDOW_SPRITES, 20		; yt
	nextreg REG_CLIP_WINDOW_SPRITES, 200	; yb
	; Write a 5th time
	nextreg REG_CLIP_WINDOW_SPRITES, 10		; xl again

	
    ld a,2 : nextreg 25, a		; 0
    ld a,200 : nextreg 25, a	; 1
    ld a,3 : nextreg 25, a		; 2
    ld a,100 : nextreg 25, a	; 3
	; Write a 5th time
	ld a,4 : nextreg 25, a		; 0
	*/

	; Test
	ld iy,0	; Not used
	ld ix,test_memory_output
	call cmd_get_sprites_clip_window_and_control

	; Check length
	TEST_MEMORY_WORD test_memory_output+1, 	6
	TEST_MEMORY_WORD test_memory_output+3,	0
	
	/*
	; Check clipping values
	TEST_MEMORY_WORD test_memory_output+5,	10		; xl
	TEST_MEMORY_WORD test_memory_output+6,	100		; xr
	TEST_MEMORY_WORD test_memory_output+7,	20		; yt
	TEST_MEMORY_WORD test_memory_output+8,	200		; yb
	*/
 TC_END


    ENDMODULE
    