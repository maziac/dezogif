;========================================================
; ut_uart.asm
;
; Unit tests for the UART.
; Not much to test here as this requires HW.
;========================================================


    MODULE ut_uart


; To save the sp value
sp_backup:  defw    0


; Test that subroutine returns correctly.
UT_read_uart_byte_timeout:
	ld (sp_backup),sp
	; Redirect timeout jump
	ld hl,rx_timeout
	ldi (hl),0xC3	; JP
	ldi (hl),.timeout&0xFF
	ld (hl),.timeout>>8

	; Test
	call read_uart_byte
	; Should never return
	TEST_FAIL		; So FAIL if it returns

.timeout:
	; Instead the timeout should be reached
	ld sp,(sp_backup)	; Restore SP
 TC_END


    ENDMODULE
    