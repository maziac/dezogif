;===========================================================================
; data.asm
;
; All volatile data is defined here.
;
; Note: The area does not need to be copied. i.e. is initialized on the fly.
;===========================================================================



;===========================================================================
; BSS data
;===========================================================================


; If an error occures it is stored here for display.
last_error: defb 0


;===========================================================================
; Main use: breakpoint.asm

; Temporary storage for the breakpoints during 'cmd_continue'
tmp_breakpoint_1:	TMP_BREAKPOINT
tmp_breakpoint_2:	TMP_BREAKPOINT



; Used to stroe the stack contents of the debugged program.
; This contains the info passed onthe stack to the debugger.
; - [SP+10]:	The return address
; - [SP+8]:	    Optional: Bit 0-3: Function number, Bit 4-7: Optional parameter
; - [SP+6]:     Optional: 0x0000, to distinguish from SW breakpoint
; - [SP+4]:	    AF was put on the stack
; - [SP+2]:	    AF (Interrupt flags) was put on the stack
; - [SP]:	    BC
debugged_prgm_stack_copy:
.bc:                defw 0
.af_interrupt:      defw 0
.af:                defw 0
.return1:           defw 0
.function_number:   defb 0
.parameter:         defb 0
.return2:           defw 0
.end
DEBUGGED_PRGM_USED_STACK_SIZE:  equ debugged_prgm_stack_copy.end-debugged_prgm_stack_copy

;===========================================================================
; Main use: backup.asm


; Stack: this area is reserved for the stack
STACK_SIZE: equ 100    ; in words


; The debug stack begins here.
debug_stack:	defs STACK_SIZE*2, 0xAA
.top:


; Small stack used for special purpose by NMI.
nmi_small_stack:	defs 10, 0x55
.top:
nmp_sp_backup:		defw 0


; The registers of the debugged program are stored here.
backup:
.im:				defb 0	; Note: IM cannot be saved
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
.layer_2_port:		defb 0
.border_color:		defb 0
.io_next_reg:		defb 0
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
	defs 11	; maximum used count for CMD_CONTINUE structure (PAYLOAD_CONTINUE)

; Just for testing buffer overflow:
	defb 0	; WPMEM
	defb  0xff, 0xff

payload_set_reg:	PAYLOAD_SET_REG = receive_buffer.payload
payload_add_breakpoint:	PAYLOAD_ADD_BREAKPOINT = receive_buffer.payload
payload_remove_breakpoint:	PAYLOAD_REMOVE_BREAKPOINT = receive_buffer.payload

payload_continue:	PAYLOAD_CONTINUE = receive_buffer.payload
payload_read_mem:	PAYLOAD_READ_MEM = receive_buffer.payload
payload_write_mem:	PAYLOAD_WRITE_MEM = receive_buffer.payload


;===========================================================================
; Main use: uart.asm

; Color is changed after each received message.
border_color:	defb BLACK


;===========================================================================
; Main use: utilities.asm, breakpoints.asm

; Temporary data area to be used by several subroutines.
tmp_data:   defs 4
tmp_clip_window = tmp_data



;===========================================================================
; Used by backup.asm

slot_backup:	SLOT_BACKUP


;===========================================================================
; Used by main.asm

; Stores the current UART selection:
; 0 = no joy port
; 1 = joy 1
; 2 = joy 2
uart_joyport_selection: defb 0

; Selection if border is slowly changing or not.
; 0 = off
; 1 = on
slow_border_change:	defb 1


;===========================================================================
; Used by: text.asm

; The address of character 0 of the font. Each font character is 8 byte in size
; and there can be up to 256 of them (although 0 is not used).
; I.e. you can safely set this 8 bytes below character at index 1.
font_address:   defw    ROM_START+ROM_SIZE-ROM_FONT_SIZE-0x20*8


;===========================================================================
; Used by: mf_rom.asm
prgm_state:	defb PRGM_IDLE


;===========================================================================
; Used by: ui.asm
text_one_char:
    defb AT, 14*8, 4*8
.char:
	defb 0, 0

text_core_version:
    defb AT, 6*8, 2*8
.major:
	defb '00'
	defb '.'
.minor:
	defb '00'
	defb '.'
.subminor:
	defb '00'
	defb 0

