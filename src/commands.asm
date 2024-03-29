;===========================================================================
; commands.asm
;
;
;===========================================================================



;===========================================================================
; Structs
;===========================================================================

	; Used in backup/restore of the slots.
	STRUCT SLOT_BACKUP
slot0:		defb	; Saved when entering debugging (RST 0), restored on continue. At the moment this must be 0xFF=ROM. I.e. saving/restoring has no real meaning. In future, when using UART interrupts, this will make more sense.
slot7:		defb	; Saved when entering debugging (RST 0), restored on continue.
tmp_slot:	defb	; Normally SWAP_SLOT but could be also other.
	ENDS



;===========================================================================
; Const data.
;===========================================================================

; DZRP version 2.1.0
DZRP_VERSION.MAJOR:		equ 2
DZRP_VERSION.MINOR:		equ 1
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
.write_bank:		defw cmd_write_bank			; 5
.continue:			defw cmd_continue			; 6
.pause:				defw cmd_not_supported		; 7, not supported on a ZX Next
.read_mem:			defw cmd_read_mem			; 8
.write_mem:			defw cmd_write_mem			; 9
.set_slot:			defw cmd_set_slot			; 10
.get_tbblue_reg:	defw cmd_get_tbblue_reg		; 11
.set_border:		defw cmd_set_border			; 12
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
	ld a,(receive_buffer.command)
	; Check that command number is in range
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
; Sends a response with the supported features.
; Changes:
;  NA
;===========================================================================
cmd_init:
	; LOGPOINT [CMD] cmd_init
	; DBG_LOG 'i'
	call .inner
	; Reset slots to ZX128 default: ROM0, 5, 2, 0 => ROM0, ROM0, 10, 11, 4, 5, 0, 1
	ld hl,slot_backup
	ldi (hl),ROM_BANK	; Slot 0
	ld (hl),1	; Slot 7
	; Other slots are set directly
	nextreg REG_MMU+1,ROM_BANK
	nextreg REG_MMU+2,10
	nextreg REG_MMU+3,11
	nextreg REG_MMU+4,4
	nextreg REG_MMU+5,5
	nextreg REG_MMU+6,0
	; Reset error
	xor a
	ld (last_error),a
	; Program state
	ld a,PRGM_LOADING
	ld (prgm_state),a
    ; Enable flashing border
    call uart_flashing_border.enable
	; Afterwards start all over again / show	; Afterwards start all over again / show the "UI"
    call show_ui

.response:
	; Send length and seq-no
	ld de,PROGRAM_NAME.end-PROGRAM_NAME + 1+5
	call send_length_and_seqno
	; No error
	xor a
	call write_uart_byte
	; Send config
	; DZRP version
	ld a,DZRP_VERSION.MAJOR
	call write_uart_byte
	ld a,DZRP_VERSION.MINOR
	call write_uart_byte
	ld a,DZRP_VERSION.PATCH
	call write_uart_byte
	; Machine type: 4 = ZX Next
	ld a,4
	call write_uart_byte
	; Send own program name and version
	ld hl,PROGRAM_NAME
.write_prg_name_loop:
	ldi a,(hl)
	call write_uart_byte
	or a
	jr nz,.write_prg_name_loop
	ret

.inner:
	; Read version number
	ld hl,receive_buffer.payload
	ld de,3
	call receive_bytes
	; Read remote program name
.read_loop
	call read_uart_byte
	or a
	jr nz,.read_loop
	ret


;===========================================================================
; CMD_CLOSE
; Closes the debug session.
; Changes:
;  NA
;===========================================================================
cmd_close:
	; LOGPOINT [CMD] cmd_close
	; Send response
	ld de,1
	call send_length_and_seqno
	; Program state
	ld a,PRGM_IDLE
	ld (prgm_state),a
    ; Enable flashing border
    call uart_flashing_border.enable
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
	call write_uart_byte
	ld a,(hl)
	call write_uart_byte
	; Next
	add hl,de
	pop bc
	djnz .loop

	; Now the slot values
	ld a,8	; 8 slots
	call write_uart_byte

	; Send the first 7 slots
	ld de,256*REG_MMU+7	; Load D and E at the same time
