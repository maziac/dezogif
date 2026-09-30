;===========================================================================
; commands.asm
;
;
;===========================================================================



;===========================================================================
; Structs
;===========================================================================

	; The memory mapping (banks) of the debugged program.
	; Saved when entering the debugger, restored on continue.
	; While debugging the MMU registers belong to the debugger. All accesses
	; to the debugged program's memory go through this backup.
	; slot0-slot7 need to be consecutive (indexed by slot number).
	STRUCT SLOT_BACKUP
slot0:		defb	; On a SW breakpoint (RST 0) this must be 0xFF=ROM (AltROM).
slot1:		defb
slot2:		defb
slot3:		defb
slot4:		defb
slot5:		defb
slot6:		defb
slot7:		defb
	ENDS



;===========================================================================
; Const data.
;===========================================================================

; DZRP version 2.2.0
DZRP_VERSION.MAJOR:		equ 2
DZRP_VERSION.MINOR:		equ 2
DZRP_VERSION.PATCH:		equ 0


; The own program name and version
PROGRAM_NAME:	defb "dezogif "
				PRG_VERSION
				defb 0
.end


; Command number <-> subroutine association
cmd_jump_table:
					defw cmd_not_supported		; 0 = reserved
.init:				defw cmd_init				; 1
.close:				defw cmd_close				; 2
.get_registers:		defw cmd_get_registers		; 3
.set_register:		defw cmd_set_register		; 4
.write_bank:		defw cmd_not_supported		; 5 = deprecated
.continue:			defw cmd_continue			; 6
.pause:				defw cmd_pause				; 7
.read_mem:			defw cmd_not_supported		; 8 = deprecated
.write_mem:			defw cmd_write_mem			; 9
.set_slot:			defw cmd_set_slot			; 10
.get_tbblue_reg:	defw cmd_get_nextreg		; 11
.set_border:		defw cmd_not_supported		; 12 = deprecated
.set_breakpoints:	defw cmd_set_breakpoints	; 13
.restore_mem:		defw cmd_restore_mem		; 14
.loopback:			defw cmd_loopback			; 15
.get_sprites_palette:	defw cmd_get_sprites_palette	; 16
.get_sprites_clip_window_and_control:	defw cmd_get_sprites_clip_window_and_control	; 17
.get_sprites:		defw cmd_not_supported		; 18, not supported on a ZX Next
.get_sprite_patterns:	defw cmd_not_supported	; 19, not supported on a ZX Next
.get_port:			defw cmd_read_port	; 20
.write_port:		defw cmd_write_port	; 21
.exec_asm:			defw cmd_exec_asm	; 22
.interrupt_on_off:	defw cmd_interrupt_on_off	; 23
.get_supported_commands: defw cmd_get_supported_commands	; 24
.read_bank_mem:		defw cmd_read_bank_mem			; 25
.write_bank_mem:	defw cmd_write_bank_mem			; 26
.set_nextregs:		defw cmd_set_nextregs			; 27
.read_mem_blocks:	defw cmd_read_mem_blocks		; 28
.end

;.get_sprites:			defw 0	; not supported on a ZX Next
;.get_sprite_patterns:	defw 0	; not supported on a ZX Next

;.add_breakpoint:		defw 0		; not supported (see set_breakpoints/restore_mem)
;.remove_breakpoint:	defw 0	; not supported (see set_breakpoints/restore_mem)
;.add_watchpoint:		defw 0	; not supported
;.remove_watchpoint:	defw 0	; not supported

;.read_state:			defw 0	; not supported
;.write_state:			defw 0	; not supported




;===========================================================================
; Jumps to the correct command according the jump table.
; Parameters:
;	(receive_buffer.command) = the command, e.g. CMD_GET_CONFIG
; Changes:
;  NA
;===========================================================================
cmd_call:	; Get pointer to subroutine
	call get_cmd_pointer
	; jump to subroutine
	jp (hl)
