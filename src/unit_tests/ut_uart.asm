;========================================================
; ut_uart.asm
;
; Unit tests for the UART.
; Not much to test here as this requires HW.
;========================================================


    MODULE ut_uart


; To save the sp value
sp_backup:  defw    0

; uart routines jump here in case of errors.
@drain_main:
	ret


; Test that subroutine returns correctly.
UT_read_uart_byte_timeout:
	ld (sp_backup),sp
	; Redirect timeout jump
	ld hl,read_uart_byte.timeout
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


; Tests setting of the joystick IO mode.
UT_set_uart_joystick:
	; Joy port 1
	MEMSETBYTE uart_joyport_selection, 1
	call set_uart_joystick
	; Read value
	xor a :	in a,(4)
	nop ; TEST ASSERTION a == 10100000b

	; Joy port 2
	MEMSETBYTE uart_joyport_selection, 2
	call set_uart_joystick
	; Read value
	xor a :	in a,(4)
	nop ; TEST ASSERTION a == 10110000b

	; No joy port
	MEMSETBYTE uart_joyport_selection, 0
	call set_uart_joystick
	; Read value
	xor a :	in a,(4)
	nop ; TEST ASSERTION a == 0

	; Pathologic case
	MEMSETBYTE uart_joyport_selection, 3
	call set_uart_joystick
	; Read value
	xor a :	in a,(4)
	nop ; TEST ASSERTION a == 0

 TC_END


    ENDMODULE
