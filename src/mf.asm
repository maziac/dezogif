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

	nextreg REG_PERIPHERAL_2,a	; TODO: Remove: Enable for testings

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
	jp save_registers  ; Note: a CALL/RET cannot be used here
.save_registers_continue:

    ; Change SP to main slot
    ld sp,debug_stack.top

	; Get the return address from the debugged program
	; Read debugged program stack
	ld hl,(MF.backup_sp)
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

	; Make sure the joyport is configured for the UART
	call set_uart_joystick

	; First work on all messages that might be in the queue
	call execute_cmds_loop

	; Send pause notification
	ld d,BREAK_REASON.MANUAL_BREAK
	ld hl,0 ; bp address
	call send_ntf_pause

	; L2 backup
	call save_layer2_rw

	; Debugged program stack ändern
	call adjust_debugged_program_stack_for_nmi

    ; Return from NMI (Interrupts are disabled)
    di
    call nmi_return

	; Disable MF
	call mf_page_out

	; Enter debugging loop
	jp cmd_loop


;===========================================================================
; Is called from the Multiface ROM when the NMI button was pressed
; and the MAIN_BANK is already paged in.
; That means the debugger is already running and the NMI should immediately return.
; The stack is used by the debugger already, so it's safe to use it here as well.
; When entered:
;   SP is pointing to the MF.stack.
;   AF needs to be popped from MF.stack.
;   All other registers are from the current running debugger.
;   The debugger's SP is in MF.backup_sp.
; ===========================================================================
mf_nmi_button_pressed_immediate_return:
	; Restore IO_NEXTREG_REG
	push bc
	ld bc,IO_NEXTREG_REG
	ld a,(backup.io_next_reg)
	out (c),a
	pop bc
	; Restore speed
	ld a,(backup.speed)
    nextreg REG_TURBO_MODE,a
	; Pop from MF stack
	pop af 
	; Restore SP
	ld sp,(MF.backup_sp)	; debugger stack
	; Page out MF ROM/RAM
	push af		; If the debugger is running it is using it's stack in slot 7
	in a,(0xbf)
	pop af
	; Return from NMI
	retn
