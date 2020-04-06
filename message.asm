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
; Data. 
;===========================================================================

; Counts the received bytes.
received_length:  defw 0


; Counter for the remaining bytes.
receive_remaining_length:  defw 0

; Pointer to the next receive position.
receive_ptr:    defw 0


; The UART data is put here before being interpreted.
receive_buffer: defs 100
    defb 0  ; WPMEM


;===========================================================================
; Initializes the receive buffer.
; Changes:
;  HL
;===========================================================================
init_receive_buffer:
    ld hl,0
    ld (received_length),hl
    ld hl,receive_buffer
    ld (receive_ptr),hl
    ret


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
	inc hl 
	; Get second byte
	call read_uart_byte
	; Store
	ld (hl),a 
	inc hl 

	; Receive the rest
	ld de,(receive_buffer)
	inc de
.loop:
	; Check if all bytes received
	dec de
	ret z	; all bytes received
	; Get next byte
	call read_uart_byte
	; Store
	ld (hl),a 
	inc hl 
	; Next
	jr .loop


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
	inc de
.loop:
	dec de
	ret z		; Return if all bytes are sent

	; Get next byte
	ldi a,(hl)
	; Write to UART
	call write_uart_byte
	; Next
	jr .loop

  

