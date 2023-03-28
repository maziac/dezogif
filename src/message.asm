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

; Each sent message has to start with this byte.
; The ZX Next transmit a lot of zeroes if the joy port is not configured.
; Therefore this byte is required to recognize when a message starts.
MESSAGE_START_BYTE:	equ 0xA5


;===========================================================================
; Structs.
;===========================================================================

; CMD_SET_REG
	STRUCT PAYLOAD_SET_REG
register_number	defb
register_value	defw
	ENDS

; CMD_ADD_BREAKPOINT
	STRUCT PAYLOAD_ADD_BREAKPOINT
bp_address	defw
	ENDS

; CMD_REMOVE_BREAKPOINT
	STRUCT PAYLOAD_REMOVE_BREAKPOINT
bp_id	defw
	ENDS

; CMD_CONTINUE
	STRUCT PAYLOAD_CONTINUE
bp1_enable	defb
bp1_address	defw
bp2_enable	defb
bp2_address	defw
alternate_command	defb
range_start	defw
range_end	defw
	ENDS

; CMD_READ_MEM
	STRUCT PAYLOAD_READ_MEM
reserved	defb
mem_start	defw
mem_size	defw
	ENDS

; CMD_WRITE_MEM
	STRUCT PAYLOAD_WRITE_MEM
reserved	defb
mem_start	defw
	ENDS

; CMD_SET_SLOT
	STRUCT PAYLOAD_SET_SLOT
slot	defb
bank	defb
	ENDS



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


/*
;===========================================================================
; Executes available commands and leaves the loop as soon as no commands
; are available anymore.
; Immediately returns if no message is available.
;===========================================================================
execute_cmds_loop:
	call check_uart_byte_available
	ret z
.loop:
	; Receive length sequence number and command
	ld hl,receive_buffer
	ld de,receive_buffer.payload-receive_buffer
	call receive_bytes
	;ld a,BLUE
	;out (BORDER),a
	; Handle command
	call cmd_call

	; Check for some time to see if another command is available
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
	ret
*/


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

/*
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
send_message:
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
*/


;===========================================================================
; Sends the length and the sequence number.
; The sequence number is taken directly from the receive_buffer.
; Important: Use only for lengths up to 65536.
; Parameter:
;  DE = Length (including the seq no, everything after the length)
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
;  HL/DE = Length (including the seq no). HL=MSB, DE=LSB
; Returns:
;  -
; Changes:
;  A, DE, BC
;===========================================================================
send_4bytes_length_and_seqno:
	; Write first byte to recognize message
	ld a,MESSAGE_START_BYTE
	call write_uart_byte
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
; HL = breakpoint address that was hit (if D!=0).
; Note: The breakpoint address is a 64k address. The routine will look up
; the right bank by itself and send a long address.
; Returns:
;  -
; Changes:
;  A, E, BC
;===========================================================================
send_ntf_pause:
	; LOGPOINT [CMD] send_ntf_pause: reason=${D}, breakpoint=${HL:hex}h (${HL})
	; Change main state
	ld a,PRGM_STOPPED
	ld (prgm_state),a
	; Write first byte to recognize message
	ld a,MESSAGE_START_BYTE
	call write_uart_byte
	; First length byte
	ld a,7
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
	; Bank
	rlca : rlca : rlca ; Get slot
	and 0111b
	add REG_MMU
	call read_tbblue_reg
	inc a	; bank+1
	call write_uart_byte
	; Empty reason string
	xor a
	jp write_uart_byte

