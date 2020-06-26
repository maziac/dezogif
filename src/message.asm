;===========================================================================
; message.asm
;
; Sending and receiving of complete messages.
; Receiving:
;  Once the first byte has been detected the other operation is stopped
;  and the complete message is received in 'receive_message'.
;  Once all bytes have been received the subroutine returns.
; Sending:
;  The 'send_message' subroutine will send all bytes and only return after
;  the last sent byte.
;===========================================================================


    
;===========================================================================
; Constants
;===========================================================================


;===========================================================================
; Structs. 
;===========================================================================

; CMD_SET_REG
	STRUCT PAYLOAD_SET_REG
register_number	defb
register_value	defw
	ENDS
payload_set_reg:	PAYLOAD_SET_REG = receive_buffer.payload

; CMD_ADD_BREAKPOINT
	STRUCT PAYLOAD_ADD_BREAKPOINT
bp_address	defw
	ENDS
payload_add_breakpoint:	PAYLOAD_ADD_BREAKPOINT = receive_buffer.payload

; CMD_REMOVE_BREAKPOINT
	STRUCT PAYLOAD_REMOVE_BREAKPOINT
bp_id	defw
	ENDS
payload_remove_breakpoint:	PAYLOAD_REMOVE_BREAKPOINT = receive_buffer.payload

; CMD_CONTINUE
	STRUCT PAYLOAD_CONTINUE
bp1_enable	defb
bp1_address	defw
bp2_enable	defb
bp2_address	defw
	ENDS
payload_continue:	PAYLOAD_CONTINUE = receive_buffer.payload

; CMD_READ_MEM
	STRUCT PAYLOAD_READ_MEM
reserved	defb
mem_start	defw
mem_size	defw
	ENDS
payload_read_mem:	PAYLOAD_READ_MEM = receive_buffer.payload

; CMD_WRITE_MEM
	STRUCT PAYLOAD_WRITE_MEM
reserved	defb
mem_start	defw
	ENDS
payload_write_mem:	PAYLOAD_WRITE_MEM = receive_buffer.payload

/*
; CMD_WRITE_BANK
	STRUCT PAYLOAD_WRITE_BANK
bank_number	defb
	ENDS
payload_write_bank:	PAYLOAD_WRITE_BANK = receive_buffer.payload
*/


;===========================================================================
; Starts the command loop. I.e. backups all registers.
; Interpretes the last received message.
; Stays in command loop waiting for the next message until
; receiving a CONTINUE message.
; Changes:
;  -, At the end the registers are restored.
;===========================================================================
cmd_loop:
	; Wait on next command
	call wait_for_uart_rx
	; Receive length sequence number and command
	ld hl,receive_buffer
	ld de,receive_buffer.payload-receive_buffer
	call receive_bytes
	;ld a,BLUE
	;out (BORDER),a
	; Handle command
	call cmd_call
	jr cmd_loop


;===========================================================================
; Executes available commands and leaves the loop as soon as no commands
; are available anymore.
; This is called from the coop routine (from the debugged program) when
; a new byte is available at the UART.
; Changes:
;  At the end the registers are restored.
;===========================================================================
execute_cmd:
	; Backup all registers 
	call save_registers
	; SP is now at debug_stack_top
	; Maximize clock speed
	nextreg REG_TURBO_MODE,RTM_28MHZ
.loop:
	; Receive length sequence number and command
	ld hl,receive_buffer
	ld de,receive_buffer.payload-receive_buffer
	call receive_bytes
	;ld a,BLUE
	;out (BORDER),a
	; Handle command
	call cmd_call

	; Check for some time if another command is available
	ld de,256*200
.wait:
	push de
	call check_uart_byte_available
	pop de
	jr nz,.loop
	dec de
	ld a,d
	or e
	jr nz,.wait
	
	; Return to debugged program
	jp restore_registers


; Called if a UART timeout occurs.
; As this could happen from everywhere the call stack is reset
; and then the cmd_loop is entered again.
rx_timeout:
enter_cmd_loop:	; Used by 'pause'.
	ld sp,debug_stack.top
	jp cmd_loop
; The receive timeout handler
RX_TIMEOUT_HANDLER = rx_timeout


