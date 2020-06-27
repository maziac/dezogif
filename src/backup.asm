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
save_registers:	; TODO: Maybe not required anymore
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
;   -
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
	pop hl	; AF
	ld (debugged_prgm_stack_copy.af),hl 

	; Load SP, so that it is possible to call subroutines.
	ld sp,debug_stack.top

	; Correct PC on stack (might have been changed by DeZog)
	ld hl,(backup.pc)
	ld (debugged_prgm_stack_copy.return1),hl

	; Correct the debugged program stack, i.e. put AF and return address on the stack
	ld hl,(backup.sp)	; Destination
	add hl,-4	; "PUSH" 2 values
	ld (backup.sp),hl
	ld de,4
	ld bc,debugged_prgm_stack_copy.af
	call write_debugged_prgm_mem
	
	; Restore layer 2 reading/writing
	call restore_layer2_rw
	; It's still possible to read/write in slot 7

	; Restore bank for slot 0
	;ld a,(slot_backup.slot0)
	;nextreg REG_MMU,a  ; Is already

	; Restore DE value
	ld de,(backup.de)	
	; Restore BC value
	ld bc,(backup.bc)	
	; Load correct value of HL
	ld hl,(backup.hl)
	; Get debugged program stack
	ld sp,(backup.sp)

	; Check interrupt state
	ld a,(backup.interrupt_state)
	bit 2,a
	; NZ if interrupts enabled
	; Set bank to restore for slot 7
	ld a,(slot_backup.slot7)
	; Turn on NMI
.enable_nmi:	equ $+3
	nextreg REG_PERIPHERAL_2,0	; self-modifying code
	jp nz,exit_code_ei
	jp exit_code_di



;===========================================================================
; Adjusts the stack of the debugged program by 4 bytes.
; Before (debugged_prgm_stack_copy):
; - [SP+6]:	The return address 
; - [SP+4]:	AF was put on the stack
; - [SP+2]:	    AF (Interrupt flags) was put on the stack
; - [SP]:	    BC
; After:
; - [SP+6]:	The return address-1
; - [SP+4]:	AF was put on the stack
; ===========================================================================
adjust_debugged_program_stack_for_bp:
	ld de,(debugged_prgm_stack_copy.return1)	
	dec de
	ld (backup.pc),de

	; Adjust debugged program SP
	ld hl,(backup.sp)	
	add hl,4*2	; Skip complete stack
	ld (backup.sp),hl	

.af:
	; Backup AF
	ld hl,(debugged_prgm_stack_copy.af)	
	ld (backup.af),hl
	ret


;===========================================================================
; Adjusts the stack of the debugged program by 4 bytes.
; Before (debugged_prgm_stack_copy):
; Stack for a function call from the debugged program
; - [SP+10]:	The return address
; - [SP+8]:	Function number
; - [SP+6]: 0x0000, to distinguish from SW breakpoint
; - [SP+4]:	AF was put on the stack
; - [SP+2]:	AF (Interrupt flags) was put on the stack
; - [SP]:	BC
; After:
; - [SP+10]:	The return address-1
; - [SP+8]:	AF was put on the stack
; ===========================================================================
adjust_debugged_program_stack_for_function:
	ld de,(debugged_prgm_stack_copy.return2)	
	ld (backup.pc),de

	; Adjust debugged program SP
	ld hl,(backup.sp)	
	add hl,6*2	; Skip complete stack
	ld (backup.sp),hl	

	; Rest
	jr adjust_debugged_program_stack_for_bp.af


;===========================================================================
; Saves layer 2 reading/writing.
; Changes:
;   A, BC
; ===========================================================================
save_layer2_rw:	; TODO: still required?
	; Save layer 2 reading/writing
    ld bc,LAYER_2_PORT
    in a,(c)
	push af
	; Turn off layer 2 reading/writing
	;xor a
	and 11111010b	; Disable read/write only
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
;   AF, BC
; ===========================================================================
save_swap_slot:
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
restore_swap_slot:
	ld a,(slot_backup.tmp_slot)
restore_slot:	; Restore the slot in A
	nextreg REG_MMU+SWAP_SLOT,a
	ret





;===========================================================================
; Read data from the memory (e.g. stack) of the debugged program.
; Parameters:
;	HL = the data to get
;   DE = the count
;   BC = the destination (in slot 7)
; Returns:
;   The data copied to BC...
; Changes:
;   
; ===========================================================================
read_debugged_prgm_mem:
	push bc
	ld bc,.read_write
	ld (memory_loop.inner_call+1),bc	; function pointer
	call save_swap_slot
	pop bc
	jp memory_loop.inner

; Inner call for 'loop_memory'
.read_write:
	; Get byte
	ld a,(hl)
	; Write byte
	ldi (bc),a
	ret 


;===========================================================================
; Write data to the memory (e.g. the stack) of the debugged program.
; Parameters:
;	HL = the pointer to write to
;   DE = the count
;   BC = the source (in slot 7)
; Returns:
;   The data copied to HL...
; Changes:
;   
; ===========================================================================
write_debugged_prgm_mem:
	push bc
	ld bc,.read_write
	ld (memory_loop.inner_call+1),bc	; function pointer
	call save_swap_slot
	pop bc
	jp memory_loop.inner

; Inner call for 'loop_memory'
.read_write:
	; Get byte
	ldi a,(bc)
	; Write byte
	ld (hl),a
	ret 


; ===========================================================================
; Helper class for cmd_read/write_mem and read/write_debugged_prgm_mem.
; Loop over (debugged program) memory in 2 phases:
; 1. memory in range 0xE000-0xFFFF
; 2. memory in range 0x0000-0xDFFF
; 3. loop to 1
; Each of the phase is optionally.
; Parameters:
;   HL = memory to read
;   DE = size
;   BC = contains a function pointer to the inner call. When called (HL) 
;        contains the memory at the location. DE and HL should not be changed.
; ===========================================================================
memory_loop:
	; Phase 1: memory in range 0xE000-0xFFFF
	ld (.inner_call+1),bc	; function pointer
	call save_swap_slot
.inner:	; Beginning from here BC is not touched anymore
	ld a,h
	;cp 0x20
	cp 0xE0
	jr c,.phase2

	; Modify HL
	and 0x1F
	add SWAP_SLOT*0x20	; 0xC0
	ld h,a

.phase1:	
	; Page in slot 7 area to swap slot
	ld a,(slot_backup.slot7)
	nextreg REG_MMU+SWAP_SLOT,a

	call .inner_loop

	; End if de was 0
	jp z,restore_swap_slot

	; Page in original banks
	call restore_swap_slot

	; Correct the address
	ld hl,0x0000

.phase2:
	; Phase 2: memory in range 0x0000-0xDFFF
	call .inner_loop
	ret z	; Return if DE was 0

	; Phase 1 again: memory in range 0xE000-0xFFFF
	ld hl,SWAP_SLOT*0x2000	; Correct HL to 0xC000
	jr .phase1


	; On a return DE contains the rest of the bytes to copy.
	; Returns with Z if DE is zero, otherwise NZ.
.inner_loop:
	; Check counter
	ld a,e
	or d
	ret z

.inner_call:
	call 0x0000	; Self-modifying code

	; Decrement counter
	dec de
	; Increment pointer
	inc l
	jr nz,.inner_loop
	inc h
	ld a,h
	cp 0x20*(SWAP_SLOT+1)	; Compare with end of slot memory area
	jr nz,.inner_loop
	
	; End of bank(s) reached	
	; Check DE once again
	ld a,e
	or d
	ret 
	
