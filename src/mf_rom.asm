;===========================================================================
; mf_rom.asm
;
; Contains mainly the NMI routine and the code to copy the debugger to bank 7.
;===========================================================================

 IFDEF MF_FAKE
; For unit testing:
MF_ORIGIN_ROM:  equ 0x6000  ; For testing another origin is defined
MF_DIFF_TO_RAM:  equ main_end-MAIN_ADDR    ; Just after the debugger program
 ELSE
MF_ORIGIN_ROM:   equ 0x0000
MF_DIFF_TO_RAM:  equ MF_ORIGIN_ROM+0x2000-MF.main_prg_copy ; At 0x2000
 ENDIF


 IFNDEF UNIT_TEST
    OUTPUT "out/mf_nmi.bin"
 ENDIF

;===========================================================================
; ROM for Multiface.
;===========================================================================
    MODULE MF

    ORG MF_ORIGIN_ROM

    defs 0x38
    ei
    ret

    defs MF_ORIGIN_ROM+0x66-$

;===========================================================================
; NMI: 0x0066
; Is executed if the M1 (yellow) button is pressed for the Multiface, and also
; if a SOFTWARE Multiface NMI is raised, which is what the asynchronous break's
; Copper list does once per frame.
; The NMI cannot be interrupted by a maskable interrupt and it
; will not be interrupted by another NMI as the M1 button is not re-activated
; before paging out the MF ROM/RAM at the end of the routine.
;
; Three ways out, each with its own tail:
;   .is_button_cause    the M1 button
;   .software_cause     the asynchronous-break poll, see there
;   fall through        a DivMMC NMI or an I/O trap: not ours, decline
;===========================================================================
nmi66h:
    ; Save the SP
    ld (MF.backup_sp),sp
    ; Change SP to be sure that it is inside RAM, so change it to MF RAM for now.
    ld sp,MF.stack.top

    ; Save to MF stack
    push af, bc

    ; Backup the debugged program's IO_NEXTREG_REG selection, BEFORE the cause
    ; check below selects REG_RESET. It used to be read in .is_button_cause,
    ; i.e. after that OUT, so what was saved was always REG_RESET and the
    ; debugged program's own selection was lost. Once per button press that is
    ; near enough harmless; the poll takes this path ~50 times a second while
    ; the debugged program runs, which turns it into a recurring corruption.
    ; Every path that returns to the interrupted code puts it back.
	ld bc,IO_NEXTREG_REG
	in a,(c)
	ld (MF.nmi_io_next_reg),a

    ; Core 03.01.10: Check for the cause of the NMI and return if not a button press
    ld a,REG_RESET
	out (c),a
	; Read register
    inc b
	in a,(c)
    and 00011100b
;    and 0
;    or 1
    jr z,.is_button_cause

    ; Not a button press. The three bits kept by the mask are, from
    ; zxnext.vhd:5891:
    ;   bit 4  nr_02_iotrap              the I/O trap on 0x2FFD/0x3FFD
    ;   bit 3  nr_02_generate_mf_nmi     a CPU or Copper write of NR 0x02 bit 3
    ;   bit 2  nr_02_generate_divmmc_nmi the DivMMC (drive) button
    ; Bit 3 is the asynchronous-break poll and is served below. The other two
    ; are not ours: an I/O trap fires on a port access rather than on a raster
    ; line, so it is not the Copper's.
    ; The answer is taken now and carried in F across the latch clear, which
    ; both non-button causes need.
    bit 3,a
    push af

    IF 0
	; Change border to blue
	ld a,BLUE
    out (BORDER),a
	ENDIF

    ; Clear reason bits.
    ; Not to re-arm the NMI - RETN does that in hardware - but so that the NEXT
    ; NMI reports its cause correctly: leave bit 3 set and a genuine button
    ; press reads a non-zero mask above and is misrouted down the poll path.
    ; "and 10000000b" is load bearing: bits 1:0 WRITTEN trigger a soft/hard
    ; reset (zxnext.vhd:6369-6370) while READ they are the reset type
    ; (:5891), so a read-modify-write of this register resets the machine -
    ; and on the poll path that would be once a frame.
	in a,(c)    ; Read again
    and 10000000b  ; Preserve esp/expbus bit
    nextreg REG_RESET,a

    pop af      ; the bit 3 answer
    jr nz,.software_cause

    ; Immediately return if there is some other reason than a button press.
    ; Shared with .poll_decline below, which arrives with the latch cleared too.
    ; Nothing pages the Multiface out here: RETN does it in hardware, which is
    ; what the decline has always relied on.
