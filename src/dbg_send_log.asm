;===========================================================================
; dbg_send_log.asm
;
; Do not use the function here directly but the macros defined
; in macro.asm.
;
; E.g. use:
;   SEND_NTF_LOG "Value of A: $u1 and BC $h2", 3
;	SEND_NTF_LOG_BYTE a
;	SEND_NTF_LOG_WORD de
; Note as byte and word parameter you can use registers like A, B, C, D, E, H, L, BC, DE, HL
; SEND_NTF_LOG will overwrite a lot of registers, you should save what you need.
; SEND_NTF_LOG_ ....
;
; ===========================================================================


 IFDEF DBG_SEND_LOG

	MODULE dbg_send_log
;===========================================================================
; Sends a NTF_LOG notification
; Parameter:
; Returns:
;  -
; Changes:
;
;===========================================================================
log:
	; LOGPOINT [CMD] send_ntf_log
	; Write first byte to recognize message
	ld a,MESSAGE_START_BYTE
	call uart.write_tx_byte
	; First length byte
	ld a,e
	call uart.write_tx_byte
	; Second length byte
	ld a,d
	call uart.write_tx_byte
	; Rest of length + seqno=0
	xor a
	ld e,3
.loop:
	call uart.write_tx_byte
	dec e
	jr nz,.loop

	; Send NTF_LOG id
	ld a,NTF_LOG
	call uart.write_tx_byte

	; Send string starting at hl until 0
.send_string:
	ldi a,(hl)
	call uart.write_tx_byte
	or a	; Check if HL reached the end of string (0)
	jr nz,.send_string

	; Remaining data (if any) has to be sent by the caller.
	ret

	ENDMODULE

 ENDIF
