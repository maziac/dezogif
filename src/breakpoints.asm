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
	ORG MAIN_SLOT*0x2000
	DISP 0x0000	; Compile for address 0x0000
copy_rom_start_0000h_code:	; Located at 0x0000

; Will be executed whenever a RST 0 (SW breakpoint) happens.
entry_code:
 	jr dbg_enter

; Jump here to return from debugger.
; When jumped here:
; - AF is on the stack and need to be popped.
; - Another RET will return to the breaked instruction.
; - A contains the bank to restore for slot 0
exit_code_ei:
	ei 		; Formerly this was done with dynamically changing self-modifying code. As the memory could also be ROM this was changed into different jump addresses.
	; Note: According Zilog spec it is not possible that an interrupt occurs before the next instruction is executed. Thus a possible interrupt happens when the memory banks are OK.
exit_code_di:
	; Restore slot 7
	nextreg REG_MMU+MAIN_SLOT,a
	; Restore
	pop af	
	; Jump to the address on the stack, i.e. the PC
    ret 
copy_rom_start_0000h_code_end
	ENT 

	ORG MAIN_SLOT*0x2000+0x0066
	DISP 0x0066
copy_rom_start_0066h_code:
dbg_enter:
    ; Store current AF
    push af  ; LOGPOINT [BP] RST 0, called from ${w@(SP):hex}h (${w@(SP)})
	; Get interrupt state 2 times, analyze it later
	ld a,i

 IF 01
  set 2,l
  push hl
  pop af 
 ENDIF

	push af
	ld a,i

    ; Flags and pushed AF (P/V): the interrupt state.
	di
	push bc	; Save BC on user stack
	; Get current bank for slot 0
.bank:	EQU $+1
	ld c,MAIN_BANK	; Self-modified code. Here the bank is inserted.

	; Page in debugger code
	nextreg REG_MMU,MAIN_BANK ; I cannot directly switch to MAIN_SLOT and jump there as this would require to many opcodes.
	; This code is executed in another bank (the MAIN_BANK)
	; ...
copy_rom_start_0066h_code_end

	; Executed in MAIN_BANK in slot 0.
	; Save layer 2 reading/writing
	ld a,HIGH LAYER_2_PORT
    in a,(LOW LAYER_2_PORT)
	ld b,a	; Save layer 2 read/write
	; Disable read/write: This is extremely dirty: In order not to use BC (as
	; it contains a required value) A is used for OUT. By luck the LAYER_2_PORT
	; high byte contains zeroes at the required bits to disable read/write.
	ld a,HIGH LAYER_2_PORT ; = 0x12 = 00010010, i.e. read and write disabled
    out (LOW LAYER_2_PORT),a
	; Now data can be loaded/saved

	; Save bank for slot 0
	ld a,c
	ld (slot_backup.slot0-MAIN_ADDR),a

	; Save layer 2 register
	ld a,b
	ld (backup.layer_2_port-MAIN_ADDR),a

	; Now take care to only reset read/write layer 2 bits and leave the rest alone
	res 0,a		; Rest layer 2 writes without affecting flags
	res 2,a		; Rest layer 2 reads without affecting flags
	ld bc,LAYER_2_PORT
	out (c),a

	; Now backup used/main slot.
	ld bc,IO_NEXTREG_REG
	ld a,REG_MMU+MAIN_SLOT
	out (c),a
	; Read register (cannot use IN A,(C) as this affect P/V)
	ld a,HIGH IO_NEXTREG_DAT
	in a,(LOW IO_NEXTREG_DAT)	; A contains the previous bank number for MAIN_SLOT
	ld (slot_backup.slot7-MAIN_ADDR),a

	; Page in slot7
	nextreg REG_MMU+MAIN_SLOT,MAIN_BANK
	; Now the labels can be used directly (for data access)

	ld (backup.sp),sp

	; Use new stack
	ld sp,backup.af+2

	; Save registers
	push af, bc, de, hl, ix, iy		; Note: AF and BC need to be corrected later. A and BC is wrong, flags contain the interrupt state

	; Switch registers
	exx
	ex af,af'

	push af, bc, de, hl

	; I and R register
	; TODO: muss ich anders machen: ld a,i/r: beide verändern das P/E flag.
	ld a,r
	ld l,a
	ld a,i		; TODO: This always indicate interrupts are off, should store the real value
	ld h,a
	push hl
	
	; Save IM, TODO: doesn't make sense
	ld hl,0
	push hl

	; Switch back registers
	ex af,af'
	exx
	; End of register saving through pushing

	; Load SP for debugger
	ld sp,debug_stack.top
	jp enter_debugger