get_cmd_pointer:	; For unit tests this is a separate function.
	; Check that command number is in range
	ld a,(receive_buffer.command)
	ld l,(cmd_jump_table.end-cmd_jump_table)/2
	sub l
	jr nc,.not_supported
	; Use table
	add l
	add a,a
	ld hl,cmd_jump_table
	add hl,a
	ldi a,(hl)
	ld h,(hl)
	ld l,a
	ret

.not_supported:
	ld hl,cmd_not_supported
	ret


;===========================================================================
; CMD not supported.
; Is called for a command that is not supported.
; Creates an error output.
; Changes:
;  NA
;===========================================================================
cmd_not_supported:
	; LOGPOINT [CMD] cmd_not_supported
	ld a,ERROR_CMD_NOT_SUPPORTED
    jp drain_main


;===========================================================================
; CMD_INIT
; Sends a response with the DZRP version.
; Changes:
;  NA
;===========================================================================
cmd_init:
	; LOGPOINT [CMD] cmd_init
	SEND_NTF_LOG "<<< CMD_INIT", 0
	; DBG_LOG 'i'
	call .inner
	; Reset slots to ZX128 default: ROM0, 5, 2, 0 => ROM0, ROM0, 10, 11, 4, 5, 0, 1
	; Only the backup is set. It is written to the MMU registers on continue.
	ld hl,.default_slots
	ld de,slot_backup
	ld bc,SLOT_BACKUP
	ldir
	; Reset error
	xor a
	ld (last_error),a
	; Reset nextreg selection
	ld (backup.io_next_reg),a	; A = 0
	; Reset border color
	ld (border_color),a	; A = 0
	; Program state
	ld a,PRGM_LOADING
	ld (prgm_state),a
    ; Enable flashing border
    call uart.flashing_border.enable
	; Afterwards start all over again / show the "UI"
    call init_and_show_ui  ; Also re-initializes copper break
	; Set priority
    nextreg REG_SPRITE_LAYER_SYSTEM, RSLS_SPRITES_VISIBLE|RSLS_LAYER_PRIORITY_SLU

.response:
	; Send length and seq-no
	ld de,PROGRAM_NAME.end-PROGRAM_NAME + 1+5
	call send_length_and_seqno
	; No error
	xor a
	call uart.write_tx_byte
	; Send config
	; DZRP version
	ld a,DZRP_VERSION.MAJOR
	call uart.write_tx_byte
	ld a,DZRP_VERSION.MINOR
	call uart.write_tx_byte
	ld a,DZRP_VERSION.PATCH
	call uart.write_tx_byte
	; Machine type: 4 = ZX Next
	ld a,4
	call uart.write_tx_byte
	; Send own program name and version
	ld hl,PROGRAM_NAME
.write_prg_name_loop:
	ldi a,(hl)
	call uart.write_tx_byte
	or a
	jr nz,.write_prg_name_loop
	ret

.default_slots:
	defb ROM_BANK, ROM_BANK, 10, 11, 4, 5, 0, 1

.inner:
	; Read version number
	ld hl,receive_buffer.payload
	ld de,3
	call receive_bytes
	; Read remote program name
.read_loop
	call uart.read_rx_byte
	or a
	jr nz,.read_loop
	ret


;===========================================================================
; CMD_GET_SUPPORTED_COMMANDS
; Sends a response with the supported commands.
; Changes:
;  NA
;===========================================================================
cmd_get_supported_commands:
	; LOGPOINT [CMD] cmd_get_supported_commands
	; Send response
	ld de,5
	call send_length_and_seqno
	; Send supported commands
	ld a,1101_1110b	; CMD_INIT - CMD_PAUSE
	call uart.write_tx_byte
	ld a,1111_1110b	; CMD_WRITE_MEM - CMD_LOOPBACK
	call uart.write_tx_byte
	ld a,1111_0011b	; CMD_GET_SPRITES_PALETTE - CMD_INTERRUPT_ON_OFF
	call uart.write_tx_byte
	ld a,0001_1111b	; CMD_GET_SUPPORTED_COMMANDS - CMD_READ_MEM_BLOCKS
	call uart.write_tx_byte
	ret



