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
; Data. 
;===========================================================================

	defb	0	; WPMEM
; The debug stack begins here. SP flows from backup in here.
debug_stack:	defs 50
debug_stack_top:

; The registers of the debugged program are stored here.
backup:
.im:		defb 0	; TODO: cannot be saved
.reserved:	defb 0
.r:			defb 0
.i:			defb 0
.hl2:		defw 0
.de2:		defw 0
.bc2:		defw 0
.af2:		defw 0
.iy:		defw 0
.ix:		defw 0
.hl:		defw 0
.de:		defw 0
.bc:		defw 0
.af:		defw 0
.sp:		defw 0
.pc:		defw 0
.speed:	defb 0
.border_color:	defb 0
backup_top:
			defb 0	; WPMEM

;===========================================================================
; Save all registers.
; Also changes stack pointer.
; Parameters:
;  SP = points to backup.af
; Returns:
;  SP = debug_stack_top after RET
; ===========================================================================
save_registers:
	; Save
	ld (backup.hl),hl
	pop hl  ; Save return address to HL
	ld (.ret_jump+1),hl	; self.modifying code, used instead of a return

	; Get caller address (+3) of dbg_check_for message or enter_breakpoint
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
	ld sp,(backup.sp)
	ld hl,(backup.pc)
	ex (sp),hl
	
	; Load correct value of HL
	ld hl,(backup.hl)

	; Jump to the address on the stack, i.e. the PC
	ret 
