;===========================================================================
; breakpoints.asm
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
.NO_REASON:			EQU 0
.MANUAL_BREAK:		EQU 1
.BREAKPOINT_HIT:	EQU 2


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

;breakpoint_list:	DUP BREAKPOINT_LIST_COUNT 
;                        BREAKPOINT
;                    EDUP
breakpoint_list:	BLOCK BREAKPOINT_LIST_COUNT * BREAKPOINT, 0
.end

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

	; Maximize clock speed
	ld a,RTM_28MHZ
	nextreg REG_TURBO_MODE,a

	; LOGPOINTx NTF PREPARE

    ; Send pause notification
	ld d,BREAK_REASON.BREAKPOINT_HIT
	ld hl,(backup.pc)
	dec hl	; RST opcode has length of 1
	call send_ntf_pause
	
	; LOGPOINTx NTF SENT

    jp cmd_loop

  
;===========================================================================
; Sets a new breakpoint.
; Exchanges the location with a RST opcode and puts the breakpoint in a list.
; Parameters:
;  HL = breakpoint address
; Returns:
;  Z = Breakpoint added
;  NZ = Breakpoint not added. List is full.
;===========================================================================
add_breakpoint:
	push hl
	; Find free breakpoint from list
	call get_free_breakpoint
	ret nz 	; no free location found
	
	; Insert in list
	pop de	; breakpoint address
	ldi (hl),1	; occupied, instruction_length
	ldi (hl),de ; the breakpoint address
	
	; Substitute opcode
	ld a,(de)	; Original opcode
	ld (hl),a	; Store in breakpoint structure
	ld a,BP_INSTRUCTION
	ld (de),a
	ret

 
;===========================================================================
; Removes a breakpoint.
; Exchanges the location with a original opcode and removesputs the breakpoint 
; from the list.
; Parameters:
;  HL = breakpoint address
;===========================================================================
remove_breakpoint:
	push hl
	; Find breakpoint in the list
	call find_breakpoint
	ret nz 	; breakpoint not found
	
	; HL contains location
	; Clear
	xor a
	ldi (hl),a : ldi (hl),a : ldi (hl),a
	; Get the original opcode
	ld a,(hl)
	ld (hl),0	; and clear

	; Restore original opcode
	pop hl
	ld (hl),a
	ret


; TODO: UNIT TESTS for breakpoints:

;===========================================================================
; Returns a free breakpoint location in the list.
; Returns:
;  HL = address of free location in list.
;	    0x0000 if no free location available.
;  Z = location found
;  NZ = no free location found
;===========================================================================
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
	; TODO: brauche ich hl=0 ?
	ld h,a
	ld l,a
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