;===========================================================================
; CMD_CLOSE
; Closes the debug session.
; Changes:
;  NA
;===========================================================================
cmd_close:
	; LOGPOINT [CMD] cmd_close
	SEND_NTF_LOG "<<< CMD_CLOSE", 0

	; Send response
	ld de,1
	call send_length_and_seqno
	; Program state
	ld a,PRGM_IDLE
	ld (prgm_state),a
    ; Enable flashing border
    call uart.flashing_border.enable
	; Afterwards start all over again / show the "UI"
	jp main


;===========================================================================
; CMD_READ_REGS
; Reads all register and slot values and sends them in the response.
; Changes:
;  NA
;===========================================================================
cmd_get_registers:
	; LOGPOINT [CMD] cmd_get_regs
	; Send response
	ld de,38
	call send_length_and_seqno

	; Loop all register values
	ld hl,backup.pc
	ld de,-3
	ld b,14
.loop:
	push bc
	ldi a,(hl)
	call uart.write_tx_byte
	ld a,(hl)
	call uart.write_tx_byte
	; Next
	add hl,de
	pop bc
	djnz .loop

	; Now the slot values
	ld a,8	; 8 slots
	call uart.write_tx_byte

	; Send the banks of all 8 slots
	ld hl,slot_backup
	ld e,SLOT_BACKUP
.slot_loop:
	ldi a,(hl)
	call uart.write_tx_byte
	dec e
	jr nz,.slot_loop
	ret


;===========================================================================
; CMD_WRITE_REG
; Writes one register.
; Changes:
;  NA
;===========================================================================
cmd_set_register:
	; LOGPOINT [CMD] cmd_set_reg
	; Read rest of message
	ld hl,receive_buffer.payload
	ld de,3
	call receive_bytes
	; Execute command
	call cmd_set_register.inner
	; Send response
	ld de,1
	jp send_length_and_seqno

.inner:	; jump label for unit tests
	; Get value in DE
	ld hl,payload_set_reg.register_value+1
	ldd d,(hl)
	ldd e,(hl)
	; Which register
	ld a,(hl)	; hl=receive_buffer.register_number
	sub 13
	jr nc,.next2

	; Double register. A is -13 to -2
	neg ; A is 13 to 2
	add a,a	; a*2: 26 to 4
	ld hl,backup.hl2-4
	add hl,a
	ldi (hl),e
	ld (hl),d
	ret

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
; CMD_CONTINUE
; Continues debugged program execution.
; Restores the back'uped registers and jumps to the last
; execution point.
; Changes:
;  NA
;===========================================================================
cmd_continue:
	; LOGPOINT [CMD] cmd_continue
	SEND_NTF_LOG "<<< CMD_CONTINUE", 0

	; Read breakpoints etc. from message
	ld hl,receive_buffer.payload
	ld de,PAYLOAD_CONTINUE
	call receive_bytes

	; Send response
	ld de,1
	call send_length_and_seqno

	; Get breakpoints
	ld a,(payload_continue.bp1_enable)
	or a
	jr z,.bp2
	; Set temporary bp 1
	ld hl,(payload_continue.bp1_address)
	ld de,tmp_breakpoint_1
	call set_tmp_breakpoint
.bp2:
	ld a,(payload_continue.bp2_enable)
	or a
	jr z,.start
	; Set temporary bp 2
	ld hl,(payload_continue.bp2_address)
	ld de,tmp_breakpoint_2
	call set_tmp_breakpoint
.start:
	; Check program state
	ld a,(prgm_state)
	cp PRGM_LOADING
	jr nz,.not_loading
	; Loading finished: Set border color after loading
	; Set border to black (A is already 0)
	out (BORDER),a
    ; Disable flashing border
    call uart.flashing_border.disable
.not_loading:
	; Continue
	jp restore_registers


