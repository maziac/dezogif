;========================================================
; ut_message.asm
;
; Unit tests for the notification response.
;========================================================


    MODULE ut_message

; Test sending of the break notification.
UT_send_ntf_pause:
	; For seq no test
	xor a
	ld (receive_buffer.seq_no),a

	; Change jump into ret
	ld a,0xC9	; RET
	;ld (cmd_pause.jump),a

	; Test
	ld d,BREAK_REASON.MANUAL_BREAK
	ld hl,0x8234	; BP address
	call send_ntf_pause
	; Check response
 	call ut_commands.test_get_response
	; Test size
	TEST_MEMORY_WORD ut_commands.test_memory_payload.length, 7

	; Test notification
	TEST_MEMORY_BYTE ut_commands.test_memory_payload+1, 	1	; NTF_PAUSE
	TEST_MEMORY_BYTE ut_commands.test_memory_payload+2, BREAK_REASON.MANUAL_BREAK	; Break reason
	TEST_MEMORY_WORD ut_commands.test_memory_payload+3,	0x8234	; BP address
	TEST_MEMORY_WORD ut_commands.test_memory_payload+5,	4+1	; Bank
	TEST_MEMORY_BYTE ut_commands.test_memory_payload+6, 0	; No error text

 TC_END


    ENDMODULE
