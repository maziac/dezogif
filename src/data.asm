;===========================================================================
; data.asm
;
; All volatile data is defined here.
;===========================================================================


;===========================================================================
; Stack. 
;===========================================================================

; Stack: this area is reserved for the stack
STACK_SIZE: equ 100    ; in words


; Reserve stack space
    defw 0  ; WPMEM, 2
stack_bottom:
    defs    STACK_SIZE*2, 0
stack_top:  
    defw 0  ; WPMEM, 2



;===========================================================================
; Data. 
;===========================================================================

;===========================================================================
; Main use: breakpoint.asm

; Temporary storage for the breakpoints during 'cmd_continue'
tmp_breakpoint_1:	TMP_BREAKPOINT
tmp_breakpoint_2:	TMP_BREAKPOINT


;===========================================================================
; Main use: backup.asm

; The debug stack begins here. SP flows from backup in here.
debug_stack:	defs 50
debug_stack_top:

; The registers of the debugged program are stored here.
backup:
.im:				defb 0	; TODO: cannot be saved
.reserved:			defb 0
.r:					defb 0
.i:					defb 0
.hl2:				defw 0
.de2:				defw 0
.bc2:				defw 0
.af2:				defw 0
.iy:				defw 0
.ix:				defw 0
.hl:				defw 0
.de:				defw 0
.bc:				defw 0
.af:				defw 0
.sp:				defw 0
.pc:				defw 0
.interrupt_state:	defb 0	; P/V flag -> Bit 2: 0=disabled, 1=enabled
;.save_mem_bank:		defb 0
.speed:				defb 0
.border_color:		defb 0
backup_top:


;===========================================================================
; Main use: message.asm

; The UART data is put here before being interpreted.
receive_buffer: 
.length:
	defw 0, 0		; 4 bytes length
.seq_no:
	defb 0
.command:
	defb 0
.payload:
	defs 6	; maximum used count for CMD_CONTINUE structure

; Just for testing buffer overflow:
	defb  0xff, 0xff


;===========================================================================
; Main use: uart.asm

; Color is changed after each received message.
border_color:	defb BLACK


;===========================================================================
; Main use: utilities.asm

; Temporary data area to be used by several subroutines.
tmp_data:   defs SLOT_BACKUP	; SLOT_BACKUP is the max. usage (8 bytes)
tmp_clip_window = tmp_data
slot_backup:	SLOT_BACKUP = tmp_data