.slot_loop:
	; Get bank for slot
	ld a,d
	call read_tbblue_reg	; Result in A
	; Send
	call write_uart_byte
	inc d
	dec e
	jr nz,.slot_loop

	; Get and send slot 7
	ld a,(slot_backup.slot7)
	; LOGPOINT cmd_get_slots slot0: ${A}
	jp write_uart_byte


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
; CMD_WRITE_BANK
; Writes one memory bank.
; If MAIN_BANK should be written an error occurs.
; Changes:
;  NA
;===========================================================================
cmd_write_bank:
	; LOGPOINT [CMD] cmd_write_bank
	; Execute command
	call cmd_write_bank.inner
	; Send response
	ld de,3
	call send_length_and_seqno
	; No error
	xor a
	call write_uart_byte
	; No error string
	jp write_uart_byte


.inner:
	; Read bank number of message
	call read_uart_byte

	; Check if it is own bank
	cp MAIN_BANK
	jr z,error_write_main_bank

	; Remember current bank for slot
	ld e,a
	call save_swap_slot
	ld a,e

	; Change bank for slot
	nextreg REG_MMU+SWAP_SLOT,a

	; Read bytes from UART and put into bank
	ld hl,SWAP_ADDR		;.slot<<13	; Start address
	ld de,(receive_buffer.length)	; Bank size
	dec de
	call receive_bytes

	; Restore slot/bank (D)
	jp restore_swap_slot

error_write_main_bank:
	ld a,ERROR_WRITE_MAIN_BANK
    jp drain_main


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
	ld a,(backup.border_color)
	out (BORDER),a
    ; Disable flashing border
    call uart_flashing_border.disable
.not_loading:
	; Continue
	jp restore_registers


;===========================================================================
; CMD_READ_MEM
; Reads a memory area.
; Special is that if slot 7 area is read,
; then the memory bank of slot_backup.slot7 is temporarily paged into
; SWAP_SLOT and read.
; Changes:
;  NA
;===========================================================================
cmd_read_mem:
	; LOGPOINT [CMD] cmd_read_mem
	; Read address and size from message
	ld hl,receive_buffer.payload
	ld de,PAYLOAD_READ_MEM
	call receive_bytes

	; Send response
	ld hl,(payload_read_mem.mem_size)
	ld de,1		; Add 1 for the sequence number
	add hl,de
	ex hl,de
	jr c,.hl_correct	; If C then hl already contains 1.
	ld l,0	; If NC then we need to reset HL to 0.
.hl_correct:
	call send_4bytes_length_and_seqno

.inner:		; For unit testing
	ld de,(payload_read_mem.mem_size)
	ld hl,(payload_read_mem.mem_start)
	ld bc,cmd_read_mem.read
	jp memory_loop

; The inner call
cmd_read_mem.read:
	; Get byte
	ld a,(hl)
	; Send
	jp write_uart_byte


;===========================================================================
; CMD_WRITE_MEM
; Writes a memory area.
; Special is that if slot 7 area is read,
; then the memory bank of slot_backup.slot7 is temporarily paged into
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

.inner:
	call save_swap_slot
	; Read length and subtract 3
	ld hl,(receive_buffer.length)
	ld de,-PAYLOAD_WRITE_MEM
	add hl,de
	ex de,hl
	; Read bytes from UART and put into memory
	ld hl,(payload_write_mem.mem_start)
	ld bc,.write
	call memory_loop

 	; Send response
 	ld de,1
 	jp send_length_and_seqno


; The inner call
.write:
	; Get byte
	push de
	call read_uart_byte
	; Write
	ld (hl),a
	pop de
	ret