.return_to_interrupted:
    ; Restore the debugged program's IO_NEXTREG_REG selection
	ld bc,IO_NEXTREG_REG
	ld a,(MF.nmi_io_next_reg)
	out (c),a

    ; RETN
    pop bc, af
    ld sp,(MF.backup_sp)
    retn


;===========================================================================
; A software Multiface NMI: the asynchronous-break poll.
;
; Raised by a two-instruction Copper list - "WAIT line,N" / "MOVE $02,$08" -
; that THE DEBUGGED PROGRAM installs, not the debugger. That division is
; deliberate and it is not an optimization: the Copper's 1024-instruction list
; is write-only (both instruction RAMs discard their CPU-side read output,
; zxnext.vhd:3959-3976 and :3980-3998, and NR 0x60/0x63 have no read decode,
; :6286-6287), so a debugger that installed a list of its own could never give
; the original back. A program that carries the two instructions itself keeps
; its own Copper program; one that does not simply gets no asynchronous break.
; See documentation/AsynchronousBreak.md.
;
; This path runs once a frame while the debugged program runs, so it is written
; to leave as fast as it can and to touch as little as possible:
;
;   * It does NOT change the clock speed unless it breaks in. The button path
;     switches to 28MHz before it has decided anything; doing that here would
;     move the machine's clock 50 times a second, which for contended memory,
;     tape or beeper code is a worse perturbation than the stolen cycles.
;   * It never reaches init_main_bank. Symbol Shift is not polled and a magic
;     mismatch declines rather than re-initializing: a poll that re-copied the
;     debugger over a running session would be catastrophic, and it fires by
;     itself with nobody's finger on anything.
;   * It restores MAIN_SLOT. The button path's immediate return deliberately
;     does not, because it only ever runs while the DEBUGGER executes and
;     MAIN_SLOT legitimately holds MAIN_BANK. This fires while the DEBUGGED
;     PROGRAM executes.
;
; The magic check is the safety gate and is not optional: prgm_state lives in
; MAIN_BANK, so neither it nor anything else there may be trusted - let alone
; called - until the bank has been shown to hold our image. Two bytes rather
; than the button path's six, because this runs every frame.
;===========================================================================
.software_cause:
    ; The cause latch was cleared above, where both non-button causes share it.
    ; Save what MAIN_SLOT held and page MAIN_BANK in over it.
    ; BC is IO_NEXTREG_DAT here.
    dec b   ; IO_NEXTREG_REG
    ld a,REG_MMU+MAIN_SLOT
	out (c),a
	; Read register
    inc b
	in a,(c)	; A contains the previous bank number for MAIN_SLOT
    ld (MF.nmi_slot7),a
	; Page in slot 7
	nextreg REG_MMU+MAIN_SLOT,MAIN_BANK

    ; Is our image really there? magic_number_a and magic_number_b are adjacent
    ; (data_const.asm), so both are compared as one word. BC is dead after
    ; this - every path out of here reloads it.
    push hl
    ld hl,(MAIN_ADDR+magic_number_a)
    ld bc,(main_prg_copy+magic_number_a)
    or a
    sbc hl,bc
    pop hl
    jr nz,.poll_decline

    ; Ours. The rest of the decision needs no MF ROM bytes and lives in the
    ; debugger's own bank: mf.asm's mf_nmi_poll, which comes back to
    ; .poll_decline or leaves through .break_into_debuggee.
    jp mf_nmi_poll

.poll_decline:
    ; Put MAIN_SLOT back before returning, or the debugged program gets its
    ; machine back with the debugger's bank at 0xE000.
    ld a,(MF.nmi_slot7)
    nextreg REG_MMU+MAIN_SLOT,a
    jr .return_to_interrupted


