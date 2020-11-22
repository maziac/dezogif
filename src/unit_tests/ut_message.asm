;========================================================
; ut_message.asm
;
; Unit tests for the notification response.
;========================================================


    MODULE ut_message


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
UT_send_ntf_pause_fake:
	; Redirect
	call redirect_uart

	; Prepare
	ld hl,5+.cmd_data_end-.cmd_data
	ld (receive_buffer.length),hl

	; Test
	TEST_FAIL

 TC_END

.cmd_data:
	defb 1, 2, 3	; Version 1.2.3
	defb "host_program", 0	; Remote program name
.cmd_data_end



; Test sending of the break notification.
UT_send_ntf_pause:
	; Redirect
	call redirect_uart
	; Prepare
	ld hl,2
	ld (receive_buffer.length),hl

	; Change jump into ret
	ld a,0xC9	; RET
	;ld (cmd_pause.jump),a

	; Test
	ld iy,0		; Not used
	ld ix,test_memory_output
	;call cmd_pause

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


    ENDMODULE
