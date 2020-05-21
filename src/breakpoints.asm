;===========================================================================
; breakpoints.asm
;===========================================================================

;===========================================================================
; Constants
;===========================================================================

; The breakpoint reasons.
BREAK_REASON:	
.NO_REASON:			EQU 0
.MANUAL_BREAK:		EQU 1
.BREAKPOINT_HIT:	EQU 2
    
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

