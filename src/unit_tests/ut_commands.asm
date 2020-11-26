;========================================================
; ut_commands.asm
;
; Unit tests for the different UART commands.
;========================================================


    MODULE ut_commands


; Data area for testing
test_stack:		defw 0

	defb 0	; WPMEM

test_memory_write_mem:
	defb 0	; Reserved
.address:
	defw 0  ; Address
.values:
	defb 0, 0, 0	; Values
.end:
	defb 0	; WPMEM


; TODO: REMOVE: test_memory_output
test_memory_output:
test_memory_payload:
	defs 1024
.end
	defb 0 	; WPMEM
.length:
	defw 0


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


; Writes test data to simulated UART buffer.
; HL = pointer to data (payload)
; DE = Length of data (payload)
; Changes:
; AF, BC, DE, HL
; Notes:
; - Port 0 is used to prepare the data that is later read through PORT_UART_RX.
; - For the tests the length, the command and the seq no is not written to
; the UART simulation. But all the rest.
test_prepare_command:
	call test_prepare_header
	; Note: storing command information is not necessary
	;add de,-(4+1+1)	; Correct the length
	; Store custom data
	ld bc,0	; Port 0 is to prepare the data that is later read through PORT_UART_RX
.loop:
	ld a,d
	or e
	ret z
	ldi a,(hl)
	out (c),a
	dec de
	jr .loop

test_prepare_header:
	;Reset error
    xor a
    ld (last_error),a
	; Write length
;	add de,4+1+1	; Length + command + seq no
	; Store length
	ld (receive_buffer.length),de
	ld (receive_buffer.length+2),a	; a = 0
	ld (receive_buffer.length+3),a
	; Store seq_no
	ld a,100
	ld (receive_buffer.seq_no),a
	ret


; Reads the response from the simulated UART.
; Note:
; Reading port 0x0001 reads data that was prior written to the PORT_UART_TX.
; Reading port 0x0002 reads the length of the remaining data in PORT_UART_TX.
test_get_response:
	; First test for error
    TEST_MEMORY_BYTE last_error, 0
	; Clear mem
	MEMFILL test_memory_payload, 0xFF, test_memory_payload.end-test_memory_payload
	ld hl,0xFFFF
	ld (test_memory_payload.length),hl
	; Length
	ld bc,0x0002	; Port for length
	in a,(c)	; Read length low byte
	ld e,a
	inc bc
	in a,(c)	; Read length high byte
	ld d,a
	dec de		; Skip A5
	; Check length, should be greater than payload
	ld hl,de
	or a
	ld de,4	; Header (just the length)
	sbc hl,de
	jp nc,.length_ok
	; Length smaller than payload
	TEST_FAIL
.length_ok:
	; Read A5
	ld bc,0x0001	; Port 0x0001 for reading the TX data
	in a,(c)
	TEST_A	MESSAGE_START_BYTE	; Is sent as start byte always
	; Read written length -> DE
	in a,(c) : ld e,a
	in a,(c) : ld d,a
	; Store length
	ld (test_memory_payload.length),de
	or a
	sbc hl,de
	TEST_FLAG_Z		; Fail if lengths not equal. Inconsistency: more written than length.
	; HL > 0: Too many bytes written to UART. HL < 0: Too less bytes written.
	; The higher bytes of the length should be 0
	in a,(c)
	TEST_A 0
	in a,(c)
	TEST_A 0
	; The seq_no is 100
	in a,(c)
	TEST_A 100
	; Read payload data from TX buffer
	ld hl,test_memory_payload
.loop:
	ldi (hl),a
	; Decrement the sequence number
	dec de
	ld a,d
	or e
	ret z
	in a,(c)
	jr .loop

; For easier calling:
	MACRO TEST_PREPARE_COMMAND
	ld hl,.cmd_data
	ld de,.cmd_data_end-.cmd_data	; Length
	call test_prepare_command
	ENDM

; Simulates an empty command.
	MACRO TEST_EMPTY_COMMAND:
	ld de,0
	call test_prepare_command
	ENDM

