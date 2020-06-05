;===========================================================================
; breakpoints.asm
;
; For a SW breakpoint a RST 0 is substituted with the opcode so that a
; breakpoint can be recognized.
; Breakpoints work in 2 main phases:
; If the breakpoint occurs another temporary breakpoint is set after the
; instruction.
; This second breakpoint is necessary to execute the substituted instruction,
; to break after it to resotre the original breakpoint.
; Here is a raw state diagram:
/*
             ╔═════════════════════════════╗                           
             ║                             ║                           
             ║        STATE.NORMAL         ║                           
             ║          (Running)          ║                           
             ║                             ║                           
             ║                             ║                           
             ╚═════════════════════════════╝                           
                 │                   ▲                                 
                 │                   │                                 
                 │                   │                                 
                 │         ┌─────────┴──────────┐                      
                 │         │  Restore opcode 2  │                      
                 │         └────────────────────┘                      
                 │                   ▲                                 
                 │                   │ Temporary breakpoint hit        
                 │                   │                                 
  Breakpoint hit │         ┌─────────┴──────────┐                      
                 │         │ Set temporary BPs, │                      
                 │         │   Restore opcode   │                      
                 │         └────────────────────┘                      
                 │                   ▲                                 
                 │                   │ Continue                        
                 ▼                   │                                 
            ╔════════════════════════════╗                             
            ║                            ║                             
            ║                            ║                             
            ║  STATE.ENTERED_BREAKPOINT  ║                             
            ║                            ║                             
            ║                            ║                             
            ╚════════════════════════════╝                             
*/
;
;
; Notes:
; - address 0x0000 is special. Here is the RST command. So it is not possible
;   to se t a breakpoint here. The value 0x0000 is also used as undefined.
;===========================================================================


;===========================================================================
; Constants
;===========================================================================

; States
STATE:
.NORMAL				EQU 0
.ENTERED_BREAKPOINT	EQU 1


; The breakpoint reasons.
BREAK_REASON:	
.NO_REASON			EQU 0
.MANUAL_BREAK		EQU 0
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
bp_address		defw	; The location of the temporary breakpoint 
	ENDS


;===========================================================================
; Data. 
;===========================================================================


; Temporary storage for the breakpoints during 'cmd_continue'
tmp_breakpoint_1:	TMP_BREAKPOINT
tmp_breakpoint_2:	TMP_BREAKPOINT


;===========================================================================
; Called by RST 0.
; I.e. this point is reached when the program runs into a RST 0.
; I.e. this indicates that a breakpoint was hit.
; The location just after the breakpoint can be found from the SP.
; I.e. it was pushed on stack because of the RST.
;===========================================================================
enter_breakpoint:
   	; Backup all registers 
	call save_registers
	; SP is now at debug_stack_top

	; Breakpoint entered

	; Maximize clock speed
	ld a,RTM_28MHZ
	nextreg REG_TURBO_MODE,a

	; Check if temporary breakpoint hit
	ld de,(backup.pc)	
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
;TODO: unit test this.


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
	ld (hl),BP_INSTRUCTION
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
	

;===========================================================================
; Sets a new breakpoint.
; Exchanges the location with a RST opcode.
; Parameters:
;  HL = breakpoint address
; Returns:
;  A = original opcode at breakpoint address
;===========================================================================
/*
 	MACRO SET_BREAKPOINT
	; Substitute opcode
	ld a,(hl)	; Original opcode
	ld (hl),BP_INSTRUCTION
	ENDM
*/
