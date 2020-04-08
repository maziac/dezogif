;===========================================================================
; commands.asm
;
; 
;===========================================================================


    
;===========================================================================
; Constants
;===========================================================================




;===========================================================================
; Data. 
;===========================================================================

; Command number <-> subroutine association
cmd_jump_table:
.get_config:		defw cmd_get_config
.read_regs:			defw cmd_read_regs
.write_regs:		defw 0
.write_bank:		defw 0
.continue:			defw cmd_continue
.pause:				defw cmd_pause
.add_breakpoint:	defw 0
.remove_breakpoint:	defw 0
.add_watchpoint:	defw 0	; not supported
.remove_watchpoint:	defw 0	; not supported
.read_mem:			defw 0
.write_mem:			defw 0
.get_slots:			defw 0
.read_state:		defw 0
.write_state:		defw 0


;===========================================================================
; Jumps to the correct command according the jump table.
; Parameters:
;	(receive_buffer.command) = the command, e.g. CMD_GET_CONFIG
; Changes:
;  NA
;===========================================================================
cmd_call:
	; Get pointer to subroutine
	ld a,(receive_buffer.command)
	add a,a
	ld hl,cmd_jump_table
	add hl,a
	ldi a,(hl)
	ld h,(hl)
	; safety check
	or a,h
	ret z	; return if jump address is zero
	; jump to subroutine
	jp (hl)


;===========================================================================
; CMD_GET_CONFIG
; Sends a response with the supported features.
; Changes:
;  NA
;===========================================================================
cmd_get_config:
	; Send length and seq-no
	ld de,2
	call send_length_and_seqno
	; Send config
	ld a,0b00000001
	jp write_uart_byte



;===========================================================================
; CMD_READ_REGS
; Reads all register values and sends them in the response.
; Changes:
;  NA
;===========================================================================
cmd_read_regs:
	; Send response
	ld de,29
	call send_length_and_seqno
	; Get PC
	ld hl,(backup.sp)
	ldi a,(hl)
	; Write LOW(PC) to UART
	call write_uart_byte
	; Write HIGH(PC) to UART
	ld a,(hl)
	call write_uart_byte
	; Loop other values
	ld hl,backup.sp
	ld de,-3
	ld b,13
.loop:
	push bc
	ldi a,(hl)
	call write_uart_byte
	ld a,(hl)
	call write_uart_byte
	; Next
	add hl,de 
	pop bc
	djnz .loop
	ret



;===========================================================================
; CMD_WRITE_REG
; Writes one register.
; Changes:
;  NA
;===========================================================================
cmd_write_reg:
	; Send response
	ld de,5
	call send_length_and_seqno
.test:	; jump label for unit tests
	; Get value in DE
	ld hl,receive_buffer.register_value+1
	ldd d,(hl)
	ldd e,(hl)
	; Which register
	ld a,(hl)	; hl=receive_buffer.register_number
	or a
	jr nz,.next1
	; PC
	ld hl,(backup.sp)
.store_dreg:
	ldi (hl),e
	ld (hl),d
	ret
.next1:
	sub 13
	jr nc,.next2
	; Double register. A is -12 to -2
	neg ; A is 12 to 2
	add a,a	; a*2: 24 to 4
	ld hl,backup.hl2-4
	add hl,a
	jr .store_dreg
.next2:
	; Single register
	jr nz,.next4
	; IM is directly set
	inc e
	dec e
	jr nz,.not_im0
	im 0
	ret
.not_im0:
	dec e
	jr nz,.not_im1
	im 1
	ret
.not_im1:
	dec e
	ret nz	; IM number wrong
	im 2
	ret

.next4:	
	sub 35-13
	ret nc	; Otherwise unknown
	; Single register. A is -20 to -1
	neg ; A is 20 to 1
	dec a	; A is 19 to 0
	xor 0x01	; The endianess need to be corrected.
	ld hl,backup.hl2
	add hl,a
	; Store register
	ld (hl),e
	ret
	

;===========================================================================
; CMD_CONTINUE
; Continues debugged program execution.
; Restores the back'uped registers and jumps to the last
; execution point. The instruction after the call to 
; 'check_for_message'.
; Changes:
;  NA
;===========================================================================
cmd_continue:
	; Send response
	ld de,1
	call send_length_and_seqno
	; Restore registers
	jp restore_registers


;===========================================================================
; CMD_PAUSE
; Pauses execution of the debugged program execution.
; The UART driver ends in the command loop waiting for further
; commands.
; Changes:
;  NA
;===========================================================================
cmd_pause:
	; Send response
	ld de,1
	jp send_length_and_seqno


