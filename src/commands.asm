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
;	A = the command, e.g. CMD_GET_CONFIG
; Changes:
;  NA
;===========================================================================
cmd_call:
	; Get pointer to subroutine
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


