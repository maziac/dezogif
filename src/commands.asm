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

; DZRP version 1.1.0
DZRP_VERSION:	defb 1, 1, 0

; The own program name and version
PROGRAM_NAME:	defb "dbg_uart_if v0.1.0", 0
.end


; Command number <-> subroutine association
cmd_jump_table:
.get_config:		defw cmd_init
.read_regs:			defw cmd_get_regs
.write_regs:		defw cmd_set_reg
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
.get_tbblue_reg:	defw cmd_get_tbblue_reg
.get_sprites_palette:	defw cmd_get_sprites_palette
.get_sprites:		defw cmd_get_sprites
.get_sprite_patterns:	defw cmd_get_sprite_patterns
.get_sprites_clip_window_and_control:	defw cmd_get_sprites_clip_window_and_control
.set_border:		defw cmd_set_border


;===========================================================================
; Jumps to the correct command according the jump table.
; Parameters:
;	(receive_buffer.command) = the command, e.g. CMD_GET_CONFIG
; Changes:
;  NA
;===========================================================================
cmd_call:	; Get pointer to subroutine
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
cmd_init:
	; LOGPOINT [COMMAND] cmd_init
	; Read version number
	ld hl,receive_buffer.payload
	ld de,3
	call receive_bytes
	; Read remote program name
.read_loop
	call read_uart_byte
	or a
	jr nz,.read_loop

	; Send length and seq-no
	ld de,PROGRAM_NAME.end-PROGRAM_NAME + 5
	call send_length_and_seqno
	; No error
	xor a
	call write_uart_byte
	; Send config
	ld hl,DZRP_VERSION
	ld e,3
.write_dzrp_version_loop:
	ldi a,(hl)
	call write_uart_byte
	dec e
	jr nz,.write_dzrp_version_loop
	; Send own program name and version
	ld hl,PROGRAM_NAME
.write_prg_name_loop:
	ldi a,(hl)
	call write_uart_byte
	or a
	jr nz,.write_prg_name_loop
	ret


;===========================================================================
; CMD_READ_REGS
; Reads all register values and sends them in the response.
; Changes:
;  NA
;===========================================================================
cmd_get_regs:
	; LOGPOINT [COMMAND] cmd_get_regs
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
cmd_set_reg:
	; LOGPOINT [COMMAND] cmd_set_reg
	; Read rest of message
	ld hl,receive_buffer.payload
	ld de,3
	call receive_bytes
	; Execute command
	call cmd_set_reg.inner
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
	ld hl,backup.im
	inc e
	dec e
	jr nz,.not_im0
	ld (hl),0
	im 0
	ret
.not_im0:
	dec e
	jr nz,.not_im1
	ld (hl),1
	im 1
	ret
.not_im1:
	dec e
	ret nz	; IM number wrong
	ld (hl),2
	im 2
	ret

.next4:	
	; Here: F=1, A=2, ...., I'=22
	sub 23
	; Here: F=-22, A=-21, ...., I'=-1
	ret nc	; Otherwise unknown
	; Single register. A is -22 to -1
	neg ; A is 22 to 1; I'=1, R'=2, D'=3, E'=4
	dec a
	; A is 21 to 0; I'=0, R'=1, D'=2, E'=3
	xor 0x01	; The endianess need to be corrected.
	; A is 21 to 0; R'=0, I'=1, E'=2, D'=3
	ld hl,backup.r
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
	; LOGPOINT [COMMAND] cmd_write_bank
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
	; Read bank number of message
	call read_uart_byte
	nextreg .slot+REG_MMU,a

	; Read bytes from UART and put into bank
	ld hl,.slot<<13	; Start address
	ld de,0x2000	; Bank size
	call receive_bytes

	; Restore slot/bank (D)
	pop de
	;ld a,.slot+REG_MMU
	;jp write_tbblue_reg	; A=register, D=value
	WRITE_TBBLUE_REG .slot+REG_MMU,d
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
	; LOGPOINT [COMMAND] cmd_continue
	; Read breakpoints etc. from message
	ld hl,receive_buffer.payload
	ld de,11
	call receive_bytes
	; Send response
	ld de,1
	call send_length_and_seqno
	; Restore registers
	ret ; TODO REMOVE
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
	; LOGPOINT [COMMAND] cmd_pause
 ld a,MAGENTA
 out (BORDER),a

	; Send response
	ld de,1
	;jp send_length_and_seqno

	; TODO REMOVE
	call send_length_and_seqno
	
	; Send fake break notification
	ld d,0	; no reason
	ld hl,0 ; bp address
	call send_ntf_pause
	ret