;===========================================================================
; CMD_PAUSE
; Acknowledges and send the pause notification to DeZog.
; Program state is set to PRGM_STOPPED.
; Changes:
;  NA
;===========================================================================
cmd_pause:
	; LOGPOINT [CMD] cmd_pause
	SEND_NTF_LOG "<<< CMD_PAUSE", 0

	; Send response: the sequence number alone
	ld de,1
	call send_length_and_seqno

	; Send pause notification
	ld d,BREAK_REASON.MANUAL_BREAK
	ld hl,0 ; bp address
	jp send_ntf_pause ; Also changes prgm_state to PRGM_STOPPED


;=============================================
; CMD_READ_MEM_BLOCKS
; Reads a few memory blocks.
; The memory banks of slot_backup are temporarily paged into
; SWAP_SLOT and read.
; Changes:
;  NA
;===========================================================================
cmd_read_mem_blocks:
	; LOGPOINT [CMD] cmd_read_mem_blocks
	; Read response length
	call uart.read_rx_word	; Result in hl, low word
	push hl
	call uart.read_rx_word  ; Result in hl, high word
	pop de	; Low word (read_rx_word changes DE)
	; Send length of response and sequence number already
	call send_4bytes_length_and_seqno

	; Calculate count of blocks
	ld hl,(receive_buffer.length)	; Only the low word is used. This would allow for 64k/4 = 16k blocks
	dec hl	; The response length field (-1 so that Carry is set correctly in loop below)

	; Now loop over all mem blocks: address/size, address/size, ...
.loop:
	; Check if count is < 0
	or a
	ld de,4
	sbc hl,de
	ret c

	push hl ; Block count
	; Read address and size from message
	call uart.read_rx_word	; Result in hl, address
	push hl
	call uart.read_rx_word	; Result in hl, size
	ex de,hl ; de = size
	pop hl	; Restore address of the current block

	; Read block and sent data through uart
	ld bc,.read
	call memory_loop

 	; Restore block count
	pop hl
	jr .loop

; The inner call
.read:
	; Get byte
	ld a,(hl)
	; Send
	jp uart.write_tx_byte


;===========================================================================
; CMD_READ_BANK_MEM
; Reads memory from the specified bank.
; See bank_mem_loop for address handling and ROM access.
; Changes:
;  NA
;===========================================================================
cmd_read_bank_mem:
	; LOGPOINT [CMD] cmd_read_bank_mem
	; Read address and size from message
	ld hl,receive_buffer.payload
	ld de,PAYLOAD_READ_BANK_MEM
	call receive_bytes

	; Send response
	ld hl,(payload_read_bank_mem.mem_size)
	ld de,1		; Add 1 for the sequence number
	add hl,de
	ex hl,de
	jr c,.hl_correct	; If C then hl already contains 1.
	ld l,0	; If NC then we need to reset HL to 0.
.hl_correct:
	call send_4bytes_length_and_seqno

	; Get bank, start and size
	ld a,(payload_read_bank_mem.bank)
	ld hl,(payload_read_bank_mem.mem_start)
	ld de,(payload_read_bank_mem.mem_size)
	; Read bytes and send them through the UART
	ld bc,cmd_read_mem_blocks.read
	jp bank_mem_loop


;===========================================================================
; CMD_WRITE_MEM
; Writes a memory area.
; The memory banks of slot_backup are temporarily paged into
; SWAP_SLOT and written.
; Changes:
;  NA
;===========================================================================
cmd_write_mem:
	; LOGPOINT [CMD] cmd_write_mem
	; Read address from message
	ld hl,receive_buffer.payload
	ld de,PAYLOAD_WRITE_MEM
	call receive_bytes

	; Read length and subtract 3
	ld hl,(receive_buffer.length)
	ld de,-PAYLOAD_WRITE_MEM
	add hl,de
	ex de,hl
	; Read bytes from UART and put into memory
	ld hl,(payload_write_mem.mem_start)
	ld bc,.write
	call memory_loop

.send_response:
 	; Send response
 	ld de,1
 	jp send_length_and_seqno

; The inner call
.write:
	; Get byte
	push de
	call uart.read_rx_byte
	; Write
	ld (hl),a
	pop de
	ret

