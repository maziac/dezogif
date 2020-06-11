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
; Note: The interrupt state is already saved before this function is called.
; Parameters:
;  - Stack:
;    -2 = return address (return to caller)
;    -4 = AF
;    -6 = caller of breakpoint (RST) +1
; Returns:
;  SP = debug_stack_top after ret_jump
; ===========================================================================
save_registers:
	; Save
	ld (backup.hl),hl
	pop hl  ; Save return address to HL
	ld (.ret_jump+1),hl	; self.modifying code, used instead of a return

	; Restore AF
	pop af 

	; Get caller address (+1 for RST) of enter_breakpoint
	pop hl	
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




;===========================================================================
; Saves all slots/banks to RAM.
; Changes:
;   A, HL, DE, BC
; ===========================================================================
save_slots:
	ld de,8*256+REG_MMU
	ld hl,slot_backup
	ld bc,IO_NEXTREG_REG
.loop:
	ld a,e
	call read_tbblue_reg_multiple
	ldi (hl),a
	; next
	inc e
	dec d
	jr nz,.loop
	ret


;===========================================================================
; Saves the 2 ROM slots.
; Changes:
;   A, BC
; ===========================================================================
save_rom_slots:
	ld a,REG_MMU
	ld bc,IO_NEXTREG_REG
	call read_tbblue_reg_multiple
	ld (slot_backup.slot0),a
	ld a,REG_MMU+1
	call read_tbblue_reg_multiple
	ld (slot_backup.slot1),a
	ret


;===========================================================================
; Restores all slots/banks to RAM.
; Changes:
;   HL, DE, B
; ===========================================================================
restore_slots:
	ld b,8
	ld hl,slot_backup
	ld e,REG_MMU
.loop:
	ldi d,(hl)
	ld (.reg+2),de	; E=MMU register, D=bank
.reg:
	nextreg 0,0
	inc e
	djnz .loop
	ret
	

;===========================================================================
; Restores all slots/banks to RAM.
; Changes:
;   A
; ===========================================================================
restore_rom_slots:
	ld a,(slot_backup.slot0)
	nextreg REG_MMU,a
	ld a,(slot_backup.slot1)
	nextreg REG_MMU+1,a
	ret
	
