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
/*
mf_nmi_disable:
	ld a,REG_PERIPHERAL_2
	call read_tbblue_reg
	and 11110111b	; Disable MF NMI
	nextreg REG_PERIPHERAL_2,a
	; And save value for exiting
	ld (restore_registers.enable_nmi),a
	ret
*/


;===========================================================================
; Function to return from the NMI and to enable maskable interrupts (if they
; were enabled before entering the NMI).
; I.e. it executes a RETN.
; Note: it must be able to be used from an NMI interrupt but also in case
; no NMI has happened.
; Changes:
;  - BC, A, F
; ===========================================================================
nmi_return:
	; Check for stackless mode
	ld a,REG_INTERRUPT_CONTROL
	call read_tbblue_reg	; Result in A
	bit NMI_STACKLESS_MODE_BIT,a
	jr z,.retn	; Normal mode, just return (RETN)

	; Handle stackless mode.
	; Cancel any pending nmi stackless cycle by clearing the stackless mode bit.
	; Note: a following RETN will take the address from the stack even if the bit
	; is turned on again.

	; Disable stackless mode
	res NMI_STACKLESS_MODE_BIT,a
	nextreg REG_INTERRUPT_CONTROL,a

	; Enable stackless mode
	set NMI_STACKLESS_MODE_BIT,a
	nextreg REG_INTERRUPT_CONTROL,a

.retn:
	retn


/*
mf_hide:
	out (0x3F),a
	in a,(0xbf)
	ret
*/


;===========================================================================
; Macro to page out the Multiface ROM/RAM.
; ===========================================================================
 	MACRO MF_PAGE_OUT
	in a,(0xbf)
	ENDM



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

	; Save the return address from the debugged program to debugged_prgm_stack_copy.return1 and backup.pc
	call save_nmi_return_address

// TODO: REMOVE:
 if 0
	; Read debugged program stack
	ld hl,(MF.backup_sp)
	ld de,2	; Just the return address
	ld bc,debugged_prgm_stack_copy.return1
	call read_debugged_prgm_mem

	; Save PC
	ld hl,(debugged_prgm_stack_copy.return1)
	ld (backup.pc),hl
 endif

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

	; First drain receive message queue
	call drain_rx_buffer

	; Send pause notification
	ld d,BREAK_REASON.MANUAL_BREAK
	ld hl,0 ; bp address
	call send_ntf_pause

	; L2 backup
	call save_layer2_rw

	; adjust debugged program stack
	call adjust_debugged_program_stack_for_nmi

    ; Return from NMI (Interrupts are disabled)
    di
    call nmi_return

	; Disable MF
	MF_PAGE_OUT

	; Enter debugging loop
	jp cmd_loop


;===========================================================================
; Writes the NMI return address to debugged_prgm_stack_copy.return1.
; If NMI stackless mode is used the address is taken from the Next NMI return registers.
; Otherwise they are taken from the SP.
; Changes:
;   BC, F, A, HL, DE
;===========================================================================
save_nmi_return_address:
	; Check for stackless mode
	ld a,REG_INTERRUPT_CONTROL
	call read_tbblue_reg	; Result in A
	bit NMI_STACKLESS_MODE_BIT,a
	jr nz,.stackless_mode

	; Normal mode: return address on stack.
	; Read debugged program stack (= NMI return address)
	ld hl,(MF.backup_sp)
	ld de,2	; Just the return address
	ld bc,debugged_prgm_stack_copy.return1
	call read_debugged_prgm_mem
	ld hl,(debugged_prgm_stack_copy.return1)
	jr .save

.stackless_mode:
	; Return address in ZXNext registers
	ld a,REG_NMI_RETURN_ADDRESS_LSB
	call read_tbblue_reg	; Result in A
	ld l,a
	ld a,REG_NMI_RETURN_ADDRESS_MSB
	call read_tbblue_reg	; Result in A
	ld h,a
	ld (debugged_prgm_stack_copy.return1),hl

.save:
	; Save PC
	ld (backup.pc),hl
	ret


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

	IF 01
	; Change border to red
	ld a,RED
    out (BORDER),a
	ENDIF

	; Restore speed
	ld a,(backup.speed)
    nextreg REG_TURBO_MODE,a
	; Pop from MF stack
	pop af
mf_nmi_immediate_return:
	; Save stack pointer
	ld sp,(MF.backup_sp)
	ld (nmp_sp_backup),sp
	; Load some stack
	ld sp,nmi_small_stack.top
	; Page out MF ROM/RAM
	push af
	in a,(0xbf)
	pop af
	; Restore SP
	ld sp,(nmp_sp_backup)
	; Return from NMI
	retn