;===========================================================================
; CMD_WRITE_BANK_MEM
; Writes data to the specified bank.
; See bank_mem_loop for address handling and ROM access.
; Changes:
;  NA
;===========================================================================
cmd_write_bank_mem:
	; LOGPOINT [CMD] cmd_write_bank_mem
	; Read address from message
	ld hl,receive_buffer.payload
	ld de,PAYLOAD_WRITE_BANK_MEM
	call receive_bytes

	; Read length and subtract 3
	ld hl,(receive_buffer.length)
	ld de,-PAYLOAD_WRITE_BANK_MEM
	add hl,de
	ex de,hl ; de = length to read and write
	ld hl,(payload_write_bank_mem.mem_start)
	ld a,(payload_write_bank_mem.bank)
	; Read bytes from UART and write them to the bank
	ld bc,cmd_write_mem.write
	call bank_mem_loop
	jr cmd_write_mem.send_response


;===========================================================================
; CMD_SET_NEXTREGS
; Writes a list of (register, value) pairs to the ZX Next registers.
; The values have to persist when the debugged program is continued.
; Therefore registers that are changed by the debugger and restored
; on continue are handled especially:
; - REG_TURBO_MODE: only backup.speed is changed (debugger keeps 28MHz).
; - REG_MMU+0..7: only slot_backup is changed (the MMU registers belong
;   to the debugger while debugging, they are restored on continue).
; Note: With nextreg command $69 the Layer 2 enabled bit could be changed.
; Therefore the layer_2_port is restored on entry of this command and saved
; on exit.
; Changes:
;  NA
;===========================================================================
cmd_set_nextregs:
	; LOGPOINT [CMD] cmd_set_nextregs
	; In case nextreg $69 is called
	call restore_layer2_rw
	; Number of pairs = length/2
	ld de,(receive_buffer.length)	; Read only the lower bytes
	srl d :	rr e	; de /= 2

.loop:
	; Check for end
	ld a,e
	or d
	jr z,.loop_end
	push de
	; Get register
	call uart.read_rx_byte
	; Check for special regs
	cp REG_TURBO_MODE
	jr z,.speed
	ld e,a
	and 0xF8
	cp REG_MMU	; REG_MMU+0..7
	ld a,e
	jr z,.slot
	; "Normal" register
	ld (.nextreg_register+2),a	; Modify opcode
	; Get value
	call uart.read_rx_byte

	; Execute nextreg
.nextreg_register:
	nextreg 0x00,a	; Self-modifying code

.continue:
	pop de
	dec de
	jr .loop

.loop_end:
	; In case nextreg $69 has been called
	call save_layer2_rw
	; Send response
	ld de,1
	jp send_length_and_seqno

.speed:
	; Get value
	call uart.read_rx_byte
	; Store
	ld (backup.speed),a
	jr .continue

.slot:
	; Get pointer to slot backup
	sub REG_MMU
	ld hl,slot_backup
	add hl,a
	; Get value
	call uart.read_rx_byte
	; Store
	ld (hl),a
	jr .continue


;===========================================================================
; CMD_SET_SLOT
; Sets a 8k-banks/slot association.
; Only slot_backup is changed. It is written to the MMU registers on
; continue.
; Changes:
;  NA
;===========================================================================
cmd_set_slot:
	; LOGPOINT [CMD] cmd_set_slot

	; Get slot
	call uart.read_rx_byte
	ld l,a
	; Get bank
	call uart.read_rx_byte
	cp 0xFE
	jr nz,.no_fe
	inc a	; Change 0xFE to 0xFF
.no_fe:
	; A = bank
	ld e,a
	; Store in slot backup
	ld a,l	; slot
	and 0x07
	ld hl,slot_backup
	add hl,a
	ld (hl),e	; LOGPOINT cmd_set_slot bank: ${E}
	; Send response
	ld de,2
	call send_length_and_seqno
	xor a	; no error
	jp uart.write_tx_byte


