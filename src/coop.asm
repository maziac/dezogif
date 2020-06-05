;===========================================================================
; coop.asm
;
; Subroutines to cooperate with teh debugged program.
;===========================================================================
 

;===========================================================================
; Constants
;===========================================================================


;===========================================================================
; Data. 
;===========================================================================



;===========================================================================
; Checks if a new messages has been received.
; If not then it returns without changing any register or flag.
; If yes the message is received and interpreted.
; Uses 2 words on the stack, one for calling the subroutine and one
; additional for pushing AF.
; Changes:
;  -
; Duration:
;  T-States=81 (with CALL), 2.32us@3.5MHz
;===========================================================================
dbg_check_for_message:			; T=17 for calling
	; Save AF
    push af						; T=11
	ld a,PORT_UART_TX>>8		; T= 7
	in a,(PORT_UART_TX&0xFF)	; T=11, Read status bits
    bit UART_RX_FIFO_EMPTY,a	; T= 8
    jr nz,.start_cmd_loop		; T= 7
	; Restore AF 
    pop af						; T=10
	ret			 				; T=10
.start_cmd_loop:
	; Restore AF
	pop af
	jp execute_cmd