; Test response of cmd_init.
UT_1_cmd_init:
	; Write test data to simulated UART buffer.
	TEST_PREPARE_COMMAND

	; Test
	call cmd_init.inner

	; Read response
	call test_get_response

	; Test size
	TEST_MEMORY_WORD test_memory_payload.length, PROGRAM_NAME.end-PROGRAM_NAME +1 +5

	; Test error
	TEST_MEMORY_BYTE test_memory_payload+1, 0	; no error

	; Test DZRP version
	TEST_MEMORY_BYTE test_memory_payload+2, DZRP_VERSION.MAJOR
	TEST_MEMORY_BYTE test_memory_payload+3, DZRP_VERSION.MINOR
	TEST_MEMORY_BYTE test_memory_payload+3, DZRP_VERSION.PATCH

	; Test machine type: 4 = ZX Next
	TEST_MEMORY_BYTE test_memory_output+5, 4

	; Test program name
	TEST_STRING_PTR test_memory_output+6, PROGRAM_NAME
 TC_END

.cmd_data:
	defb 1, 2, 3	; Version 1.2.3
	defb "host_program", 0	; Remote program name
.cmd_data_end


; Test response of cmd_close.
UT_2_cmd_close:
	; Write test data to simulated UART buffer.
	TEST_EMPTY_COMMAND

	; Test
	call cmd_close

	; Get response
	call test_get_response

	; Test size
	TEST_MEMORY_WORD test_memory_payload.length, 1

	; Test is done already inside test_get_response

 TC_END

; cmd_close jumps here:
@main:
	ret

; Test cmd_get_registers.
UT_3_cmd_get_registers:
	; Write test data to simulated UART buffer.
	TEST_EMPTY_COMMAND

	; Save current slot configuration
	; Save the first 7 slots
	ld d,REG_MMU
	ld e,7
	ld hl,.cmp_slots
.loop:
	; Get bank for slot
	ld a,d
	call read_tbblue_reg	; Result in A
	; Store for later comparison
	ldi (hl),a
	inc d
	dec e
	jr nz,.loop
	; Last slot
	ld a,(slot_backup.slot7)
	ld (.cmp_slots+7),a

	; Copy data
	MEMCOPY backup, .cmd_data, .cmd_data_end-.cmd_data

	; Test
	call cmd_get_registers

	; Get response
	call test_get_response

	; Test size
	TEST_MEMORY_WORD test_memory_payload.length, 38

	; Test returned data
	TEST_MEM_CMP test_memory_output+1, .cmp_data, .cmp_data_end-.cmp_data

	; Test slots
	TEST_MEMORY_BYTE test_memory_output+29, 8	; 8 slots
	TEST_MEM_CMP test_memory_output+30, .cmp_slots, 8

 TC_END

.cmd_data:	; WPMEM, .cmd_data_end-.cmd_data, W
	defw 0x1001, 0x1002, 0x1003, 0x1004, 0x1005, 0x1006, 0x1007
	defw 0x2001, 0x2002, 0x2003, 0x2004, 0x2005, 0x2006, 0x2007
.cmd_data_end
.cmp_data:	; Order is vice versa
	defw 0x2007, 0x2006, 0x2005, 0x2004, 0x2003, 0x2002, 0x2001
	defw 0x1007, 0x1006, 0x1005, 0x1004, 0x1003, 0x1002, 0x1001
.cmp_data_end
.cmp_slots:	defs 8


; Test that double register is set correctly.
UT_4_cmd_set_register.UT_pc:
	TEST_PREPARE_COMMAND

    ; Test
    call cmd_set_register

	; Get response
	call test_get_response

	; Test size
	TEST_MEMORY_WORD test_memory_payload.length, 1

	; Test set value
	ld hl,(backup.pc)
	TEST_DREG hl, 0x1112

 TC_END

.cmd_data:
	defb 0	; PC
	defw 0x1112	; Value
.cmd_data_end


; Test that single register low is set correctly.
UT_4_cmd_set_register.UT_c:
	TEST_PREPARE_COMMAND

	ld bc,0xFEDE
	ld (backup.bc),bc

    ; Test
    call cmd_set_register

	; Get response
	call test_get_response

	; Test size
	TEST_MEMORY_WORD test_memory_payload.length, 1

	; Test set value
	ld bc,(backup.bc)
	TEST_DREG bc, 0xFE22	; Only 0x22 is set

 TC_END

