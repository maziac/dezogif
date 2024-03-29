;===========================================================================
; macros.asm
;
; Macro definitions.
;===========================================================================


;===========================================================================
; Macro to write a Z80 register to a specific next register.
; E.g. use:  WRITE_TBBLUE_REG 0x13,d
; Writes register to to 0x13.
; Uses 5 bytes.
; Parameters:
;   tbblue_reg = A ZX Next register
;   z80_reg = a Z80 register, e.g. d, e, c etc.
; Changes:
;   A
;===========================================================================
	MACRO WRITE_TBBLUE_REG tbblue_reg?, z80_reg?
	ld a,z80_reg?
	nextreg tbblue_reg?,a
	ENDM


;===========================================================================
; Macro to copy a memory area from src to dest.
; Parameters:
;	dest = Pointer to destination
;   src = Pointer to source
;   count = The number of bytes to copy.
; Changes:
;   BC, DE, HL
;===========================================================================
	MACRO MEMCOPY dest?, src?, count?
	ld bc,count?
    ld hl,src?
    ld de,dest?
    ldir
	ENDM


;===========================================================================
; Macro to fill a memory area with a certain value.
; Parameters:
;	dest = Pointer to destination
;   value = The byte value used to fill the area.
;   count = The number of bytes to fill.
; Changes:
;   F, BC, DE, HL
;===========================================================================
	MACRO MEMFILL dest?, value?, count?
	ld bc,count?-1
    ld hl,dest?
	ld (hl),value?
    ld de,dest?+1
    ldir
	ENDM


;===========================================================================
; Macro to clear a memory area with zeroes.
; Parameters:
;	dest = Pointer to destination
;   count = The number of bytes to clear.
; Changes:
;   F, BC, DE, HL
;===========================================================================
	MACRO MEMCLEAR dest?, count?
	MEMFILL dest?, 0, count?
	ENDM

;===========================================================================
; Macro to clear the memory area at HL with zeroes.
; Parameters:
;   count = The number of bytes to clear.
; Changes:
;   F, BC, DE, HL
;===========================================================================
	MACRO MEMCLEARHL count?
	ld bc,count?-1
	ld (hl),0
    ld de,hl
	inc de
    ldir
	ENDM


;===========================================================================
; Macro to set a byte value in a memory location.
; Parameters:
;	dest = Pointer to destination
;   value = The byte value to set
; Changes:
;   A
;===========================================================================
	MACRO MEMSETBYTE dest?, value?
	ld a,value?
	ld (dest?),a
	ENDM


;===========================================================================
; Macro to set a word value in a memory location.
; Parameters:
;	dest = Pointer to destination
;   value = The byte value to set
; Changes:
;   HL
;===========================================================================
	MACRO MEMSETWORD dest?, value?
	ld a,value? & 0xFF
	ld (dest?),a
	ld a,value? >> 8
	ld (dest?+1),a
	ENDM

;===========================================================================
; Creates text data from a number.
; E.g. number 123456 will translate to
;  defb '123456'
; Leading zeroes are skipped.
; Parameters:
;	number = The number to translate.
; Changes:
;   -
;===========================================================================
	MACRO STRINGIFY number?
value = number?
divisor = 1000000
digit = 0
skip = 0
    DUP 7
digit = value / divisor
skip = skip + digit
    IF skip != 0
        defb digit+'0'
    ENDIF
value = value-digit * divisor
divisor = divisor / 10
    EDUP
	ENDM


;===========================================================================
; Creates a Multiface NMI break.
; Note: did not work for me!
;===========================================================================
	MACRO MF_BREAK
	push af
	ld a,r
	di
	in a,(0x3F)
	rst 8
	ENDM



; Debug macros:
 IFDEF DEBUG

;===========================================================================
; Clears the logged lines, also on screen.
; Starts/inits logging.
; Sets the logging position to the start of the lines.
; Lines are shown as "-------".
; Parameters:
;   none
; Changes:
;   -
;===========================================================================
	MACRO DBG_CLEAR
	call debug.clear
	ENDM


;===========================================================================
; Logs a single character to the next position.
; Parameters:
;   val: the character to log, e.g. 'A' or '5'.
; Changes:
;   -
;===========================================================================
	MACRO DBG_LOG val?
	push af
	ld a,val?
	call debug.log
	pop af
	ENDM


;===========================================================================
; Logs a number [0;65535] together with prefix and suffix.
; E.g. "#42768_"
; Parameters:
;   val: ???
; Changes:
;   -
;===========================================================================
	MACRO DBG_LOG_NUMBER number?
	push hl
	ld hl,number?
	call debug.log_number
	pop hl
	ENDM
	MACRO DBG_LOG_NUMBER_A
	call debug.log_number_a
	ENDM


;===========================================================================
; Prints the logged values.
; Only prints new values.
; Parameters:
;   -
; Changes:
;   -
;===========================================================================
	MACRO DBG_PRINT
	call debug.print
	ENDM

 ELSE
	; Define empty macros
	MACRO DBG_CLEAR
	ENDM
	MACRO DBG_LOG val?
	ENDM
	MACRO DBG_LOG_NUMBER number?
	ENDM
	MACRO DBG_PRINT
	ENDM
 ENDIF