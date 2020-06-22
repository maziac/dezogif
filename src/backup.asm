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
; Important Note:
; This function also turns off layer 2 reading/writing.
; I.e. up to this point it is not save to read from/write to
; slot 0.
; I.e. before calling this function no self-modifying code is 
; allowed.
; ===========================================================================
save_registers:
	; Save hl
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

	; Get interrupt state.
	; Do as much as possible here to save memory in the
	; 'exit_code' routine.
	; Therefore the code is modified in slot0 (EI or NOP to enable or kep interrupts disabled).

	push af	; Is popped at exit_code
	
	; Load slot0 into swap slot to modify it
	push bc
	call save_swap_slot0
	ld a,(slot_backup.slot0)
	nextreg REG_MMU+SWAP_SLOT,a
	ld a,(backup.interrupt_state)
	bit 2,a
	; NZ if interrupts enabled
	ld a,0	; NOP
	jr z,.no_interrupts
	ld a,0xFB	; EI
.no_interrupts:
	; Self-modify code: EI or NOP
	ld (exit_code.ei-copy_rom_start_0000h_code+SWAP_SLOT*0x2000),a
	call restore_swap_slot0
	ld a,(slot_backup.slot0)
	push af	; Put on stack which should be in a safe readable area
	; Restore layer 2 reading/writing
	call restore_layer2_rw
	pop af	; Restore bank
	pop bc
	jp exit_code



;===========================================================================
; Saves layer 2 reading/writing.
; Changes:
;   A, BC
; ===========================================================================
save_layer2_rw:
	; Save layer 2 reading/writing
    ld bc,LAYER_2_PORT
    in a,(c)
	push af
	; Turn off layer 2 reading/writing
	;xor a
	and 11111010b	; Disable read/write
	out (c),a
	; Store
	pop af
	ld (backup.layer_2_port),a
	ret


;===========================================================================
; Restores layer 2 reading/writing.
; Changes:
;   A, BC
; ===========================================================================
restore_layer2_rw:
	; Restore layer 2 reading/writing
	ld a,(backup.layer_2_port)
	ld bc,LAYER_2_PORT
	out (c),a
	ret


;===========================================================================
; Saves the swap slot bank.
; Changes:
;   A
; ===========================================================================
save_swap_slot0:
	ld a,REG_MMU+SWAP_SLOT
save_slot:	; Save the slot in A
	call read_tbblue_reg
	ld (slot_backup.tmp_slot),a
	ret


;===========================================================================
; Restores the swap slot bank.
; Changes:
;   A
; ===========================================================================
restore_swap_slot0:
	ld a,(slot_backup.tmp_slot)
restore_slot:	; Restore the slot in A
	nextreg REG_MMU+SWAP_SLOT,a
	ret
