;===========================================================================
; breakpoints.asm
;
; For a SW breakpoint a RST 0 is substituted with the opcode so that a
; breakpoint can be recognized.
;
; Notes:
; - address 0x0000 is special. Here is the RST command. So it is not possible
;   to se t a breakpoint here. The value 0x0000 is also used as undefined.
;===========================================================================


;===========================================================================
; Constants
;===========================================================================

; The breakpoint reasons.
BREAK_REASON:	
.NO_REASON			EQU 0
.MANUAL_BREAK		EQU 1
.BREAKPOINT_HIT		EQU 2


; The breakpoint RST command.
BP_INSTRUCTION:		EQU 0xC7		; RST 0


; The breakpoint structure to save.
	STRUCT BREAKPOINT
instruction_length	defb	; The length of the 'breaked' instruction. 0 indicates a free location.
address				defw	; The location of the breakpoint
;branch_address		defw	; The optional branch address of the instruction	
opcode				defb	; The substituted opcode
	ENDS

; The temporary breakpoint structure.
	STRUCT TMP_BREAKPOINT
opcode				defb	; The substituted opcode
bp_address			defw	; The location of the temporary breakpoint 
	ENDS



;===========================================================================
; This instructions needs to be copied to address 0x0000.
;===========================================================================
copy_rom_start_0000h_code:	; Located at 0x0000

; Will be executed whenever a RST 0 (SW breakpoint) happens.
entry_code:
 	jr dbg_enter

; Jump here to return from debugger.
; When jumped here:
; - AF is on the stack and need to be popped.
; - Another RET will return to the breaked instruction.
; - A contains the bank to restore for slot 0
exit_code:	; Restore slot 0 bank
	nextreg REG_MMU+USED_SLOT,a
	; Restore
	pop af	
	; Enable interrupts (or not)
.ei:
	ei 	; Self-modified code
	; Jump to the address on the stack, i.e. the PC
    ret 
copy_rom_start_0000h_code_end


	ORG copy_rom_start_0000h_code+0x0066
copy_rom_start_0066h_code:
	nop	; For trap/NMI

dbg_enter:
    ; Store current AF
    push af  ; LOGPOINT [BP] RST 0, called from ${w@(SP):hex}h (${w@(SP)})
	; Get interrupt state 2 times, analyze it later
	ld a,i
	push af
	ld a,i
    ; Flags and pushed AF (P/V): the interrupt state.
	di
	; Get current bank for slot 0
.bank:	EQU $+1 ; TODO
	ld a,0	; Self-modified code. Here the bank is inserted.

	; Page in debugger code
	nextreg REG_MMU+USED_SLOT,USED_BANK
	; This code is executed in another bank (the USED_BANK)
	; ...
copy_rom_start_0066h_code_end

	; Executed in USED_BANK
	jp enter_debugger



;===========================================================================
; Called by RST 0 or JP 0.
; This point is reached when the program e.g. runs into a RST 0.
; This indicates that either a breakpoint was hit (RST 0)
; or the coop code has called it because the debugged program wants to
; check for data on teh UART (JP 0).
; The cases are distinguished by the stack contents:
; - Breakpoint: The stack contains the return address to the debugged program
;   which is != 0.
; - Coop code: A 0 has been put on the stack. The next value on the stack is
;   the return address to the debugged program.
; When entered:
; - F/PUSHED AF contains the interrupt enabled state in P/V (PE=interrrupts enabled)
; - A contains the last used memory bank for USED_SLOT
; - interrupts are turned off (DI)
;
; Stack for a SW breakpoint (RST 0):
; - [SP+2]:	The return address (!=0)
; - [SP]:	AF was put on the stack
; Stack for a function call from the debugged program
; - [SP+6]:	The return address
; - [SP+4]:	Function number
; - [SP+2]: 0x0000, to distinguish from SW breakpoint
; - [SP]:	AF was put on the stack
; Stack for a function call from the debugged program if a parameter is used
; - [SP+8]:	The return address
; - [SP+6]:	Parameter
; - [SP+4]:	Function number
; - [SP+2]: 0x0000, to distinguish from SW breakpoint
; - [SP]:	AF was put on the stack
;===========================================================================
enter_debugger:
	; Save slot 0 bank
	push af 
	; Save layer 2 read/write
	push bc 
	call save_layer2_rw
	pop bc 

	; Save slot 0 bank
	pop af
	ld (slot_backup.slot0),a

	; Check interrupt state: Flags and pushed AF (P/V): the interrupt state. If either one is PE then the interrupts are enabled.
	ld a,0100b
	inc sp : inc sp		; Correct SP
    jp pe,.int_found   	; IFF was 1 (interrupts enabled)

	; 2nd try
	dec sp : dec sp
	pop af
    jp pe,.int_found   	; IFF was 1 (interrupts enabled)

	; Interrupts were disabled
	xor a

