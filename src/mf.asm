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
 ret ; TODO
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
 ret ; TODO
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
	jp save_registers  ; Note: a CALL cannot be used here
.save_registers_continue:

    ; Change SP to main slot
    ld sp,debug_stack.top

	; Send pause notification
	ld d,BREAK_REASON.MANUAL_BREAK
	ld hl,0 ; bp address
	call send_ntf_pause

	; Check if there are more messages waiting
	call execute_cmds

	; Save
	push af

	; Either hide or page out. Both work to re-enable the M1 button.
	call mf_hide
	;call mf_page_out

    pop af

    retn



;===========================================================================
; Is called from the Multiface ROM when the NMI button was pressed
; and the MAIN_BANK is already paged in.
; That means the debguger is already running andthe NMI should immediately return.
; The stack is used by the debugger already, so it's safe to use it here as well.
; When entered:
;   SP is pointing to the MF.stack.
;   BC/AF need to be popped from MF.stack.
;   All other registers are from the current running debugger.
;   The debugger's SP is in MF.backup_sp.
; ===========================================================================
mf_nmi_button_pressed_immediate_return:
	; Pop from MF stack
	pop bc, af 
	; Restore SP
	ld sp,(MF.backup_sp)	; debugger stack
	; Page out MF ROM/RAM
	push af
	in a,(0xbf)
	pop af
	; Return from NMI
	retn


/*
	; Get sp into MAIN_BANK
	ld bc,(MF.backup_sp)
	ld (backup.sp),bc
	; Pop from MF stack
	pop bc, af 
	; Use new stack
	ld sp,debug_stack.top
	; Save registers
	push af, hl
	; Page out MF ROM/RAM
	in a,(0xbf)


	; Copy nmi exit program to slot 0 bank
	; It is assumed that the correct bank (Copy of ROM or modified user bank)
	; is paged into slot 0. This should be OK since it was tested that the
	; MAIN_BANK is paged in slot 7.
	MEMCOPY mf_nmi_exit, mf_nmi_exit_copy, mf_nmi_exit_copy_end-mf_nmi_exit_copy
	; Set right bank to change

	ld hl,(backup.sp)
	dec hl : dec hl 	; Reserve 2 bytes on the stack for another interrupting nmi
	
	; Restore
    pop hl, af
    ld sp,(backup.sp)
	retn


;===========================================================================
; Routine for exiting from the debugger into the debugged program.
; When returning from NMI a special procedure is required which is copied into
; the ROM area (slot 0) to save space.
; Occupies 6 bytes.
;===========================================================================
mf_nmi_exit_copy:
	DISP 0x0002	; Compile for address 0x0002
mf_nmi_exit:
.bank:	equ	$+3
	nextreg REG_MMU+MAIN_SLOT,0	; Self-modifying code
	retn
.end
	ENT
mf_nmi_exit_copy_end

	ASSERT mf_nmi_exit_copy_end-mf_nmi_exit_copy <= 6

*/