;===========================================================================
; Receives a number of bytes from the UART.
; The received bytes are written at HL.
; Parameter:
;  HL = pointer to the buffer to write to.
;  DE = number of bytes to receive.
; Returns:
;  -
; Changes:
;  A, HL, DE, BC
;===========================================================================
receive_bytes:
.loop:
	push de
	; Get byte
	call read_uart_byte
	; Store
	ldi (hl),a
	;out (BORDER),a
	pop de
	dec de
	ld a,e
	or d
	jr nz,.loop
	ret

/*
;===========================================================================
; Once the first byte has been detected this function should be called.
; The subroutine does not return before all bytes of the message have been
; received.
; Returns:
;  receive_buffer contains the received message. The first 2 bytes of 
;  receive_buffer contain the length.
; Changes:
;  A, HL, DE, BC
;===========================================================================
receive_message:
	ld hl,receive_buffer
	; Receive the length, 2 bytes:
	; Get first byte
	call read_uart_byte
	; Store
	ldi (hl),a 
	; Get second byte
	call read_uart_byte
	; Store
	ldi (hl),a 

	; Receive the rest
	ld de,(receive_buffer.length)
.loop:
	; Check if all bytes received
	ld a,e
	or d
	ret z	; all bytes received
	; Get next byte
	call read_uart_byte
	; Store
	ldi (hl),a 
	; Next
	dec de
	jr .loop
*/


;===========================================================================
; Once the first byte has been detected this function should be called.
; The subroutine does not return before all bytes of the message have been
; received.
; Parameter:
;  HL = Pointer to the message to send. The 2 fist bytes of the message are 
;  the length.
; Returns:
;  -
; Changes:
;  A, HL, BC
;===========================================================================
send_message:  ; TODO: maybe not required.
	; Get length
	; First length byte
	ldi a,(hl)
	ld e,a
	; Write to UART
	call write_uart_byte
	; Second length byte
	ldi a,(hl)
	ld d,a
	; Write to UART
	call write_uart_byte

	; DE contains the length
.loop:
	ld a,e
	or d
	ret z		; Return if all bytes are sent

	; Get next byte
	ldi a,(hl)
	; Write to UART
	call write_uart_byte
	; Next
	dec de
	jr .loop

  

;===========================================================================
; Sends the length and the sequence number.
; The sequence number is taken directly from the receive_buffer.
; Important: Use only for lengths up to 65536.
; Parameter:
;  DE = Length.
; Returns:
;  -
; Changes:
;  A, DE, BC, HL=0
;===========================================================================
send_length_and_seqno: 
	; Store Length MSB=0
	ld hl,0
	; jp send_4bytes_length_and_seqno
	; Flow through

;===========================================================================
; Sends a 4 bytes length and the sequence number.
; The sequence number is taken directly from the receive_buffer.
; Important: Use only for lengths up to 65536.
; Parameter:
;  HL/DE = Length. HL=MSB, DE=LSB
; Returns:
;  -
; Changes:
;  A, DE, BC
;===========================================================================
send_4bytes_length_and_seqno: 
	; First length byte
	ld a,e
	; Write to UART
	call write_uart_byte
	; Second length byte
	ld a,d
	; Write to UART
	call write_uart_byte
	; Third length byte
	ld a,l
	; Write to UART
	call write_uart_byte
	; Fourth length byte
	ld a,h
	; Write to UART
	call write_uart_byte
	; Sequence number
	ld a,(receive_buffer.seq_no)
	jp write_uart_byte


;===========================================================================
; Sends a NTF_PAUSE notification
; Parameter:
;  D = break reason:
;	  0 = no reason (e.g. a step-over)
;	  1 = manual break
;	  2 = breakpoint hit
; HL = breakpoint address that was hit (if D!=0)
; Returns:
;  -
; Changes:
;  A, E, BC
;===========================================================================
send_ntf_pause:
	; LOGPOINT [CMD] send_ntf_pause: reason=${D}, breakpoint=${HL:hex}h (${HL})
	; First length byte
	ld a,6
	call write_uart_byte
	; Rest of length + seqno=0
	xor a
	ld e,4
.loop:
	call write_uart_byte
	dec e
	jr nz,.loop
	; NTF_PAUSE id
	ld a,1	; NTF_PAUSE
	call write_uart_byte
	; Breakpoint reason
	ld a,d
	call write_uart_byte
	; Breakpoint
	ld a,l
	call write_uart_byte
	ld a,h
	call write_uart_byte
	xor a
	jp write_uart_byte