.cmd_data:
	defb 16	; C
	defw 0x2122	; Value
.cmd_data_end


; Test that single register high is set correctly.
UT_4_cmd_set_register.UT_b:
	TEST_PREPARE_COMMAND

	ld bc,0xFEDE
	ld (backup.bc),bc

    ; Test
    call cmd_set_register

	; Get response
	call test_get_response

	; Test size
	TEST_MEMORY_WORD test_memory_payload.length, 1

	; Test set value
	ld bc,(backup.bc)
	TEST_DREG bc, 0x32DE	; Only 0x32 is set

 TC_END

.cmd_data:
	defb 17	; B
	defw 0x3132	; Value
.cmd_data_end


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

	; Prepare fill data
	ld l,0x55
	call .prepare_uart_data

	; Test A
	call cmd_write_bank
	call test_get_response

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
	add hl,0x0100-1
	ld a,(hl)
	TEST_A 0x55

	; Prepare fill data
	ld l,0xAA
	call .prepare_uart_data

	; Test B
	call cmd_write_bank
	call test_get_response

	; Page in the memory bank
	nextreg REG_MMU+SWAP_SLOT,28

	ld hl,SWAP_ADDR	;.slot<<13	; Start address
	ld a,(hl)
	TEST_A 0xAA
	add hl,0x0100-1
	ld a,(hl)
	TEST_A 0xAA

	; Test size
	TEST_MEMORY_WORD test_memory_payload.length, 3

	; No error
	TEST_MEMORY_BYTE test_memory_payload+1, 0
	; No error string
	TEST_MEMORY_BYTE test_memory_payload+2, 0

	; Restore slot/bank (D)
	pop de
	;ld a,.slot+REG_MMU
	;call write_tbblue_reg	; A=register, D=value
	WRITE_TBBLUE_REG REG_MMU+SWAP_SLOT,d
 TC_END

	; L=fill byte
.prepare_uart_data:
	ld de,0x101
	push de
	call test_prepare_header
	pop de
	dec de
	; Prepare UART test data (command), 2x
	ld bc,0x0000	; Port for test data
	; Bank 28
	ld a,28
	out (c),a
	; Write all bytes
	ld de,0x100
	inc de
	ld (receive_buffer.length),de
	dec de
.loop:
	out (c),l
	dec de
	ld a,e
	or d
	jr nz,.loop
	ret


; Test cmd_continue
UT_6_continue:
	; Write test data to simulated UART buffer.
	TEST_PREPARE_COMMAND

	; Redirect "return"
	ld a,0xC3	; JP
	ld (restore_registers.ret_jump1),a
	ld hl,.exit_code
	ld (restore_registers.ret_jump1+1),hl

	; Prepare
	;ld hl,2+PAYLOAD_CONTINUE
	;ld (receive_buffer.length),hl

	; Return
    ld hl,.continue     ; The jump address
    ld (backup.pc),hl   ; Continue at return address
    ld (backup.sp),sp

	; Test
	call cmd_continue
.continue:

	; Check response
	call test_get_response

	; Test size
	TEST_MEMORY_WORD test_memory_payload.length, 1

 TC_END

.cmd_data:	PAYLOAD_CONTINUE 0, 0, 0, 0,	0, 0, 0
.cmd_data_end

.exit_code:
	pop af
	ret


; Test cmd_pause
UT_7_pause:
	; This command is not implemented for ZXNext (use NMI button instead).
 TC_END


; Test reading memory.
UT_8_cmd_read_mem.UT_normal:
	TEST_PREPARE_COMMAND

	; Test
	ld hl,.test_memory_src
	ld (payload_read_mem.mem_start),hl
	ld hl,.test_memory_src_end-.test_memory_src
	ld (payload_read_mem.mem_size),hl
	call cmd_read_mem

	; Check response
	call test_get_response

	; Compare src against dst
	TEST_MEM_CMP .test_memory_src, test_memory_payload+1, .test_memory_src_end-.test_memory_src

 TC_END

