;===========================================================================
; data.asm
;
; All volatile data is defined here.
; 
; Note: The area does not need to be copied. i.e. is initiatlized on the fly.
;===========================================================================




;===========================================================================
; Const data
;===========================================================================

INTRO_TEXT: 
    defb AT, 0, 0
    PROGRAM_TITLE   ; E.g. "ZX Next UART DeZog Interface"
    defb AT, 0, 1*8
    PRG_VERSION
    defb AT, 0, 2*8
    defb "ESP UART Baudrate: "
    STRINGIFY BAUDRATE

;    defb AT, 0, 4*8
;    defb "Tx=7, Rx=9"
    defb AT, 0, 5*8
    defb "Keys:"
    defb AT, 0, 6*8
    defb "1 = Joy 1"
    defb AT, 0, 7*8
    defb "2 = Joy 2"
    defb AT, 0, 8*8
    defb "3 = No joystick port"
    defb AT, 0, 9*8
    defb "0 = Reset"
;.end
    defb 0

JOY1_SELECTED_TEXT:
    defb AT, 0, 3*8, "Using Joy 1 (left)", 0
JOY2_SELECTED_TEXT:
    defb AT, 0, 3*8, "Using Joy 2 (right)", 0
NOJOY_SELECTED_TEXT:
    defb AT, 0, 3*8, "No joystick port used.", 0

SELECTED_TEXT_TABLE:
    defw NOJOY_SELECTED_TEXT
    defw JOY1_SELECTED_TEXT
    defw JOY2_SELECTED_TEXT

;===========================================================================
; BSS data
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


;===========================================================================
; Used by main.asm

; Stores the current UART selection:
; 0 = no joy port
; 1 = joy 1
; 2 = joy 2
uart_joyport_selection: defb 0

;===========================================================================
; Used by: text.asm

; The address of character 0 of the font. Each font character is 8 byte in size
; and there can be up to 256 of them (although 0 is not used).
; I.e. you can safely set this 8 bytes below character at index 1.
font_address:   defw    ROM_START+ROM_SIZE-ROM_FONT_SIZE-0x20*8