;===========================================================================
; CMD_GET_NEXTREG
; Reads the tbblue register.
; Changes:
;  NA
;===========================================================================
cmd_get_nextreg:
	; LOGPOINT [CMD] cmd_get_nextreg
	; Send response
	ld de,2
	call send_length_and_seqno
	; Read register number
	call uart.read_rx_byte	; Register number
	call read_tbblue_reg	; Result in A
	; Send
	jp uart.write_tx_byte


;===========================================================================
; CMD_SET_BREAKPOINTS
; Sets all breakpoints.
; Changes:
;  NA
;===========================================================================
cmd_set_breakpoints:
	; LOGPOINT [CMD] cmd_set_breakpoints
	; Calculate the count
	ld hl,(receive_buffer.length)	; Read only the lower bytes
	; Divide by 3
	ld e,3
	call div_hl_e	; hl = hl/3
	; Send response
	ld de,hl
	push de
	inc de
	call send_length_and_seqno
	pop de 	; count

.loop:
	; Check for end
	ld a,e
	or d
	ret z
	; Loop
	push de
	; Get breakpoint address
	call uart.read_rx_byte
	ld l,a
	call uart.read_rx_byte
	ld h,a
	; Get bank+1
	call uart.read_rx_byte
	or a
	jr z,.handle_64k_address

	; Handle long address
	dec a	; A = bank
	; Page in bank
	call page_in_bank
	jr .set_bp

.handle_64k_address:
	; Normal 64k address: page in bank of the debugged program
	call page_in_debugged_prgm_bank

.set_bp:
	; Get memory
	ld a,(hl)	; LOGPOINT [CMD] BP=${HL:hex16}h, ${HL} (SWAP)
	; Set breakpoint
	ld (hl),BP_INSTRUCTION

	; Send memory
	call uart.write_tx_byte
	pop de
	dec de
	jr .loop



;===========================================================================
; CMD_RESTORE_MEM
; Restores the memory at the addresses.
; Note: memory is only overwritten if the value is BP_INSTRUCTION
; (RST 0). For the case that the debugged program overwrites the
; breakpoint (self-modifying code).
; Of course, it is anyhow no good idea to modify code at a
; breakpoint, but dezogif tries to do its best to be as unintrusive
; as possible.
; Changes:
;  NA
;===========================================================================
cmd_restore_mem:
	; LOGPOINT [CMD] cmd_restore_mem
	; Send response
	ld de,1
	call send_length_and_seqno

	; Calculate the count
	ld de,(receive_buffer.length)	; Read only the lower bytes

.loop:
	; Check for end
	ld a,e
	or d
	ret z
	; Loop
	push de
	; Get memory address
	call uart.read_rx_byte
	ld l,a
	call uart.read_rx_byte
	ld h,a
	; Get bank+1
	call uart.read_rx_byte
	or a
	jr z,.handle_64k_address

	; Handle long address
	dec a	; A = bank
	; Page in bank
	call page_in_bank
	jr .restore

.handle_64k_address:
	; Normal 64k address: page in bank of the debugged program
	call page_in_debugged_prgm_bank

.restore:
	call .read_and_restore

	; Next address
	pop de
	add de,-4
	jr .loop

.read_and_restore:
	; Get value
	call uart.read_rx_byte
	; Set memory
	ld e,a
	ld a,(hl)
	cp BP_INSTRUCTION
	ret nz	; Skip restore if not BP_INSTRUCTION (RST 0)
	ld (hl),e
	ret


;===========================================================================
; CMD_LOOPBACK
; The received data is looped back to the sender.
; If Async break is enabled, the copper will be turned on before the
; loopback operation.
; After the loopback operation, the copper will keep running
; or not depending on the state of copper_break_enabled.
; It is not turned off afterwards, because more loopback
; operations may follow.
;
; Changes:
;  NA
;===========================================================================
cmd_loopback:
	; LOGPOINT [CMD] cmd_loopback
	DBG_LOG 'L'
	; Page in bank for storage
	nextreg REG_MMU+SWAP_SLOT,LOOPBACK_BANK
	; Get length
	ld de,(receive_buffer.length)
	DBG_LOG_NUMBER16 de
	ld hl,0x2000
	or a
	sbc hl,de
	jr c,.size_too_big

	; Read all data in swap slot
	ld hl,SWAP_ADDR
	jr .rcv_check_end