.test_memory_src:	defb 1, 2, 3, 4, 5, 6, 7, 8
.test_memory_src_end:
	defb 0	; WPMEM

.cmd_data: PAYLOAD_READ_MEM	0, .test_memory_src, .test_memory_src_end-.test_memory_src
.cmd_data_end



; Test reading memory in each relevant bank.
; Note: The locations should not contain any code/data.
UT_8_cmd_read_mem.UT_banks:
	; Page in different memory to ROM
	nextreg REG_MMU,81
	nextreg REG_MMU+1,82

	; Location 0x1FFF
	ld hl,0x1FFF
	ld (hl),0xA1
	ld (.cmd_data.mem_start),hl
	TEST_PREPARE_COMMAND
	call cmd_read_mem
	call test_get_response
	TEST_MEMORY_BYTE test_memory_payload+1,0xA1

	; Location 0x2000
	ld hl,0x2000
	ld (hl),0xA2
	ld (.cmd_data.mem_start),hl
	TEST_PREPARE_COMMAND
	call cmd_read_mem
	call test_get_response
	TEST_MEMORY_BYTE test_memory_payload+1,0xA2

	; Location 0x3FFF
	ld hl,0x3FFF
	ld (hl),0xA3
	ld (.cmd_data.mem_start),hl
	TEST_PREPARE_COMMAND
	call cmd_read_mem
	call test_get_response
	TEST_MEMORY_BYTE test_memory_payload+1,0xA3

	; Location 0x4000
	ld hl,0x4000
	ld (hl),0xA4
	ld (.cmd_data.mem_start),hl
	TEST_PREPARE_COMMAND
	call cmd_read_mem
	call test_get_response
	TEST_MEMORY_BYTE test_memory_payload+1,0xA4

	; Location 0x5123
	ld hl,0x5123
	ld (hl),0xA5
	ld (.cmd_data.mem_start),hl
	TEST_PREPARE_COMMAND
	call cmd_read_mem
	call test_get_response
	TEST_MEMORY_BYTE test_memory_payload+1,0xA5

	; Location 0xC000
;	ld ix,test_memory_dst	; Pointer to write to
	ld hl,0xC000
	ld (hl),0xA6
	ld (.cmd_data.mem_start),hl
	TEST_PREPARE_COMMAND
	call cmd_read_mem
	call test_get_response
	TEST_MEMORY_BYTE test_memory_payload+1,0xA6

	; Location 0xFFFF
	ld hl,0xFFFF
	; Page in different bank in slot 7 area
	ld a,80
	ld (slot_backup.slot7),a
	nextreg REG_MMU+MAIN_SLOT,a
	; Write
	ld (hl),0xA7
	; Restore bank
	nextreg REG_MMU+MAIN_SLOT,LOADED_BANK

	ld (.cmd_data.mem_start),hl
	TEST_PREPARE_COMMAND
	call cmd_read_mem
	call test_get_response
	TEST_MEMORY_BYTE test_memory_payload+1,0xA7

	; Test that slots are restored
	ld a,REG_MMU
	call read_tbblue_reg
	TEST_A 81
	ld a,REG_MMU+1
	call read_tbblue_reg
	TEST_A 82
 TC_END

.cmd_data: PAYLOAD_READ_MEM	0, 0, 1
.cmd_data_end


; Test writing memory.
UT_9_cmd_write_mem.UT_normal:
	TEST_PREPARE_COMMAND

	; Test
	call cmd_write_mem

	; Check response
	call test_get_response

	; Test size
	TEST_MEMORY_WORD test_memory_payload.length, 1

	; Test data
	TEST_MEMORY_BYTE .test_memory_dst,   0xD1
	TEST_MEMORY_BYTE .test_memory_dst+1, 0xD2
	TEST_MEMORY_BYTE .test_memory_dst+2, 0xD3
 TC_END

.test_memory_dst:	defb 0, 0, 0, 0, 0, 0, 0, 0
.test_memory_dst_end:
	defb 0	; WPMEM

.cmd_data: PAYLOAD_WRITE_MEM	0, .test_memory_dst
	defb 0xD1, 0xD2, 0xD3	; Test data
