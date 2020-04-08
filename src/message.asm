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

; Commands
CMD.GET_CONFIG:			equ 	1
CMD.READ_REGS:			equ 	2
CMD.WRITE_REGS:			equ 	3
CMD.WRITE_BANK:			equ 	4
CMD.CONTINUE:			equ 	5
CMD.PAUSE:				equ 	6
CMD.ADD_BREAKPOINT:		equ 	7
CMD.REMOVE_BREAKPOINT:	equ 	8
CMD.ADD_WATCHPOINT:		equ 	9
CMD.REMOVE_WATCHPOINT:	equ 	10
CMD.READ_MEM:			equ 	11
CMD.WRITE_MEM:			equ 	12
CMD.GET_SLOTS:			equ 	13
CMD.READ_STATE:			equ 	14
CMD.WRITE_STATE:		equ 	15


;===========================================================================
; Data. 
;===========================================================================

; Counts the received bytes.
;received_length:  defw 0


; Counter for the remaining bytes.
;receive_remaining_length:  defw 0

; Pointer to the next receive position.
;receive_ptr:    defw 0


; The UART data is put here before being interpreted.
receive_buffer: 
.length:
	defw 0
.seq_no:
	defb 0
.command:
	defb 0
.payload:
.register_number:	; For CMD_READ_REGS
.bank_number:		; For CMD_WRITE_BANK
.bp1_enable:		; For CMD_CONTINUE
.bp_address:		; For CMD_ADD_BREAKPOINT
.bp_id:				; For CMD_REMOVE_BREAKPOINT
	defs 1
.register_value:	; For CMD_READ_REGS
.bp1_address:		; For CMD_CONTINUE
.mem_start:			; For CMD_READ_MEM
	defs 1
	defs 1
.bp2_enable:		; For CMD_CONTINUE
.mem_size:			; For CMD_READ_MEM
	defs 1
.bp2_address:		; For CMD_CONTINUE
	defs 1
	defs 1

	defs 100	; TODO: Remove. Soviel braichen wir nicht.
    defb 0  ; WPMEM


;===========================================================================
; Initializes the receive buffer.
; Changes:
;  HL
;===========================================================================
 if 0
init_receive_buffer:
    ld hl,0
    ld (received_length),hl
    ld hl,receive_buffer
    ld (receive_ptr),hl
    ret
 endif


;===========================================================================
; Checks if a new messages has been received.
; If not then it returns without changing any register or flag.
; If yes the message is received and interpreted.
; Changes:
;  -
;===========================================================================
dbg_check_for_message:
	; Save
	ld (backup.hl),hl
	ld (backup.sp),sp
	pop hl	; Get return address=current PC 
	ld (backup.pc),hl ; TODO: Instead I could use ((backup.sp))
	ld sp,backup.af+2
	push af
    call check_uart_rx
    ; Check if message needs to be parsed
	jr nz,start_cmd_loop
	; No message -> return
	pop af 
	ld sp,(backup.sp)
	ld hl,(backup.hl)
	ret 


;===========================================================================
; Starts the command loop. I.e. backups all registers.
; Interpretes the last received message.
; Stays in command loop waiting for the next message until
; receiving a CONTINUE message.
; Changes:
;  -, At the end the registers are restored.
;===========================================================================
start_cmd_loop:
	; Backup all registers after 'af', SP = points to backup.af
	call save_registers
	; SP is now at debug_stack_top
	; Maximize clock speed
	ld a,RTM_28MHZ
	nextreg REG_TURBO_MODE,a
cmd_loop:
	; Receive length sequence number and command
	ld hl,receive_buffer
	ld de,receive_buffer.payload-receive_buffer
	call receive_bytes
	; Handle command
	call cmd_call
	; Wait on next command
	jr cmd_loop
	

; Called if a UART timeout occurs.
; As this could happen from everywhere the call stack is reset
; and then the cmd_loop is entered again.
timeout:
	ld sp,debug_stack_top
	jp cmd_loop


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
	inc d
.loop:
	; Get byte
	call read_uart_byte
	; Store
	ldi (hl),a
	dec e
	jr nz,.loop
	dec d
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
; Parameter:
;  DE = length (including sequence number).
; Returns:
;  -
; Changes:
;  A, DE, BC
;===========================================================================
send_length_and_seqno: 
	; First length byte
	ld a,e
	; Write to UART
	call write_uart_byte
	; Second length byte
	ld a,d
	; Write to UART
	call write_uart_byte
	; Sequence number
	ld a,(receive_buffer.seq_no)
	jp write_uart_byte

