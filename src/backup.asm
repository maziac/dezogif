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
.i:			defb 0
.r:			defb 0
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
backup_top:
			defb 0	; WPMEM

;===========================================================================
; Save all registers except AF. AF has been already stored.
; Parameters:
;  SP = points to backup.af
; Returns:
;  SP = debug_stack_top
; ===========================================================================
save_registers:
	pop af  ; Save return address

	push bc
	push de
	push hl
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
	ld a,i
	ld l,a
	ld a,r
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

	push af ; Restore return address
	ret 


;===========================================================================
; Restore all registers and jumps to the stored PC.
; Parameters:
;  SP = points to debug_stack_top-2 (i.e. the return address)
; ===========================================================================
restore_registers:
	; Skip im
	ld sp,backup.i

	; I and R register
	pop hl
	ld a,l
	ld i,a
	ld a,h
	ld r,a
	
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
	pop hl
	pop de
	pop bc
	pop af

	ld sp,(backup.sp)

	; Jump to the address put on the stack before	
	ret 