.cmd_data_end


; Test writing memory in each relevant bank.
; Note: The locations should not contain any code/data of
; the tested program which is around 0x7000 for unit testing.
UT_9_cmd_write_mem.UT_banks:
	; Page in different memory to ROM
	nextreg REG_MMU,81
	nextreg REG_MMU+1,82

	; Location 0x1FFF
	ld hl,.cmd_data.mem_start
	ld de,0x1FFF
	ldi (hl),de
	ld (hl),0xB1
	TEST_PREPARE_COMMAND
	call cmd_write_mem
	; Check response
	call test_get_response
	; Test data
	TEST_MEMORY_BYTE 0x1FFF, 0xB1

	; Location 0x2000
	ld hl,.cmd_data.mem_start
	ld de,0x2000
	ldi (hl),de
	ld (hl),0xB2
	TEST_PREPARE_COMMAND
	call cmd_write_mem
	; Check response
	call test_get_response
	; Test data
	TEST_MEMORY_BYTE 0x2000, 0xB2

	; Location 0x3FFF
	ld hl,.cmd_data.mem_start
	ld de,0x3FFF
	ldi (hl),de
	ld (hl),0xB3
	TEST_PREPARE_COMMAND
	call cmd_write_mem
	; Check response
	call test_get_response
	; Test data
	TEST_MEMORY_BYTE 0x3FFF, 0xB3


	; Location 0x4000
	ld hl,.cmd_data.mem_start
	ld de,0x4000
	ldi (hl),de
	ld (hl),0xB4
	TEST_PREPARE_COMMAND
	call cmd_write_mem
	; Check response
	call test_get_response
	; Test data
	TEST_MEMORY_BYTE 0x4000, 0xB4

	; Location 0x5123
	ld hl,.cmd_data.mem_start
	ld de,0x5123
	ldi (hl),de
	ld (hl),0xB5
	TEST_PREPARE_COMMAND
	call cmd_write_mem
	; Check response
	call test_get_response
	; Test data
	TEST_MEMORY_BYTE 0x5123, 0xB5

	; Location 0xC000
	ld hl,.cmd_data.mem_start
	ld de,0xC000
	ldi (hl),de
	ld (hl),0xB6
	TEST_PREPARE_COMMAND
	call cmd_write_mem
	; Check response
	call test_get_response
	; Test data
	TEST_MEMORY_BYTE 0xC000, 0xB6

	; Location 0xFFFF
	ld hl,.cmd_data.mem_start
	ld de,0xFFFF
	ldi (hl),de
	ld (hl),0xB7
	TEST_PREPARE_COMMAND
	ld a,80
	ld (slot_backup.slot7),a
	call cmd_write_mem
	; Check response
	call test_get_response
	; Test data
	nextreg REG_MMU+MAIN_SLOT,80
	TEST_MEMORY_BYTE 0xFFFF,0xB7

	; Restore
	nextreg REG_MMU+MAIN_SLOT,LOADED_BANK
 TC_END

.cmd_data: PAYLOAD_WRITE_MEM	0, 0
	defb 0	; test data
.cmd_data_end


; Test retrieving the slot/bank association.
; Note: This will also fail if some other test that changes the default
; slot/bank association fails.
UT_10_cmd_get_slots:
	TEST_EMPTY_COMMAND

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

	; Test
	call cmd_get_slots

	; Check repsonse
 	call test_get_response

	; Test size
	TEST_MEMORY_WORD test_memory_payload.length, 1+8

	; Compare with standard slots
	TEST_MEMORY_BYTE test_memory_payload+1, 0xFF	; ROM
	TEST_MEMORY_BYTE test_memory_payload+2, 0xFF	; ROM
	TEST_MEMORY_BYTE test_memory_payload+3, 10
	TEST_MEMORY_BYTE test_memory_payload+4, 11
	TEST_MEMORY_BYTE test_memory_payload+5, 4
	TEST_MEMORY_BYTE test_memory_payload+6, 5
	TEST_MEMORY_BYTE test_memory_payload+7, 0
	TEST_MEMORY_BYTE test_memory_payload+8, 70
 TC_END