.is_button_cause:

    IF 0
    ; Change border
    ld a,(MF.border_color)
    inc a
    and 0x07
    ld (MF.border_color),a
    out (BORDER),a
    ENDIF

    ; IO_NEXTREG_REG was backed up at the top of nmi66h - see there.
    ld a,(MF.nmi_io_next_reg)
    ld (backup.io_next_reg),a

	; Now backup main slot.
    ld bc,IO_NEXTREG_REG
	ld a,REG_MMU+MAIN_SLOT
	out (c),a
	; Read register
    inc b
	in a,(c)	; A contains the previous bank number for MAIN_SLOT

	; Page in slot 7
	nextreg REG_MMU+MAIN_SLOT,MAIN_BANK
	; Save previous bank
	ld (slot_backup.slot7),a

    ; Save clock
	ld a,REG_TURBO_MODE
	dec b   ; IO_NEXTREG_REG
	out (c),a
	; Read register
    inc b
	in a,(c)
	ld (backup.speed),a

    ; Check for Symbol Shift being pressed the same time -> Init
    ld bc,PORT_KEYB_BNMSHIFTSPACE
    in a,(c)
    bit 1,a ; Symbol Shift
    jr z,init_main_bank

    ; Speed up
    nextreg REG_TURBO_MODE,RTM_28MHZ

	; Compare with magic number
    push hl

    if 01
	ld a,(main_prg_copy+magic_number_a)
	ld hl,MAIN_ADDR+magic_number_a
	cp (hl)
	jr nz,init_main_bank
	ld a,(main_prg_copy+magic_number_b)
    inc hl
	cp (hl)
	jr nz,init_main_bank
	ld a,(main_prg_copy+magic_number_c)
	ld hl,MAIN_ADDR+magic_number_c
	cp (hl)
	jr nz,init_main_bank
	ld a,(main_prg_copy+magic_number_d)
	inc hl
	cp (hl)
	jr nz,init_main_bank
    ; Also check build time
	ld a,(main_prg_copy+build_time_rel)
	ld hl,MAIN_ADDR+build_time_rel
	cp (hl)
	jr nz,init_main_bank
	ld a,(main_prg_copy+build_time_rel+1)
	inc hl
 ;inc a
	cp (hl)
	jr nz,init_main_bank
    endif

    pop hl, bc

    ; Check if program was already stopped
    ld a,(prgm_state)
    cp PRGM_RUNNING
    jp nz,mf_nmi_button_pressed_immediate_return

    ; Restore registers from MF stack
    pop af

    jp mf_nmi_button_pressed


;===========================================================================
; Initializes the main bank. I.e. copies the code from MF to MAIN_BANK.
;===========================================================================
init_main_bank:
    di
    ; Switch clock
    nextreg REG_TURBO_MODE,RTM_3MHZ
    ; Wait and flash the border
    ld bc,0x4000
.wait:
    ld a,c
    srl a : srl a : srl a
    and 0x07
    out (BORDER),a
    dec bc
    ld a,c
    or b
    jr nz,.wait
    out (BORDER),a  ; a is 0 = BLACK
    ; pop bc, af ; doesn't matter. program control is now moved to dezog.

	; Maximize clock speed
	nextreg REG_TURBO_MODE,RTM_28MHZ

    ; Reset layer 2 writing/reading
    ld bc,LAYER_2_PORT
    xor a
    out (c),a

    ; The main program needs to be copied to MAIN_BANK
    ; Page in MAIN_BANK
    nextreg REG_MMU+MAIN_SLOT,MAIN_BANK
    MEMCOPY MAIN_ADDR, main_prg_copy, MF_DIFF_TO_RAM

    ; Jump to main bank
    jp main_bank_entry


; Align to 16 bytes.
    ALIGN 16, 0

 IFNDEF UNIT_TEST
    OUTEND
 ENDIF


;===========================================================================
; This here contains a copy of the main debug program.
; It will be copied from here into the MAIN_BANK/MAIN_SLOT.
;===========================================================================

main_prg_copy:
    ; The actual code is copied in the make file target mf_rom.
    ; ...



;===========================================================================
; The MF RAM area.
;===========================================================================
    defs MF_DIFF_TO_RAM


; The Multiface stack. Used only for a very short timeframe.
stack:
    defs 2*20
.top:

; Used to backup the debugged program's SP.
backup_sp:      defw 0

; The bank that was in MAIN_SLOT when this NMI was taken, before the entry path
; paged MAIN_BANK in over it. Scoped to the NMI entry, like backup_sp above, and
; deliberately not slot_backup.slot7: the poll declines far more often than it
; breaks in, and on a decline this has to go back into the MMU rather than into
; the debugged program's saved state.
nmi_slot7:      defb 0

; The IO_NEXTREG_REG selection as this NMI found it, read at the top of nmi66h.
; Same scope as the two above.
nmi_io_next_reg: defb 0

; Non-zero when this break was caused by the poll rather than by the M1 button,
; so that mf_nmi_button_pressed can skip its drain_rx_buffer. The drain discards
; everything until 100ms of quiet, which is right for a button press - nobody
; sent anything, and junk on the link should go - and wrong for a poll break,
; whose whole cause is a command sitting in the RX FIFO. Draining would throw
; that command away and leave DeZog blocked on a response that can never come.
;
; A byte rather than a register: the pops in mf_nmi_poll and save_registers
; between here and there consume every one of them. It is read AND cleared by
; mf_nmi_button_pressed, so a button press following a poll break drains
; normally, and main_bank_entry clears it because MF RAM is undefined at
; power-on.
;
; None of these four cost a byte of the 8192-byte ROM image: OUTEND is above, so
; nothing from here down is emitted.
nmi_poll_break:  defb 0

    ENDMODULE