.int_found:
	; Store interrupt state in bit 2
	ld (backup.interrupt_state),a
	; LOGPOINT [INT] Saving interrupt state: ${A:hex}h

	; Determine if breakpoint or coop code
	inc sp : inc sp
	ex (sp),hl	; Get value from stack
	; Check for 0
	ld a,l
	or h 
	ex (sp),hl	; Restore stack
	dec sp : dec sp
	jp nz,enter_breakpoint
	jp exec_user_function


;===========================================================================
; Called by enter_debugger.
; I.e. this point is reached when the program runs into a RST 0.
; I.e. this indicates that a breakpoint was hit.
; The location just after the breakpoint can be found from the SP.
; I.e. it was pushed on stack because of the RST.
; When entered:
; Stack for a SW breakpoint (RST 0):
; - [SP+2]:	The return address (!=0)
; - [SP]:	AF was put on the stack
;===========================================================================
enter_breakpoint:
	; LOGPOINT [DEFAULT] enter_breakpoint

   	; Backup all registers 
	call save_registers
	; SP is now at debug_stack_top
	; Maximize clock speed
	ld a,RTM_28MHZ
	nextreg REG_TURBO_MODE,a

	; Correct the return address to the breakpoint address
	ld de,(backup.pc)	
	dec de
	ld (backup.pc),de	

	; Check if temporary breakpoint hit (de = breakpoint address)
	call check_tmp_breakpoints ; Z = found
	ld d,BREAK_REASON.NO_REASON
	jr z,.no_reason
	; Otherwise a "real" breakpoint was hit
	ld d,BREAK_REASON.BREAKPOINT_HIT
.no_reason:

    ; Send pause notification
	ld hl,(backup.pc)	; breakpoint address
	call send_ntf_pause

	; Clear temporary breakpoints
	call clear_tmp_breakpoints

	jp cmd_loop		; continues later at .continue



;===========================================================================
; Clears the temporary breakpoints.
; I.e. restore the original opcodes.
; Temporary breakpoints are not enable if they point to location 0x0000.
;===========================================================================
clear_tmp_breakpoints:
	ld hl,(tmp_breakpoint_1.bp_address)
	ld a,l
	or h
	jr z,.second_bp
	; Restore opcode
	ld a,(tmp_breakpoint_1.opcode)
	ld (hl),a
.second_bp:
	ld hl,(tmp_breakpoint_2.bp_address)
	ld a,l
	or h
	jr z,.clear
	; Restore opcode
	ld a,(tmp_breakpoint_2.opcode)
	ld (hl),a
.clear:
	; Clear both temporary breakpoints
	MEMCLEAR tmp_breakpoint_1, 2*TMP_BREAKPOINT
	ret


;===========================================================================
; Sets one of the two temporary breakpoints.
; Temporary breakpoints are not enable if they point to location 0x0000.
; Stores the opcode at the bp address and set bp address to RST.
; Sets a temporary breakpoint only if no "real" breakpoint is set.
; Parameters:
;   HL = breakpoint address
;   DE = Pointer to tmp_breakpoint1/2
; Changes:
;   HL, DE, A
;===========================================================================
set_tmp_breakpoint:
	; Get opcode
	ld a,(hl)
	cp BP_INSTRUCTION
	ret z	; Do nothing if already a breakpoint set

	; Set BP
	ld (hl),BP_INSTRUCTION ; LOGPOINT [BP] set_tmp_breakpoint @${HL:hex} (${HL})
	; Store to 'opcode'
	ex de,hl
	ldi (hl),a	
	; Store address
	ldi (hl),de
	ret 
	

;===========================================================================
; Checks if one of the 2 temporary breakpoints matches the given breakpoint 
; address.
; Parameters:
;   DE = breakpoint address
; Returns:
;   Z = found
;   NZ = not found
; Changes:
;   HL, DE, A
;===========================================================================
check_tmp_breakpoints:
	ld hl,tmp_breakpoint_1.bp_address
	ldi a,(hl)
	cp e
	jr nz,.no_bp1
	ld a,(hl)
	cp d 
	ret z	; Return if found
.no_bp1:
	inc hl : inc hl	; skip high byte and opcode
	ldi a,(hl)
	cp e
	ret nz	; Return if not found 
	ld a,(hl) 
	cp d 
	ret 	; Return with Z or NZ

