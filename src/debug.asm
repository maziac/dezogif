;===========================================================================
; debug.asm
;
; Include this for a few rudimentary debug functions for output on the
; ZX Spectrum ULA screen.
;
; Basic functionality:
; - dbg.clear: start logging, clear the logged lines
; - dbg.log: log a single character
; - dbg.log_number: log a number
; - dbg.print: print all (not yet printed) logs to the screen.
;
; Do not use these function directly but the macros defined
; in marcro.asm.
; Example:
; DBG_CLEAR
; DBG_LOG 'A'
; DBG_LOG 'B'
; ld hl,32123
; DBG_LOG_NUMBER hl
; DBG_PRINT
;
; Output: "AB#32123_"
;
; Note: The output functions do not set any colors.
; The output defaults to the last 3 lines of the screen.
; Make sure that the corresponding color screen
; attributes are set to somethign visible.
; ===========================================================================



	MODULE dbg

; TODO: test line wrapping.



; Data area

; The log output start in columns and lines (not pixels).
TEXT_START_POSITION_CLMN:	equ 0
TEXT_START_POSITION_LINE:	equ 21

text:
    defb "................................"
    defb "................................"
    defb "................................"
text_end:

    defb 0  ; End

; Points to the next location the next 'log' will insert the character.
text_next_ptr:
    defw text

; Points after the lasted printed character.
text_last_printed_ptr:
    defw text

; Stores the last screen address, after the last print call.
; Used for the next print location.
text_last_printed_screen_addr:
    defw text


;===========================================================================
; Clears the complete text area (text_dbg_ptr_val to text_dbg_ptr_val_end)
; and fills it with '-'.
; Does also print the area.
; Changes:
;  -
;===========================================================================
clear:
	push af, hl, de, bc
	ld hl,text
	ld (text_next_ptr),hl
	; Fill with '-'
	MEMFILL text, '-', text_end-text
	; Caclulate screen address
	ld de,256*8*TEXT_START_POSITION_LINE + 8*TEXT_START_POSITION_CLMN
	call text.ula.calc_address
	ld (text_last_printed_screen_addr),hl	; store screen start address
	push hl
	; Print "----" line
	ld hl,text_end
	ld (text_next_ptr),hl
	ld hl,text
	ld (text_last_printed_ptr),hl
	call print
	; Start for next character
	pop hl
	ld (text_last_printed_screen_addr),hl	; store screen start address
	ld hl,text
	ld (text_next_ptr),hl
	ld (text_last_printed_ptr),hl
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
	ld de,text_end
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
	call dbg.log

	; Number
	ld de,(text_next_ptr)
	call itoa_5digits
	inc de
	ld (text_next_ptr),de

	; Suffix
	ld a,'_'
	call dbg.log
	pop hl, de, bc, af
	ret

; Logs the nnumber in A
log_number_a:
	push af, bc, de, hl
	; Store to hl
	ld l,a
	ld h,0

	; Prefix
	ld a,'#'
	call dbg.log

	; Number
	ld de,(text_next_ptr)
	call itoa_5digits.three_digits
	inc de
	ld (text_next_ptr),de

	; Suffix
	ld a,'_'
	call dbg.log
	pop hl, de, bc, af
	ret


;===========================================================================
; Prints all log characters that have not been printed yet.
; Changes:
;  -
;===========================================================================
print:
	push af, bc, de, hl, ix
	ld de,(text_last_printed_ptr)
	ld hl,(text_last_printed_screen_addr)

.loop:
	; Check for end
	push hl
	ld hl,(text_next_ptr)
	or a
	sbc hl,de
	pop hl
	jr z,.end

	; print
	ld a,(de)
    call .print_char
	inc l	; Next x-position

	; increment read pointer
	ld de,(text_last_printed_ptr)
	inc de
	ld (text_last_printed_ptr),de
	jr .loop

.end:
	; Remember
	ld (text_last_printed_screen_addr),hl
	pop ix, hl, bc, de, af
	ret

; Prints A by replacing, not XORing.
.print_char:
    push hl
    push hl
    ; Calculate offset of character in font
    ld e,a
    ld d,8  ; 8 byte per character
    mul d,e
    ; Add to font start address
    ld hl,(font_address)
    add hl,de
    ld ix,hl    ; ix points to character in font
    ; Now copy the character to the screen
    pop hl

    ld c,8  ; 8 byte per character
.char_loop:
    ldi a,(ix)  ; Load from font
    ld (hl),a	; Place on screen
    ; Next line
    PIXELDN
    ; Next
    dec c
    jr nz,.char_loop

    ; Restore screen address
    pop hl
    ret

	ENDMODULE


