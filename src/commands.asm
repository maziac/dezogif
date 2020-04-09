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
.write_regs:		defw cmd_write_reg
.write_bank:		defw cmd_write_bank
.continue:			defw cmd_continue
.pause:				defw cmd_pause
.add_breakpoint:	defw cmd_add_breakpoint
.remove_breakpoint:	defw cmd_remove_breakpoint
.add_watchpoint:	defw 0	; not supported
.remove_watchpoint:	defw 0	; not supported
.read_mem:			defw cmd_read_mem
.write_mem:			defw cmd_write_mem
.get_slots:			defw cmd_get_slots
.read_state:		defw cmd_read_state
.write_state:		defw cmd_write_state


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
	out (BORDER),a
	add a,a
	ld hl,cmd_jump_table-2
	add hl,a
	ldi a,(hl)
	ld h,(hl)
	ld l,a
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
	; Read rest of message
	ld hl,receive_buffer.payload
	ld de,3
	call receive_bytes
	; Execute command
	call cmd_write_reg.inner
	; Send response
	ld de,1
	jp send_length_and_seqno
	
.inner:	; jump label for unit tests
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
; CMD_WRITE_BANK
; Writes one memory bank.
; Changes:
;  NA
;===========================================================================
cmd_write_bank:
	; Read bank number of message
	call read_uart_byte
	ld (receive_buffer.bank_number),a
	; Execute command
	call cmd_write_bank.inner
	; Send response
	ld de,1
	jp send_length_and_seqno

.inner:
	; Choose the right slot: don't use a slot where this program is located.
.slot:	equ ((cmd_write_bank+2*0x2000)>>13)&0x07
	; Remember current bank for slot
	ld a,.slot+REG_MMU
	call read_tbblue_reg	; Result in A
	push af	; remember

	; Change bank for slot 
	ld a,(receive_buffer.bank_number)
	nextreg .slot+REG_MMU,a

	; Read bytes from UART and put into bank
	ld hl,.slot<<13	; Start address
	ld de,0x2000	; Bank size
	call receive_bytes

	; Restore slot/bank (D)
	pop de
	ld a,.slot+REG_MMU
	jp write_tbblue_reg	; A=register, D=value



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
	; Read breakpoints from message
	ld hl,receive_buffer.payload
	ld de,6
	call receive_bytes
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
 ld a,MAGENTA
 out (BORDER),a

	; Send response
	ld de,1
	jp send_length_and_seqno



;===========================================================================
; CMD_ADD_BREAKPOINT
; Adds a breakpoint. Returns the breakpoint ID in the response.
; If no breakpoint is left 0 is returned.
; Changes:
;  NA
;===========================================================================
cmd_add_breakpoint:
	; Read breakpoint from message
	ld hl,receive_buffer.payload
	ld de,2
	call receive_bytes
	; Consume condition (conditions not implemented)
.loop:
	call read_uart_byte
	or a
	jr nz,.loop

	; TODO: to be implemented

	; Send response
	ld de,3
	call send_length_and_seqno

	; BP ID = 0 for now
	xor a
	call write_uart_byte
	xor a
	jp write_uart_byte



;===========================================================================
; CMD_REMOVE_BREAKPOINT
; Removes a breakpoint.
; Changes:
;  NA
;===========================================================================
cmd_remove_breakpoint:
	; Read breakpoint ID from message
	ld hl,receive_buffer.payload
	ld de,2
	call receive_bytes

	; TODO: to be implemented

	; Send response
	ld de,1
	jp send_length_and_seqno


;===========================================================================
; CMD_READ_MEM
; Reads a memory area.
; Changes:
;  NA
;===========================================================================
cmd_read_mem:
	; Read address and size from message
	ld hl,receive_buffer.payload
	ld de,5
	call receive_bytes

	; Send response
	ld hl,(receive_buffer.mem_size)
	ld de,1		; Add 1 for the sequence number
	add hl,de
	ex hl,de
	jr c,.hl_correct	; If C then hl already contains 1.
	ld l,0	; If NC then we need to reset HL to 0.
.hl_correct:
	call send_4bytes_length_and_seqno

.inner:
	; Loop all memory bytes
	ld hl,(receive_buffer.mem_start)
	ld de,(receive_buffer.mem_size)
.loop:
	ldi a,(hl)
	; Send
	call write_uart_byte
	dec de
	ld a,e
	or d
	jr nz,.loop
	ret


;===========================================================================
; CMD_WRITE_MEM
; Writes a memory area.
; Changes:
;  NA
;===========================================================================
cmd_write_mem:
	; Read address from message
	ld hl,receive_buffer.payload
	ld de,3
	call receive_bytes

.inner:
	; Read length and subtract 5
	ld hl,(receive_buffer.length)
	ld de,-5
	add hl,de
	ex de,hl
	; Read bytes from UART and put into memory
	ld hl,(receive_buffer.mem_start)
	call receive_bytes

	; Send response
	ld de,1
	jp send_length_and_seqno


;===========================================================================
; CMD_GET_SLOTS
; Returns the 8k-banks/slot association.
; Changes:
;  NA
;===========================================================================
cmd_get_slots:
	; Send response
	ld de,9
	call send_length_and_seqno

.inner:
	ld de,(REG_MMU<<8)+8	; Ld d and e at the same time
.loop:
	; Get bank for slot
	ld a,d
	call read_tbblue_reg	; Result in A
	; Send
	call write_uart_byte
	inc d
	dec e
	jr nz,.loop

	ret


;===========================================================================
; CMD_READ_STATE
; Returns the complete state of the device.
; Changes:
;  NA
;===========================================================================
cmd_read_state:
	; TODO: Implement to save/restore state

	; Send response
	ld de,1
	jp send_length_and_seqno


;===========================================================================
; CMD_WRITE_STATE
; Writes the complete state of the device.
; Changes:
;  NA
;===========================================================================
cmd_write_state:
	; TODO: Implement to save/restore state

	; Send response
	ld de,1
	jp send_length_and_seqno


