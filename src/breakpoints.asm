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

; The number of possible breakpoints.
BREAKPOINT_LIST_COUNT:	EQU 20 


; The breakpoint structure to save.
	STRUCT BREAKPOINT
instruction_length	defb	; The length of the 'breaked' instruction. 0 indicates a free location.
address				defw	; The location of the breakpoint
;branch_address		defw	; The optional branch address of the instruction	
opcode				defb	; The substituted opcode
	ENDS


;===========================================================================
; Data. 
;===========================================================================

; The overall state
state:		defb 0


;breakpoint_list:	DUP BREAKPOINT_LIST_COUNT 
;                        BREAKPOINT
;                    EDUP
breakpoint_list:	defs BREAKPOINT_LIST_COUNT * BREAKPOINT, 0
.end

; Temporary storage for the breakpoint during ENTERED_BREAKPOINT state.
tmp_breakpoint_address_1_1:	defw	0
; Temporary storage for the breakpoint after the original breakpoint during ENTERED_BREAKPOINT state.
tmp_breakpoint_address_1_2:	defw	0
; Temporary storage for opcode at tmp_breakpoint_address_1_2.
tmp_breakpoint_opcode:	defb	0


;===========================================================================
; Clears all breakpoints.
;===========================================================================
clear_breakpoints:
	MEMCLEAR breakpoint_list, BREAKPOINT_LIST_COUNT * BREAKPOINT
	ret


;===========================================================================
; Called by RST 0.
; I.e. thispoint is reached when the program runs into a RST 0.
; I.e. this indicates that a breakpoint was hit.
; The location just after the breakpoint can be found from the SP.
; I.e. it was pushed on stack because of the RST.
;===========================================================================
enter_breakpoint:
   	; Backup all registers 
	call save_registers
	; SP is now at debug_stack_top

	; Check state
	ld a,(state)
	or a	; 0 = NORMAL
	jr nz,.restore_breakpoint

	; Breakpoint entered

	; Maximize clock speed
	ld a,RTM_28MHZ
	nextreg REG_TURBO_MODE,a

    ; Send pause notification
	ld d,BREAK_REASON.BREAKPOINT_HIT
	ld hl,(backup.pc)
	call send_ntf_pause
	;jp cmd_loop

	; Get breakpoint address
	ld hl,(backup.pc)	
	; And save
	ld (tmp_breakpoint_address_1_1),hl 
	; Change state
	ld a,STATE.ENTERED_BREAKPOINT
	ld (state),a
	jp cmd_loop

.not_found:
	; Should not happen, i.e. we breaked at a location for which no breakpoint exists.
	jp cmd_loop	; Put a breakpoint here; ASSERT

.restore_breakpoint:
	; In the middle of a breakpoint action. The temporary breakpoint has been hit.
	; Restore temporary opcode
	ld hl,(tmp_breakpoint_address_1_2)
	ld a,(tmp_breakpoint_opcode)	; Get original opcode
	ld (hl),a
	; Set the breakpoint again at previous location
	ld hl,(tmp_breakpoint_address_1_1)
	ld (hl),BP_INSTRUCTION
	; change state to normal
	xor a
	ld (state),a
	; Continue 
	jp restore_registers

.continue:
	ld a,(state)
	or a
	jr z,.just_restore

	; Substitute breakpoint with original opcode
	; Get breakpoint address
	ld hl,(tmp_breakpoint_address_1_1)
	call find_breakpoint
	jr nz,.not_found
	; hl contains bp id
	ldi a,(hl)	; Get opcode length
	inc hl : inc hl	; move to opcode
	ld c,(hl)
	ld hl,(tmp_breakpoint_address_1_1)	; Get breakpoint address
	; Restore original opcode
	ld (hl),c

	; Add temporary breakpoint just after the original opcode
	add hl,a	; Add opcode length
	ld a,(hl)	; Get original opcode
	ld (tmp_breakpoint_address_1_2),hl 
	ld (tmp_breakpoint_opcode),a 
	ld (hl),BP_INSTRUCTION

.just_restore:
    jp restore_registers