;===========================================================================
; CMD_SET_SLOT
; Sets a 8k-banks/slot association.
; Changes:
;  NA
;===========================================================================
cmd_set_slot:
	; LOGPOINT [CMD] cmd_set_slot

	; Get slot
	call read_uart_byte
	ld l,a
	; Get bank
	call read_uart_byte
	cp 0xFE
	jr nz,.no_fe
	inc a	; Change 0xFE to 0xFF
.no_fe:
	; A = bank

	; Get slot
	inc l
	bit 3,l	; check for 0
	jr z,.not_slot7

	; LOGPOINT cmd_set_slot slot0: ${A}

	; Slot 7 is handled especially: don't change the slot but only the backed up value
	ld (slot_backup.slot7),a
	jr .end

.not_slot7:
	ld h,a	; H = bank
	dec l
	ld a,l	; slot
	add a,REG_MMU
	ld (.nextreg_register+2),a	; Modify opcode
	ld a,h	; A = bank
.nextreg_register:
	nextreg 0x00,a	; Self-modifying code
.end:
	; Send response
	ld de,2
	call send_length_and_seqno
	xor a	; no error
	jp write_uart_byte

;.error:
;	call read_uart_byte	; read dummy value
;	ld a,1	; error
;	jp write_uart_byte


;===========================================================================
; CMD_GET_TBBLUE_REG
; Reads the tbblue register.
; Changes:
;  NA
;===========================================================================
cmd_get_tbblue_reg:
	; LOGPOINT [CMD] cmd_get_tbblue_reg
	; Send response
	ld de,2
	call send_length_and_seqno
	; Read register number
	call read_uart_byte	; Register number
	call read_tbblue_reg	; Result in A
	; Send
	jp write_uart_byte


;===========================================================================
; CMD_SET_BORDER
; Sets the border color.
; Changes:
;  NA
;===========================================================================
cmd_set_border:
	; LOGPOINT [CMD] cmd_set_border
	; Read border color
	call read_uart_byte
	ld (backup.border_color),a
	; Send response
	ld de,1
	jp send_length_and_seqno


;===========================================================================
; CMD_SET_BREAKPOINTS
; Sets all breakpoints.
; Changes:
;  NA
;===========================================================================
cmd_set_breakpoints:
	; LOGPOINT [CMD] cmd_set_breakpoints
	call save_swap_slot
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
	call read_uart_byte
	ld l,a
	call read_uart_byte
	ld h,a
	; Get bank+1
	call read_uart_byte
	or a
	jr z,.handle_64k_address

	; Handle long address
	dec a	; A = bank
	; Page in bank in upper memory
	jr .page_in_bank

.handle_64k_address:
	; Normal 64k address:
	; Check memory area
	cp HIGH MAIN_ADDR	; 0xE000
	jr c,.normal

	; Page in bank
	ld a,(slot_backup.slot7)
.page_in_bank:
	nextreg REG_MMU+SWAP_SLOT,a
	ld a,h
	and 0x1F
	add HIGH SWAP_ADDR	; 0xC0
	ld h,a
	; Get memory
	ld a,(hl)	; LOGPOINT [CMD] BP=${HL:hex}h, ${HL} (SWAP)
	; Set breakpoint
	ld (hl),BP_INSTRUCTION

	; Restore slot/bank
	ld e,a
	call restore_swap_slot

	; Restore a
	ld a,e
	jr .next

.normal:
	; Get memory
	ld a,(hl)	; LOGPOINT [CMD] BP=${HL:hex}h, ${HL}
	; Set breakpoint
	ld (hl),BP_INSTRUCTION

.next:
	; Send memory
	call write_uart_byte
	pop de
	dec de
	jr .loop



;===========================================================================
; CMD_RESTORE_MEM
; Restores the memory at the addresses.
; Changes:
;  NA
;===========================================================================
cmd_restore_mem:
	; LOGPOINT [CMD] cmd_restore_mem
	;call save_rom_slots
	call save_swap_slot
	; Send response
	ld de,1
	call send_length_and_seqno

	; Calculate the count
	ld de,(receive_buffer.length)	; Read only the lower bytes