; Test cmd_set_slot
UT_11_cmd_set_slot:
	ld iy,.cmd_data

	; Test
	ld (iy+PAYLOAD_SET_SLOT.slot),SWAP_SLOT
	ld (iy+PAYLOAD_SET_SLOT.bank),75
	TEST_PREPARE_COMMAND
	call cmd_set_slot
	; Check repsonse
 	call test_get_response
	; Test size
	TEST_MEMORY_WORD test_memory_payload.length, 2
	; Test: no error
	TEST_MEMORY_BYTE test_memory_payload+1, 0
	; Check bank
	ld a,REG_MMU+SWAP_SLOT
	call read_tbblue_reg
	TEST_A	75

	; Test
	ld (iy+PAYLOAD_SET_SLOT.slot),SWAP_SLOT
	ld (iy+PAYLOAD_SET_SLOT.bank),76
	TEST_PREPARE_COMMAND
	call cmd_set_slot
	; Check repsonse
 	call test_get_response
	; Check bank
	ld a,REG_MMU+SWAP_SLOT
	call read_tbblue_reg
	TEST_A	76

	; Test
	ld (iy+PAYLOAD_SET_SLOT.slot),MAIN_SLOT
	ld (iy+PAYLOAD_SET_SLOT.bank),70
	TEST_PREPARE_COMMAND
	call cmd_set_slot
	; Check repsonse
 	call test_get_response
	; Check bank
	TEST_MEMORY_BYTE slot_backup.slot7, 70

	; Test
	ld (iy+PAYLOAD_SET_SLOT.slot),0
	ld (iy+PAYLOAD_SET_SLOT.bank),0xFE
	TEST_PREPARE_COMMAND
	call cmd_set_slot
	; Check repsonse
 	call test_get_response
	; Check bank
	ld a,REG_MMU+0
	call read_tbblue_reg
	TEST_A	ROM_BANK

	; Test
	ld (iy+PAYLOAD_SET_SLOT.slot),0
	ld (iy+PAYLOAD_SET_SLOT.bank),0xFF
	TEST_PREPARE_COMMAND
	call cmd_set_slot
	; Check repsonse
 	call test_get_response
	; Check bank
	ld a,REG_MMU+0
	call read_tbblue_reg
	TEST_A	ROM_BANK

 TC_END

.cmd_data:	PAYLOAD_SET_SLOT	0, 0
.cmd_data_end



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

	; Check result
	ld a,(backup.border_color)
	and 0x07
	TEST_A CYAN

	; Test
	ld iy,.cmd_data
	ld (iy),BLACK
	ld ix,test_memory_output
	call cmd_set_border

	; Check result
	ld a,(backup.border_color)
	and 0x07
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
	ld hl,2+2*3
	ld (receive_buffer.length),hl

	; Test
	ld a,8
	ld (0xC000),a
	ld a,123
	ld (0xC0FF),a
	ld iy,.cmd_data
	ld ix,test_memory_output
	call cmd_set_breakpoints

	; Check response
	; Check length
	TEST_MEMORY_WORD test_memory_output+1, 1+2
	TEST_MEMORY_WORD test_memory_output+3, 0
	; Check returned values
	TEST_MEMORY_BYTE test_memory_output+6, 8
	TEST_MEMORY_BYTE test_memory_output+7, 123

	; Test memory (breakpoints)
	TEST_MEMORY_BYTE 0xC000, BP_INSTRUCTION
	TEST_MEMORY_BYTE 0xC0FF, BP_INSTRUCTION

 TC_END

.cmd_data:	defw 0xC000
			defb 0
			defw 0xC0FF
			defb 0



; Test cmd_set_breakpoints.
; Restore slots.
UT_14_cmd_set_breakpoints.UT_restore_slots:
	; Redirect
	call redirect_uart
	; Prepare
	ld hl,2+2*3
	ld (receive_buffer.length),hl

	; Page in banks in ROM area
	nextreg REG_MMU+0,70
	nextreg REG_MMU+1,71
	nextreg REG_MMU+SWAP_SLOT,72

	; Test
	xor a
	ld (0x8200),a
	ld (0x3FFF),a
	ld iy,.cmd_data
	ld ix,test_memory_output
	call cmd_set_breakpoints

	; Check response
	; Check length
	TEST_MEMORY_WORD test_memory_output+1, 	1+2
	TEST_MEMORY_WORD test_memory_output+3,	0
	; Check returned values
	TEST_MEMORY_BYTE test_memory_output+6, 0
	TEST_MEMORY_BYTE test_memory_output+7, 0

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