;===========================================================================
; Sets a new breakpoint.
; Exchanges the location with a RST opcode and puts the breakpoint in a list.
; If we are in the middle of a breakpoint execution (STATE.ENTERED_BREAKPOINT)
; then we need to check first it opcode is already temporary exchanged.
; Parameters:
;  HL = breakpoint address
; Returns:
;  HL = Location of added breakpoint. Is used as breakpoint ID.
;       0 if no breakpoint available anymore.
;  Z = Breakpoint added
;  NZ = Breakpoint not added. List is full.
;===========================================================================
add_breakpoint:
	push hl
	; Find free breakpoint from list
	call get_free_breakpoint
	pop de	; breakpoint address
	jr nz,.no_free_location 	; no free location found
	
	; Insert in list
	ldi (hl),1	; occupied, instruction_length
	ldi (hl),de ; the breakpoint address
	
	; Substitute opcode
	ld a,(de)	; Original opcode
	ld (hl),a	; Store in breakpoint structure
	ld a,BP_INSTRUCTION
	ld (de),a
	; Correct hl to start of breaklpoint location
	add hl,-BREAKPOINT.opcode
	ret
.no_free_location:
	ld hl,0
	ret
 
;===========================================================================
; Removes a breakpoint.
; Exchanges the location with a original opcode and removes the breakpoint 
; from the list.
; Parameters:
;  HL = Breakpoint ID. This is the location (address) inside the breakpoint_list.
; Changes:
;  A, HL, DE
;===========================================================================
remove_breakpoint:
	; Check if location contains a breakpoint
	xor a
	cp (hl)
	ret z	; Returns immediately if no active breakpoint

	; Clear breakpoint
	xor a
	ldi (hl),a
	; Get breakpoint address
	ld de,(hl)
	ldi (hl),a : ldi (hl),a
	; Get the original opcode
	ld a,(hl)
	ld (hl),0	; and clear

	; Restore original opcode
	ld (de),a
	ret


;===========================================================================
; Returns a free breakpoint location in the list.
; Returns:
;  HL = address of free location in list.
;	    0x0000 if no free location available.
;  Z = location found
;  NZ = no free location found
;===========================================================================
; TODO: Check if used at all.
get_free_breakpoint:
	ld hl,breakpoint_list
	ld de,BREAKPOINT	; size of struct
	ld b,BREAKPOINT_LIST_COUNT
	xor a	; Search for 0 entry
.loop:
	cp (hl)
	ret z	; found
	add hl,de
	djnz .loop
	; not found, HL = 0
	inc a	; Force NZ
	ret


;===========================================================================
; Searches for the given breakpoint.
; Returns:
;  HL = address of free location in list.
;  Z = found
;  NZ = not found
;===========================================================================
find_breakpoint:
	ex de,hl	; de = breakpoint to find
	ld hl,breakpoint_list+BREAKPOINT.address
	ld b,BREAKPOINT_LIST_COUNT
	ld a,e
.loop:
	; compare low byte
	cp (hl)
	jr nz,.not_equal
	; compare high byte
	inc hl 
	ld a,d
	cp (hl)
	dec hl
	ld a,e
	jr z,.equal	; found
.not_equal:
	add hl,BREAKPOINT	; size of struct
	djnz .loop
	; not found, HL = 0
	; TODO: brauche ich hl=0 ?
	ld a,1
	or a	; To force NZ. 
	ld h,a
	ld l,a
	ret

.equal:
	; let HL point to the beginning of the struct
	add hl,-BREAKPOINT.address
	ret


/*
Doesn't work:
;===========================================================================
; Returns the length of tthe instruction at HL.
; Parameter:
;  HL = address of the instruction
; Returns:
;  A = length [1-4]
;===========================================================================
get_instruction_length:
	ld a,5
	ld (.b_value+1),a
	ld de,.instruction+3
	; Fill sandbox
	ld a,(.fill_instruction)
	ldd (de),a : ldd (de),a : ldd (de),a
	
.loop:
	; (hl)->(de)
	ldi
	push hl, de
	ld hl,.b_value+1
	dec (hl)
	
	; sandbox ------
.b_value:
	ld b,4
.instruction:
	nop
	dec b
	dec b
	dec b
	; --------------

	pop de, hl
	djnz .loop

	; Found. Check which one.
	add de,-.instruction
	; e = instruction length
	ld a,e
	ret
.fill_instruction:
	dec b	
*/