.loop:
	; Check for end
	ld a,e
	or d
	;jp z,restore_rom_slots	; Returns
	jp z,restore_swap_slot	; Returns
	; Loop
	push de
	; Get memory address
	call read_uart_byte
	ld l,a
	call read_uart_byte
	ld h,a
	; Get bank+1
	call read_uart_byte
	or a
	jr z,.handle_64k_address

	; Handle long address
	dec a	; A = bank
	; Page in bank in upper memory
	jr .page_in_bank

.handle_64k_address:
	; Check memory area
	cp HIGH MAIN_ADDR	; 0xE000
	jr c,.normal

	ld a,(slot_backup.slot7)
.page_in_bank:
	nextreg REG_MMU+SWAP_SLOT,a
	ld a,h
	and 0x1F
	add HIGH SWAP_ADDR	; 0xC0
	ld h,a
	; Get value
	call read_uart_byte
	; Set memory
	ld (hl),a

	; Restore slot/bank
	ld e,a
	call restore_swap_slot

	; Restore a
	ld a,e
	jr .next

.normal:
	; Get value
	call read_uart_byte
	; Set memory
	ld (hl),a

.next:
	; Next address
	pop de
	add de,-4
	jr .loop



;===========================================================================
; CMD_LOOPBACK
; The received data is looped back to the sender.
; Changes:
;  NA
;===========================================================================
cmd_loopback:
	; LOGPOINT [CMD] cmd_loopback
	; Save swap slot
	call save_swap_slot

	; Page in bank for storage
	nextreg REG_MMU+SWAP_SLOT,LOOPBACK_BANK
	; Get length
	ld de,(receive_buffer.length)

	; Read all data in swap slot
	ld hl,SWAP_ADDR
	jr .rcv_check_end

.rcv_loop:
	; Loop
	push de
	; Get value
	call read_uart_byte
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
	call write_uart_byte
	; Next
	dec de
.send_check_end:
	; Check for end
	ld a,e
	or d
	jr nz,.send_loop

	; Restore slot
	call restore_swap_slot
	; Continue
	pop af	; swallow return address
	jp main_loop.continue


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
	call read_uart_byte
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
	call write_uart_byte 	; Send xl, xr, yt or yb
	dec d
	jr nz,.send_loop

	; Get sprite control byte
	ld a,REG_SPRITE_LAYER_SYSTEM
	call read_tbblue_reg
	jp write_uart_byte 	; Send sprite control byte



;===========================================================================
; CMD_READ_PORT
; Reads a value from a port.
; Changes:
;  NA
;===========================================================================
cmd_read_port:
	; LOGPOINT [CMD] cmd_write_port
	; Read port (low byte)
	call read_uart_byte
	ld l,a
	; Read port (high byte)
	call read_uart_byte
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
	jp write_uart_byte


;===========================================================================
; CMD_WRITE_PORT
; Writes a value to a port.
; Changes:
;  NA
;===========================================================================
cmd_write_port:
	; LOGPOINT [CMD] cmd_write_port
	; Read port (low byte)
	call read_uart_byte
	ld l,a
	; Read port (high byte)
	call read_uart_byte
	ld h,a
	; Read value
	call read_uart_byte
	; Write to the port
	ld bc,hl
	out (c),a
	; Send response
	ld de,1
	jp send_length_and_seqno


;===========================================================================
; CMD_EXEC_ASM
; Executes a small assembler program.
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

	; Execute
	call payload_exec_asm.code

	; Save all registers
	push hl, de, bc, af
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
	call write_uart_byte
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
	call write_uart_byte	; low byte
	ld a,h
	jp write_uart_byte	; high byte



;===========================================================================
; CMD_INTERRUPT_ON_OFF
; Turns the interrupt on or off.
; Changes:
;  NA
;===========================================================================
cmd_interrupt_on_off:
	; LOGPOINT [CMD] cmd_exec_asm
	; Read: off=0 or on
	call read_uart_byte
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