.rcv_loop:
	; Loop
	push de
	; Get value
	call uart.read_rx_byte
	; Store
	ldi (hl),a
	; Next
	pop de
	dec de
.rcv_check_end:
	; Check for end
	ld a,e
	or d
	jr nz,.rcv_loop

	; Send response
	ld de,(receive_buffer.length)
	inc de
	call send_length_and_seqno

	; Send all data
	ld de,(receive_buffer.length)
	ld hl,SWAP_ADDR
	jr .send_check_end

.send_loop:
	; Loop
	; Get value
	ldi a,(hl)
	; Send
	call uart.write_tx_byte
	; Next
	dec de
.send_check_end:
	; Check for end
	ld a,e
	or d
	jr nz,.send_loop

	; Continue
	pop af	; swallow return address
	jp main_loop.continue

.size_too_big:
	ld a,ERROR_LOOPBACK_SIZE
	jp drain_main

;===========================================================================
; CMD_GET_SPRITES_PALETTE
; Returns the values of the requested palette.
; Changes:
;  NA
;===========================================================================
cmd_get_sprites_palette:
	; LOGPOINT [CMD] cmd_get_sprites_palette
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
	or 00100000b
	ld l,a
	; Get palette index
	call uart.read_rx_byte
	bit 0,a
	ld a,l
 	jr z,.palette_0
	or 01000000b	; Select palette 1
