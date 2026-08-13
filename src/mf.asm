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

	; First drain receive message queue - UNLESS this break was the poll's.
	; See MF.nmi_poll_break: for a button press the drain is right, for a poll
	; break it would eat the very command that asked for the break.
	; Read and cleared in one place, so a button press after a poll break drains
	; normally. "call z" because a zero flag from "or a" means "not a poll".
	ld hl,MF.nmi_poll_break
	ld a,(hl)
	ld (hl),0
	or a
	call z,drain_rx_buffer

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
; The asynchronous-break poll.
;
; Reached by JP from mf_rom.asm's .software_cause, which has already cleared the
; NR 0x02 cause latch, saved the debugged program's bank in MF.nmi_slot7, paged
; MAIN_BANK into MAIN_SLOT and checked that the image there is ours. Nothing may
; be called in this bank before that check, which is why the check is in MF ROM
; and everything below is here: MF ROM bytes are scarce and these are not.
;
; When entered:
;   MF ROM/RAM paged in; MAIN_BANK in MAIN_SLOT; interrupts disabled by the NMI.
;   SP = MF.stack, holding [AF][BC] - the debugged program's, pushed by nmi66h.
;   DE, HL, IX, IY and the alternate set are the debugged program's and MUST
;   survive: the decline returns to it, and the break hands them to
;   save_registers.
;
; Two questions, in this order, and the order matters.
;
;   1. Is a program running? Answered from prgm_state, which is exact and needs
;      no new flag - but it lives in MAIN_BANK, so it could not have been asked
;      before the magic check. Anything other than PRGM_RUNNING means the
;      debugger itself is executing (stopped at a breakpoint, or idling in
;      main_loop) and there is nothing to break into.
;   2. Only then, is there traffic? Asking that first would read the UART status
;      register while the debugger is using the link itself - and that read
;      clears the sticky RX overflow and framing flags (serial/uart.vhd:536-539),
;      so a poll firing once a frame would wipe an overflow the debugger's own
;      code was about to report. With the order this way round the status
;      register is only touched while the debugged program runs.
;
; What counts as traffic is "any byte", which is a decision with a visible cost:
; check_uart_byte_available is one status read and cannot tell a CMD_PAUSE from
; anything else that arrives, so a stray byte on the cable breaks the program in
; when nobody asked. Parsing inside the NMI is the alternative and it is worse.
; The precedent is cmd_loop's own wait_for_uart_rx, which has always resumed on
; any byte.
;===========================================================================
mf_nmi_poll:
	; 1. Is there a debugged program to break into?
	ld a,(prgm_state)
	cp PRGM_RUNNING
	jr nz,.decline

	; 2. Has the PC said anything?
	call check_uart_byte_available
	jr z,.decline

	; --- break in ---------------------------------------------------------
	; The NMI interrupted a running program, so MAIN_SLOT held ITS bank. This is
	; the one path on which that value is what continue must page back.
	ld a,(MF.nmi_slot7)
	ld (slot_backup.slot7),a

	; Tell mf_nmi_button_pressed not to drain: the command that caused this
	; break is in the RX FIFO and the drain would eat it. See there.
	ld a,1
	ld (MF.nmi_poll_break),a

	; The clock is switched HERE and nowhere else, which is the difference
	; between this and the button path: nmi66h speeds up before it has decided
	; anything, and a poll doing that would move the machine's clock once a
	; frame whether or not it broke in. The debugged program's speed is read
	; first, because the next instruction destroys it.
	; Note REG_TURBO_MODE does not read back what was written - bits 5:4 are the
	; actual speed and 1:0 the programmed one (zxnext.vhd:5903) - which is what
	; the button path stores too, and is correct for the same reason.
	ld a,REG_TURBO_MODE
	call read_tbblue_reg
	ld (backup.speed),a
	nextreg REG_TURBO_MODE,RTM_28MHZ

	; Hand over to the button path, which is correct from here on unchanged: a
	; running program was interrupted, which is exactly what
	; mf_nmi_button_pressed is written for. AF and BC are popped because that is
	; the stack state it expects.
	pop bc
	pop af
	jp mf_nmi_button_pressed

.decline:
	; The common case, once a frame. Back to MF ROM, which is where MAIN_SLOT
	; has to be put back from: this bank is about to stop being mapped.
	jp MF.nmi66h.poll_decline


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

	IF 0
	; Change border to red
	ld a,RED
    out (BORDER),a
	ENDIF

	; Restore speed
	ld a,(backup.speed)
    nextreg REG_TURBO_MODE,a
	; Pop from MF stack
	pop af
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
