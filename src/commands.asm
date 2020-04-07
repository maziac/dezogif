;===========================================================================
; commands.asm
;
; 
;===========================================================================


    
;===========================================================================
; Constants
;===========================================================================




;===========================================================================
; Data. 
;===========================================================================



;===========================================================================
; CMD_GET_CONFIG
; Sends a response with the supported features.
; Changes:
;  HL
;===========================================================================
cmd_get_config:
	; Send length and seq-no
	ld de,2
	call send_length_and_seqno
	; Send config
	ld a,0b00000001
	jp write_uart_byte



;===========================================================================
; CMD_CONTINUE
; Continues debugged program execution.
; Restores the back'uped registers and jumps to the last
; execution point. The instruction after the call to 
; 'check_for_message'.
; Changes:
;  NA
;===========================================================================
cmd_continue:
	; Send response
	ld de,1
	call send_length_and_seqno
	; Restore registers