.palette_0:
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
	call uart.write_tx_byte
	ld a,REG_PALETTE_VALUE_16  ; color9th
	call read_tbblue_reg ; Result in A
	call uart.write_tx_byte
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
; CMD_GET_SPRITES_CLIP_WINDOW_AND_CONTROL
; Returns the sprites clip window and the control byte (regsiter (0x15).
; Changes:
;  NA
;===========================================================================
cmd_get_sprites_clip_window_and_control:
	; LOGPOINT [CMD] cmd_get_sprites_clip_window_and_control
	; Prepare response
	ld de,6
	call send_length_and_seqno

    ; Get index
	ld a,REG_CLIP_WINDOW_CONTROL
	call read_tbblue_reg
	rra : rra
	and 011b	; A contains the index

	; Get xl, xr, yt or yb
	ld d,4
.loop:	; 4x: for xl, xr, yt and yb
	push af
	ld a,REG_CLIP_WINDOW_SPRITES
	call read_tbblue_reg
	; Increase index by writing the same value
	nextreg REG_CLIP_WINDOW_SPRITES, a
	ld e,a
	; Store
	pop af
	ld hl,tmp_clip_window
	add hl,a
	ld (hl),e
	inc a
	and 011b
	dec d
	jr nz,.loop

	; Send xl, xr, yt or yb
	ld d,4
	ld hl,tmp_clip_window
.send_loop:
	ldi a,(hl)
	call uart.write_tx_byte 	; Send xl, xr, yt or yb
	dec d
	jr nz,.send_loop

	; Get sprite control byte
	ld a,REG_SPRITE_LAYER_SYSTEM
	call read_tbblue_reg
	jp uart.write_tx_byte 	; Send sprite control byte



;===========================================================================
; CMD_READ_PORT
; Reads a value from a port.
; Changes:
;  NA
;===========================================================================
cmd_read_port:
	; LOGPOINT [CMD] cmd_read_port
	; Read port (low byte)
	call uart.read_rx_byte
	ld l,a
	; Read port (high byte)
	call uart.read_rx_byte
	ld b,a
	; Read value from the port
	ld c,l
	in a,(c)

	; Send response
	push af
	ld de,2
	call send_length_and_seqno
	; Write port value
	pop af
	jp uart.write_tx_byte


;===========================================================================
; CMD_WRITE_PORT
; Writes a value to a port.
; Notes:
; - BORDER additionally saves the value to be set when border flashing is disabled.
; - The layer_2_port could be changed which changes the memory mapping.
; Therefore the layer_2_port is restored on entry of this command and saved
; on exit.
; - The same is done for the slots (e.g. port 0x7FFD changes the MMU registers).
; Changes:
;  NA
;===========================================================================
cmd_write_port:
	; LOGPOINT [CMD] cmd_write_port
	; In case the memory mapping is changed
	call restore_slots
	; In case layer_2_port is changed
	call restore_layer2_rw
	; Read port (low byte)
	call uart.read_rx_byte
	ld l,a
	; Read port (high byte)
	call uart.read_rx_byte
	ld h,a
	; Read value
	call uart.read_rx_byte
	; Write to the port
	ld bc,hl
	out (c),a
	; Check for border
	bit 0,c	; Check only A0 of the address bits
	jr nz,.border_not_changed

	; Remember border value
	ld (border_color),a

.border_not_changed:
	; In case layer_2_port has been changed
	call save_layer2_rw
	; In case the memory mapping has been changed
	call save_slots
	; Send response
	ld de,1
	jp send_length_and_seqno


;===========================================================================
; CMD_EXEC_ASM
; Executes a small assembler program.
; The program is executed with the memory mapping of the debugged program.
; Changes to the mapping (e.g. by nextreg or port 0x7FFD) are kept.
; Changes:
;  NA
;===========================================================================
cmd_exec_asm:
	; LOGPOINT [CMD] cmd_exec_asm
	ld de,(receive_buffer.length)	; assembler code size
	ld hl,PAYLOAD_EXEC_ASM-1	; 1 for the RET
	or a
	sbc hl,de
	jr nc,.buffer_size_ok

	; Code size too big -> return error
	ld hl,0
	push hl, hl, hl, hl
	ld a,1	; error: 1 = buffer size too big
	jp .send_response

.buffer_size_ok:
	; Load the context (ignored) and the assembler code
	ld hl,receive_buffer.payload
	call receive_bytes
	; End the code with a RET
	ld (hl),0xC9

	; Use the memory mapping of the debugged program
	call restore_slots

	; Execute
	call payload_exec_asm.code

	; Save all registers
	push hl, de, bc, af

	; In case the memory mapping has been changed
	call save_slots

	/*
	; Via CMD_EXEC_ASM it is possible to change registers that will keep
	; their values even when starting the debugged program with CMD_CONTINUE.
	; Read layer_2 port;
	ld bc,LAYER_2_PORT
	in a,(c)
	ld (backup.layer_2_port),a
	; Read CPU speed
	ld a,REG_TURBO_MODE
	call read_tbblue_reg
	ld (backup.speed),a
	; Switch to 28Mhz
	nextreg REG_TURBO_MODE,RTM_28MHZ
	*/

	; No error
	xor a

.send_response:
	; a contains the error code.
	push af
	; Send response
	ld de,10
	call send_length_and_seqno
	; Send error code (=no error)
	pop af	; error code
	call uart.write_tx_byte
	; Send AF
	pop hl	; H=A, L=F
	call .write_reg
	; Send BC
	pop hl	; H=B, L=C
	call .write_reg
	; Send DE
	pop hl	; H=D, L=E
	call .write_reg
	; Send HL
	pop hl	; H=H, L=L
	; Flow through

.write_reg:
	ld a,l
	call uart.write_tx_byte	; low byte
	ld a,h
	jp uart.write_tx_byte	; high byte



;===========================================================================
; CMD_INTERRUPT_ON_OFF
; Turns the interrupt on or off.
; Changes:
;  NA
;===========================================================================
cmd_interrupt_on_off:
	; LOGPOINT [CMD] cmd_exec_asm
	; Read: off=0 or on
	call uart.read_rx_byte
	ld hl,backup.interrupt_state
	or a
	jr z,.disable

	; Enable interrupt
	set 2,(hl)

.send_response:
	; Send response
	ld de,1
	jp send_length_and_seqno

.disable:
	; Disable interrupt
	res 2,(hl)
	jr .send_response
