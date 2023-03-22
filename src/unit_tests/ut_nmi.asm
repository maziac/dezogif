;========================================================
; ut_nmi.asm
;
; Unit tests for the NMI.
; Not much to test here as this requires HW.
; But a few tests done by simulating 'nextreg'.
;========================================================


    MODULE ut_nmi


; In core 03.01.10 the NMI can be caused not only by the button.
; Check that in the other case the function immeidately returns.
UT_nmi_cause_wrong:
	; Redirect (modify) NMI ISR.
    MEMCOPY MF.nmi66h.is_button_cause, .jmp, 3

	; Simulate a different cause
	ld a,0b00000100
	ld bc,0x0002
	out (c),a	; Note: this will trigger writing to 0x7FFD (switching memory) as well. Use with care.
	; Test
	call MF.nmi66h

	; Simulate a different cause
	ld a,0b00001000
	ld bc,0x0002
	out (c),a
	; Test
	call MF.nmi66h

	; Simulate a different cause
	ld a,0b00010000
	ld bc,0x0002
	out (c),a
	; Test
	call MF.nmi66h
 TC_END
.jmp:
	jp .fail
.fail:
	TEST_FAIL	; If jumped here the testcase has failed


; Check that in case of a button press the NMI function is executed.
UT_nmi_cause_button:
	; Redirect (modify) NMI ISR.
    MEMCOPY MF.nmi66h.is_button_cause, .jmp, 3

	; Simulate button cause
	ld a,0b11100011
	ld bc,0x0002
	out (c),a
	; Test
	call MF.nmi66h

	TEST_FAIL	; If returned here the testcase has failed

.jmp:
	jp .success
.success:
 	TC_END	; If jumped here the testcase has passed


    ENDMODULE
