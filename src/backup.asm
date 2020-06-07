;===========================================================================
; backup.asm
;
; Stores the registers of the debugged program for later use
; and for restoration.
;===========================================================================

    
;===========================================================================
; Constants
;===========================================================================
    


;===========================================================================
; Save all registers.
; Also changes stack pointer.
; Parameters:
;  - A = The memory bank to restore at USED_SLOT
;  - F = contains the interrupt state in P/V (PE=enabled)
;  - Stack:
;    -2 = return address (return to caller)
;    -4 = AF
;    -6 = caller of breakpoint (RST) +1
; Returns:
;  SP = debug_stack_top after RET
; ===========================================================================
save_registers:
;TODO: The interrupt recognition has to be added here similar to save_registers_with_dec_pc

	; Save without decrementing PC
	ld (backup.hl),hl
	pop hl  ; Save return address to HL
	ld (save_registers_common.ret_jump+1),hl	; self.modifying code, used instead of a return

	; Get caller address (+3 for CALL) of dbg_check_for_message
	pop hl	
	jr save_registers_common

save_registers_with_dec_pc:
	; Save
	ld (backup.hl),hl
	pop hl  ; Save return address to HL
	ld (save_registers_common.ret_jump+1),hl	; self.modifying code, used instead of a return

	; Store interrupt state and bank
	push af
	pop hl 
	ld a,l
	ld (backup.interrupt_state),a

	; Restore AF
	pop af 

	; Get caller address (+1 for RST) of enter_breakpoint
	pop hl	
	dec hl
save_registers_common:
	ld (backup.pc),hl

	; Save stack pointer (is already corrected because of 'pop hl')
	ld (backup.sp),sp
	
	; Use new stack
	ld sp,backup.af+2

	; Save registers
	push af
	push bc
	push de
	
	;push hl
	dec sp		; Instead of PUSH HL (hl is already saved)
	dec sp

	push ix
	push iy

	; Switch registers
	exx
	ex af,af'

	push af
	push bc
	push de
	push hl

	; I and R register
	ld a,r
	ld l,a
	ld a,i
	ld h,a
	push hl
	
	; Save IM, TODO: doesn't make sense
	ld hl,0
	push hl

	; Restore hl2
	;ld hl,(backup.hl2)

	; Switch back registers
	ex af,af'
	exx
	; End of register saving through pushing

	; Save clock speed
	ld a,REG_TURBO_MODE
	call read_tbblue_reg
	ld (backup.speed),a

	; Save border
	in a,(BORDER)
	ld (backup.border_color),a

.ret_jump:
	jp 0x0000	; Self-modifying code
	


;===========================================================================
; Restore all registers and jump to the stored PC.
; Parameters:
;  SP = points to debug_stack_top-2 (i.e. the return address)
; ===========================================================================
restore_registers:
	; Skip IM
	ld sp,backup.r

	; I and R register
	pop hl
	ld a,l
	ld r,a
	ld a,h
	ld i,a
	
	; Switch registers
	exx
	ex af,af'

	pop hl
	pop de
	pop bc
	pop af

	; Switch back registers
	ex af,af'
	exx

	pop iy
	pop ix
	pop hl		; Will be loaded later again
	pop de
	pop bc

	; Restore border color
	ld a,(backup.border_color)
	out (BORDER),a

	; Restore clock speed
	ld a,(backup.speed)
	nextreg REG_TURBO_MODE,a

	; Restore AF
	pop af

	; Correct PC on stack (might have been changed by DeZog)
	ld hl,(backup.pc)
	ld sp,(backup.sp)
	push hl
	
	; Load correct value of HL
	ld hl,(backup.hl)

	; Get interrupt state
	push af
	ld a,(backup.interrupt_state)
	bit 2,a
.jump:
	jp rst_code_return