;===========================================================================
; CMD_ADD_BREAKPOINT
; Adds a breakpoint. Returns the breakpoint ID in the response.
; If no breakpoint is left 0 is returned.
; Changes:
;  NA
;===========================================================================
cmd_add_breakpoint:
	; LOGPOINT [COMMAND] cmd_add_breakpoint
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
	; LOGPOINT [COMMAND] cmd_remove_breakpoint
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
	; LOGPOINT [COMMAND] cmd_read_mem
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
	; LOGPOINT [COMMAND] cmd_write_mem
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
	; LOGPOINT [COMMAND] cmd_get_slots
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
	; LOGPOINT [COMMAND] cmd_read_state
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
	; LOGPOINT [COMMAND] cmd_write_state
	; TODO: Implement to save/restore state

	; Send response
	ld de,1
	jp send_length_and_seqno


;===========================================================================
; CMD_GET_TBBLUE_REG
; Reads the tbblue register.
; Changes:
;  NA
;===========================================================================
cmd_get_tbblue_reg:
	; LOGPOINT [COMMAND] cmd_get_tbblue_reg
	; Send response
	ld de,2
	call send_length_and_seqno
	; Read register number
	call read_uart_byte	; Register number
	call read_tbblue_reg	; Result in A
	; Send 
	jp write_uart_byte


;===========================================================================
; CMD_GET_SPRITES_PALETTE
; Returns the values of the requested palette.
; Changes:
;  NA
;===========================================================================
cmd_get_sprites_palette:
	; LOGPOINT [COMMAND] cmd_get_sprites_palette
	; Start response
	ld de,513
	call send_length_and_seqno
	; Save current values
	ld a,REG_PALETTE_CONTROL
	call read_tbblue_reg	; Result in A
	ld d,a	; eUlaCtrlReg
	ld a,REG_PALETTE_INDEX
	call read_tbblue_reg	; Result in A
	ld e,a	; indexReg
	ld a,REG_PALETTE_VALUE_8
	call read_tbblue_reg	; Result in A
	ld l,a	; colorReg
	ld a,REG_MACHINE_TYPE
	call read_tbblue_reg	; Result in A
    ld h,a	; machineReg
	; Save
	push hl		; h = machineReg, l = colorReg
	push de 	; d = eUlaCtrlReg, e = indexReg

	; Select sprites
	ld a,d	; eUlaCtrlReg
	and 0x0F
	or 0b00100000
	ld e,a
	; Get palette index
	call read_uart_byte
	bit 0,a
	ld a,e
 	jr z,.palette_0
	or 0b01000000	; Select palette 1
.palette_0:
	;ld d,a
	;ld a,REG_PALETTE_CONTROL
	;call write_tbblue_reg
	NEXTREG REG_PALETTE_CONTROL,a