copy_rom_start_code_end

	ENT	; End of DISPlaced code

	ORG MAIN_SLOT*0x2000+copy_rom_start_code_end

;===========================================================================
; Called by RST 0 or JP 0.
; This point is reached when the program e.g. runs into a RST 0.
; This indicates that either a breakpoint was hit (RST 0)
; or the coop code has called it because the debugged program wants to
; check for data on the UART (JP 0).
; The cases are distinguished by the stack contents:
; - Breakpoint: The stack contains the return address to the debugged program
;   which is != 0.
; - Coop code: A 0 has been put on the stack. The next value on the stack is
;   the return address to the debugged program.
; When entered:
; - PUSHED AF: F contains the interrupt enabled state in P/V (PE=interrrupts enabled),
;              A contains the used memory bank for slot 0
; - A contains the last used memory bank for MAIN_SLOT
; - interrupts are turned off (DI)
;
; Stack for a SW breakpoint (RST 0):
; - [SP+6]:	The return address (!=0)
; - [SP+4]:	AF was put on the stack
; - [SP+2]:	AF (Interrupt flags) was put on the stack
; - [SP]:	BC
; Stack for a function call from the debugged program
; - [SP+10]:	The return address
; - [SP+8]:	Function number
; - [SP+6]: 0x0000, to distinguish from SW breakpoint
; - [SP+4]:	AF was put on the stack
; - [SP+2]:	AF (Interrupt flags) was put on the stack
; - [SP]:	BC
; Stack for a function call from the debugged program if a parameter is used
; - [SP+12]:	The return address
; - [SP+10]:	Parameter
; - [SP+8]:	Function number
; - [SP+6]: 0x0000, to distinguish from SW breakpoint
; - [SP+4]:	AF was put on the stack
; - [SP+2]:	AF (Interrupt flags) was put on the stack
; - [SP]:	BC
;===========================================================================
enter_debugger:
	; Save interrupt state
	;push af
    
	; Disable the M1 (MF NMI) button
    call mf_nmi_disable

	; Save clock speed
	ld a,REG_TURBO_MODE
	call read_tbblue_reg
	ld (backup.speed),a

	; Change clock speed
	nextreg REG_TURBO_MODE,RTM_28MHZ

	; Save border
	in a,(BORDER)
	ld (backup.border_color),a

	; Read user stack
	ld hl,(backup.sp)
	ld de,DEBUGGED_PRGM_USED_STACK_SIZE
	ld bc,debugged_prgm_stack_copy
	call read_debugged_prgm_mem

	; Restore slot 0 bank
	ld a,(slot_backup.slot0)
	nextreg REG_MMU,a

	; Check interrupt state: Flags and pushed AF (P/V): the interrupt state. If either one is PE then the interrupts are enabled.
	ld a,0100b
	ld hl,backup.af	; Point to flags
	bit 2,(hl)			; Check flags
 	jp nz,.int_found   	; IFF was 1 (interrupts enabled)

	; 2nd try
	ld hl,debugged_prgm_stack_copy.af_interrupt
	bit 2,(hl)			; Check other flags
    jp nz,.int_found   	; IFF was 1 (interrupts enabled)

	; Interrupts were disabled
	xor a

.int_found:
	; Store interrupt state in bit 2
	ld (backup.interrupt_state),a
	; LOGPOINT [INT] Saving interrupt state: ${A:hex}h

	; Correct the saved values
	ld hl,(debugged_prgm_stack_copy.bc)
	ld (backup.bc),hl
	ld hl,(debugged_prgm_stack_copy.af)
	ld (backup.af),hl
	
	; Determine if breakpoint or coop code
	ld hl,(debugged_prgm_stack_copy.other)	; Get value from "stack"
	; Check for 0
	ld a,l
	or h 
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
; - [SP+6]:	The return address (!=0)
; - [SP+4]:	AF was put on the stack
; - [SP+2]:	    AF (Interrupt flags) was put on the stack
; - [SP]:	    BC
; Note: The SP will be corrected to point to SP+4.
;===========================================================================
enter_breakpoint:
	; LOGPOINT [DEFAULT] enter_breakpoint

   	; Maximize clock speed
	nextreg REG_TURBO_MODE,RTM_28MHZ

	; Put and correct the return address to the breakpoint address
	ld de,(debugged_prgm_stack_copy.other)	
	dec de
	ld (backup.pc),de

	; Backup AF
	ld hl,(debugged_prgm_stack_copy.af)	
	ld (backup.af),hl

	; Adjust debugged program SP
	ld hl,(backup.sp)	
	add hl,4*2	; Skip complete stack
	ld (backup.sp),hl	

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

