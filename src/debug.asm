;===========================================================================
; debug.asm
;
; Include this for a few rudimentary debug functions for output on the
; ZX Spectrum ULA screen.
; Note: These functions are meant for debugging dezogif itself.
;
; Basic functionality:
; - debug.clear: start logging, clear the logged lines
; - debug.log: log a single character
; - debug.log_number: log a number in hl
; - debug.log_number_a: log a number in a
; - debug.print: print all (not yet printed) logs to the screen.
;
; Do not use these function directly but the macros defined
; in macro.asm.
; Example:
; DBG_CLEAR
; DBG_LOG 'A'
; DBG_LOG 'B'
; ld c,5
; DBG_LOG_NUMBER8
; ld hl,32123
; DBG_LOG_NUMBER16 hl
; DBG_PRINT
;
; Output: "AB#005_#32123_"
;
; ===========================================================================



 IFDEF DEBUG

	MODULE debug

; Data area

; The log output start in columns and lines (not pixels).
TEXT_START_POSITION_CLMN:	equ 0
TEXT_START_POSITION_LINE:	equ 21

text:
	AT 0, 21
	COLOR GREEN
.start:
    defb "................................"
    defb "................................"
    defb "................................"
.end:

    defb 0  ; End

; Points to the next location the next 'log' will insert the character.
text_next_ptr:
    defw text.start


;===========================================================================
; Clears the complete text area (text_dbg_ptr_val to text_dbg_ptr_val_end)
; and fills it with '-'.
; Does also print the area.
; Changes:
;  -
;===========================================================================
clear:
	push af, hl, de, bc
	ld hl,text.start
	ld (text_next_ptr),hl
	; Fill with '-'
	MEMFILL text.start, '.', text.end-text.start
	call print
	pop bc, de, hl, af
	ret


;===========================================================================
; Logs a single character to the next position on screen.
; It is not yet printed (for performance reasons).
; You can print with 'dbg.print'.
; Changes:
;  -
;===========================================================================
log:
	push af, hl, de
	ld hl,(text_next_ptr)
	ld de,text.end
	or a
	sbc hl,de	; Check if too big
	jr z,.skip
	add hl,de
	ldi (hl),a
	ld (text_next_ptr),hl
.skip:
	pop de, hl, af
	ret


;===========================================================================
; ; Logs a number [0;65535] together with prefix and suffix.
; E.g. "#42768_"
; It is not yet printed (for performance reasons).
; You can print with 'dbg.print'.
; Parameter:
;	HL: contains the number to print [0-65535].
; Changes:
;  -
;===========================================================================
log_number:
	push af, bc, de, hl
	; Prefix
	ld a,'#'
	call debug.log

	; Number
	ld de,(text_next_ptr)
	ld hl,text.end-5-1
	or a
	sbc hl,de	; Check if too big
	jr c,.ret

	pop hl
	push hl
	call itoa_5digits
	inc de
	ld (text_next_ptr),de

	; Suffix
.ret:
	ld a,'_'
	call debug.log
	pop hl, de, bc, af
	ret

; Logs the number in A
log_number_a:
	push af, bc, de, hl
	; Store to hl
	ld l,a
	ld h,0
	push hl

	; Prefix
	ld a,'#'
	call debug.log

	; Number
	ld de,(text_next_ptr)
	ld hl,text.end-3-1
	or a
	sbc hl,de	; Check if too big
	jr c,.ret

	pop hl
	call itoa_5digits.three_digits
	inc de
	ld (text_next_ptr),de

	; Suffix
.ret:
	ld a,'_'
	call debug.log
	pop hl, de, bc, af
	ret


;===========================================================================
; Prints all log characters.
; Changes:
;  -
;===========================================================================
print:
	ld ix,text
	jp text.ula.print_string

	ENDMODULE

 ENDIF