.cmd_data:	defw 0x0200
			defb 0
			defw 0x3FFF
			defb 0


; Test cmd_set_breakpoints.
; With long addresses (i.e. with banking).
UT_14_cmd_set_breakpoints.UT_long_bps:
	; Redirect
	call redirect_uart
	; Prepare
	ld hl,2+2*3
	ld (receive_buffer.length),hl

	; Page in banks in ROM area
	nextreg REG_MMU+0,73
	nextreg REG_MMU+1,74
	nextreg REG_MMU+SWAP_SLOT,72

	; Test
	ld a,9
	ld (0x8200&0x1FFF),a
	ld a,124
	ld (0x3FFF&0x1FFF+0x2000),a
	ld iy,.cmd_data
	ld ix,test_memory_output
	call cmd_set_breakpoints

	; Check response
	; Check length
	TEST_MEMORY_WORD test_memory_output+1, 1+2
	TEST_MEMORY_WORD test_memory_output+3, 0
	; Check returned values
	TEST_MEMORY_BYTE test_memory_output+6, 9
	TEST_MEMORY_BYTE test_memory_output+7, 124

	; Test memory (breakpoints)
	TEST_MEMORY_BYTE 0x8200&0x1FFF, BP_INSTRUCTION
	TEST_MEMORY_BYTE 0x3FFF&0x1FFF+0x2000, BP_INSTRUCTION

 TC_END

.cmd_data:	defw 0x8200
			defb 73+1
			defw 0x3FFF
			defb 74+1



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
	ld hl,2+2*4
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
	defw 0xC000	; Address
	defb 0		; No bank
	defb 0xAA	; Value

	defw 0xC0FF	; Address
	defb 0		; No bank
	defb 0x55	; Value


; Test cmd_restore_mem.
; Restore slots.
UT_15_cmd_restore_mem.UT_restore_slots:
	; Redirect
	call redirect_uart
	; Prepare
	ld hl,2+2*4
	ld (receive_buffer.length),hl

	; Page in banks in ROM area
	nextreg REG_MMU+0,70
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
	defw 0x0200	; Address
	defb 0		; No bank
	defb 0xA5	; Value

	defw 0x3FFF	; Address
	defb 0		; No bank
	defb 0x5A	; Value


; Test cmd_restore_mem.
; 2 values.
UT_15_cmd_restore_mem.UT_long_addresses:
	; Redirect
	call redirect_uart
	; Prepare
	ld hl,2+2*4
	ld (receive_buffer.length),hl

	; Page in banks in ROM area
	nextreg REG_MMU+0,73
	nextreg REG_MMU+1,74
	nextreg REG_MMU+SWAP_SLOT,72

	; Test
	ld a,0xFF
	ld (0xCF00&0x1FFF),a
	ld ((0xC0FF&0x1FFF)+0x2000),a
	ld iy,.cmd_data
	ld ix,test_memory_output
	call cmd_restore_mem

	; Check length
	TEST_MEMORY_WORD test_memory_output+1, 	1
	TEST_MEMORY_WORD test_memory_output+3,	0

	; Test
	TEST_MEMORY_BYTE 0xCF00&0x1FFF, 0xAA
	TEST_MEMORY_BYTE (0xC0FF&0x1FFF)+0x2000, 0x55
 TC_END

.cmd_data:
	defw 0xCF00	; Address
	defb 73+1	; Bank
	defb 0xAA	; Value

	defw 0xC0FF	; Address
	defb 74+1	; Bank
	defb 0x55	; Value


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
	call .wrap_cmd_loopback

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

.wrap_cmd_loopback
	call cmd_loopback
	; Does not return here:
	; ASSERT

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