/*
           // Store current values
            var cspect = Main.CSpect;
            byte eUlaCtrlReg = cspect.GetNextRegister(REG_PALETTE_CONTROL);
            byte indexReg = cspect.GetNextRegister(REG_PALETTE_INDEX);
            byte colorReg = cspect.GetNextRegister(REG_PALETTE_VALUE_8);
            // Bit 7: 0=first (8bit color), 1=second (9th bit color)
            byte machineReg = cspect.GetNextRegister(REG_MACHINE_TYPE);
            // Select sprites
            byte selSprites = (byte)((eUlaCtrlReg & 0x0F) | 0b0010_0000 | (paletteIndex << 6));
            cspect.SetNextRegister(0x43, selSprites); // Resets also 0x44
  */
  
	// Read palette
	ld d,0	; Index
.loop:
	; Set index
	; d = index
;	ld a,REG_PALETTE_INDEX
;	call write_tbblue_reg ; Result in A
	WRITE_TBBLUE_REG REG_PALETTE_INDEX,d
	// Read color
	ld a,REG_PALETTE_VALUE_8
	call read_tbblue_reg ; Result in A
	call write_uart_byte
	ld a,REG_PALETTE_VALUE_16  ; color9th
	call read_tbblue_reg ; Result in A
	call write_uart_byte
	inc d 
	jr nz,.loop		; Loop 256x

    /*
             // Read palette
            for (int i = 0; i < 256; i++)
            {
                // Set index
                cspect.SetNextRegister(REG_PALETTE_INDEX, (byte)i);
                // Read color
                byte colorMain = cspect.GetNextRegister(REG_PALETTE_VALUE_8);
                SetByte(colorMain);
                byte color9th = cspect.GetNextRegister(REG_PALETTE_VALUE_16);
                SetByte(color9th);
                //Log.WriteLine("Palette index={0}: 8bit={1}, 9th bit={2}", i, colorMain, color9th);
            }
	*/

	// Restore values
	pop de 		; d = eUlaCtrlReg, e = indexReg
	pop hl		; h = machineReg, l = colorReg
	; d = eUlaCtrlReg
	WRITE_TBBLUE_REG REG_PALETTE_CONTROL,d
	; e = indexReg
	WRITE_TBBLUE_REG REG_PALETTE_INDEX,e

	; If bit 7 set, increase 0x44 index.
	bit 7,h
	ret z

	; Write it to increase the index
	; l = colorReg
	WRITE_TBBLUE_REG REG_PALETTE_VALUE_16,e
	ret 

	/*
            // Restore values
            cspect.SetNextRegister(REG_PALETTE_CONTROL, eUlaCtrlReg);
            cspect.SetNextRegister(REG_PALETTE_INDEX, indexReg);
            if ((machineReg & 0x80) != 0)
            {
                // Bit 7 set, increase 0x44 index.
                // Write it to increase the index
                cspect.SetNextRegister(REG_PALETTE_VALUE_16, colorReg);
            }
	*/
	

;===========================================================================
; CMD_GET_SPRITES
; Returns the requested sprites (attributes).
; Changes:
;  NA
;===========================================================================
cmd_get_sprites:
; TODO: Implement
	; LOGPOINT [COMMAND] cmd_get_sprites
	ret


;===========================================================================
; CMD_GET_SPRITE_PATTERNS
; Returns the requested sprite patterns.
; Changes:
;  NA
;===========================================================================
cmd_get_sprite_patterns:
; TODO: Implement
	; LOGPOINT [COMMAND] cmd_get_sprites_patterns
	ret


;===========================================================================
; CMD_GET_SPRITES_CLIP_WINDOW_AND_CONTROL
; Returns the sprites clip window and the control byte (regsiter (0x15).
; Changes:
;  NA
;===========================================================================
cmd_get_sprites_clip_window_and_control:
; TODO: Implement
	; LOGPOINT [COMMAND] cmd_get_sprites_clip_window_and_control
	ret


;===========================================================================
; CMD_SET_BORDER
; Sets the border color.
; Changes:
;  NA
;===========================================================================
cmd_set_border:
	; LOGPOINT [COMMAND] cmd_set_border
	; Read register number
	call read_uart_byte
	out (BORDER),a
	; Send response
	ld de,1
	jp send_length_and_seqno
