;===========================================================================
; mf.asm
;
; Routines for handling the Multiface and NMI.
;===========================================================================

    
;===========================================================================
; Constants
;===========================================================================
    



;===========================================================================
; Enables the Multiface NMI.
; Changes:
; A, BC, F
; ===========================================================================
mf_nmi_enable:
	ld a,REG_PERIPHERAL_2
	call read_tbblue_reg
	or 00001000b	; Enable MF NMI
	nextreg REG_PERIPHERAL_2,a
	ret 


;===========================================================================
; Disables the Multiface NMI.
; Changes:
; A, BC, F
; ===========================================================================
mf_nmi_disable:
	ld a,REG_PERIPHERAL_2
	call read_tbblue_reg
	and 11110111b	; Disable MF NMI
	nextreg REG_PERIPHERAL_2,a
	; And save value for exiting
	or 00001000b	; Enable M1 button bit
	ld (restore_registers.enable_nmi),a
	ret 


;===========================================================================
; Function to return from the NMI and to enable maskable interrupts (if they
; were enabled before entering the NMI).
; I.e. executes a RETN.
; ===========================================================================
nmi_return:
	retn


mf_hide:
	out (0x3F),a
	in a,(0xbf)
	ret 

mf_page_out:
	in a,(0xbf)
	ret 




;===========================================================================
; Is called from the Multiface ROM when the NMI button was pressed.
; This will send a pause notification and afterwards handle all "queued"
; commands from DeZog.
; Then the NMI is left.
; When entered:
;   SP is pointing to the MF.stack.
;   All other registers are from the debugged program.
;   The debugged program SP is in MF.backup_sp.
; ===========================================================================
mf_nmi_button_pressed:
	; Save registers
	push hl
	ld hl,.save_registers_continue
	ld (save_registers.ret_jump+1),hl
	pop hl
	ld sp,(MF.backup_sp)	; Restore SP
.for_test:  ; TODO: REMOVE label
	jp save_registers  ; Note: a CALL/RET cannot be used here
.save_registers_continue:

    ; Change SP to main slot
    ld sp,debug_stack.top

	; Get the return address from the debugged program
	; Read debugged program stack
	ld hl,(backup.sp)
	ld de,2	; Just the return address
	ld bc,debugged_prgm_stack_copy.return1
	call read_debugged_prgm_mem

	; Save PC
	ld hl,(debugged_prgm_stack_copy.return1)
	ld (backup.pc),hl	
	
	; Save also the interrupt state.
	; Note: during NMI no maskable interrupt can happen.
	; The IFF2 state can simply be read with a 1-time read through LD A,I.
	ld a,i		; Read IFF2
	push af 
	pop hl
	ld a,l	; Bit 2 contains the interrupt state.
	ld (backup.interrupt_state),a

	; Send pause notification
	ld d,BREAK_REASON.MANUAL_BREAK
	ld hl,0 ; bp address
	call send_ntf_pause

	; L2 backup
	call save_layer2_rw

	; Debugged program stack ändern
	call adjust_debugged_program_stack_for_nmi

	; Change main state
	ld a,PRGM_STOPPED
	ld (prgm_state),a

    ; Return from NMI (Interrupts are disabled)
    di
    call nmi_return

	; Enter debugging loop
	;ld sp,debug_stack.top
	jp cmd_loop


;===========================================================================
; Is called from the Multiface ROM when the NMI button was pressed
; and the MAIN_BANK is already paged in.
; That means the debugger is already running andthe NMI should immediately return.
; The stack is used by the debugger already, so it's safe to use it here as well.
; When entered:
;   SP is pointing to the MF.stack.
;   AF needs to be popped from MF.stack.
;   All other registers are from the current running debugger.
;   The debugger's SP is in MF.backup_sp.
; ===========================================================================
mf_nmi_button_pressed_immediate_return:
	; Restore speed
	ld a,(backup.speed)
    nextreg REG_TURBO_MODE,a
	; Pop from MF stack
	pop af 
	; Restore SP
	ld sp,(MF.backup_sp)	; debugger stack
	; Page out MF ROM/RAM
	push af		; TODO: SP could still be in MF area
	in a,(0xbf)
	pop af
	; Return from NMI
	retn
