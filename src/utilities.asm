;===========================================================================
; utilities.asm
;
; Misc subroutines.
;===========================================================================


;===========================================================================
; Constants
;===========================================================================


; Border
BORDER:     equ 0xFE

; Keyboard ports: Bits 0-4. Bit is low if pressed.
; Example: in PORT_KEYB_54321, 2 is bit 1. in PORT_KEYB_67890, 0 is bit 0
PORT_KEYB_54321:            equ 0xF7FE ; 5, 4, 3, 2, 1
PORT_KEYB_67890:            equ 0xEFFE ; 6, 7, 8, 9, 0
PORT_KEYB_BNMSHIFTSPACE:    equ 0x7FFE ; B, N, M, Symbol Shift, Space
PORT_KEYB_HJKLENTER:        equ 0xBFFE ; H, J, K, L, Enter
PORT_KEYB_YUIOP:            equ 0xDFFE ; Y, U, I, O, P
PORT_KEYB_TREWQ:            equ 0xFBFE ; T, R, E, W, Q
PORT_KEYB_GFDSA:            equ 0xFDFE ; G, F, D, S, A
PORT_KEYB_VCXZCAPS:         equ 0xFEFE ; V, C, X, Z, Caps Shift


; Clears the screen and opens channel 2
ROM_CLS                 EQU  0x0DAF
; Open a channel
ROM_OPEN_CHANNEL        EQU  0x1601
; Print a string
ROM_PRINT               EQU  0x203C


; The address of the original ZX Spectrum character set in ROM.
ROM_FONT:  equ 0x3D00
ROM_FONT_SIZE: equ 0x0300  ; 96 chars, [0x20..0x7F]

; The ROM start address and the ROM size (16k) of the Spectrum.
ROM_START:  equ 0x0000
ROM_SIZE: equ 0x4000  ; 16k


; DivMMC, see https://velesoft.speccy.cz/zx/divide/divide-memory.htm
; DivIDE control register (write only) 227 ($E3) in original DivIDE mode:
; D7		D6		D5	D4	D3	D2	D1		D0
; CONMEM	MAPRAM	X	X	X	X	BANK1	BANK0
; This register is write-only (readed data will be unknown).
; All bits are reset to '0' after each power-on. Unimplemented bits, marked 'X', should be zeroed.
; Bits BANK1 and BANK0 select the 8k bank, which normally appears in area 2000-3fffh, when divide memory is mapped.
DIVIDE_CTRL_REG:	EQU 0xE3


;===========================================================================
; Reads a TBBLUE register.
; Parameters:
;   A = The register to read
; Returns:
;   A = The value
; Changes:
;   BC, F
;===========================================================================
read_tbblue_reg:
	; Select register in A
	ld bc,IO_NEXTREG_REG
	out (c),a
	; Read register
	inc b	; IO_NEXTREG_DAT
	in a,(c)
	ret

;===========================================================================
; Reads a TBBLUE register.
; This is meant for multiple use. You need to set BC to IO_NEXTREG_REG
; before the first call.
; Is slighlty faster than read_tbblue_reg.
; Parameters:
;   A = The register to read
;   BC = IO_NEXTREG_REG
; Returns:
;   A = The value
; Changes:
;   F
;===========================================================================
read_tbblue_reg_multiple:
	; Select register in A
	out (c),a
	; Read register
	inc b	; IO_NEXTREG_DAT
	in a,(c)
	dec b
	ret


;===========================================================================
; Writes a color to the border and waits on press
; of SPACE.
; Changes:
;   A
;===========================================================================
	MACRO WAIT_SPACE color?
	ld a,color?
	out (BORDER),a
	; Wait on key press
.not_pressed:
	ld a,HIGH PORT_KEYB_BNMSHIFTSPACE
	in a,(LOW PORT_KEYB_BNMSHIFTSPACE)
	bit 0,a	; SPACE
	jr nz,.not_pressed
	; Wait on key release
.pressed:
	ld a,HIGH PORT_KEYB_BNMSHIFTSPACE
	in a,(LOW PORT_KEYB_BNMSHIFTSPACE)
	bit 0,a	; SPACE
	jr z,.pressed
	ENDM


;===========================================================================
; Writes a value to a given TBBLUE register.
; Parameters:
;   A = register
;   D = value
; Returns:
;	-
; Changes:
;   A
;===========================================================================
/*
write_tbblue_reg:
	ld (.register+2),a
	ld a,d
.register:
	nextreg 0,a
	ret
*/



;===========================================================================
; Unsigned division: 16-bit / 8-bit
; Input: HL = Dividend, E = Divisor, E < 128
; Output: HL = HL / E
; Changes: AF, B
; See http://sgate.emt.bme.hu/patai/publications/z80guide/part4.html
;===========================================================================
div_hl_e:
	xor a		; Clearing the upper 8 bits of AHL
	ld b,16		; The length of the dividend (16 bits)
.loop:
	add hl,hl	; Advancing a bit
	rla
	cp e		; Checking if the divisor divides the digits chosen (in A)
	jp c,.skip	; If not, advancing without subtraction
	sub e		; Subtracting the divisor
	inc l		; and setting the next digit of the quotient
.skip:
	djnz .loop
	ret


;===========================================================================
; Converts an integer into a string.
; Does only work for numbers < 100 and always
; uses 2 digits.
; If number is >= 100 other characters (other than digits)
; will appear.
; Is used to convert the core version into a string.
; Input:
; - A: The number to convert (<100)
; - HL: The pointer to write to.
; Changes:
; - A, F, B, C
; Note: HL is unchanged
;===========================================================================
itoa_2digits:
    inc hl
	cp 100
	jr c,.below100

	; A >= 100, print just "??"
	ld a,'?'
	ldd (hl),a
    ld (hl),a
    ret

.below100:
    ld c,10
    ld b,-1
.loop10:
    inc b
    sub c
    jr nc,.loop10
    ; Print lower digit
    add c
    add a,'0'
    ldd (hl),a
    ; Print higher digit
    ld a,b
    add a,'0'
    ld (hl),a
    ret


;===========================================================================
; Converts an integer into a string.
; Does only work for numbers < 100 and always
; uses 2 digits.
; If number is >= 100 other characters (other than digits)
; will appear.
; Is used to convert the core version into a string.
; Input:
; - HL: The number to convert (0-65535)
; - DE: The pointer to write to.
; Changes:
; - A, F, B, C, D, E, H, L
; - DE = DE + 4
;===========================================================================
itoa_5digits:
	; 10000s
	ld bc,10000
	call .inner_sub
	ldi (de),a
	; 1000s
	ld bc,1000
	call .inner_sub
	ldi (de),a
	; 100s
	ld bc,100
	call .inner_sub
	ldi (de),a
	; 10s
	ld bc,10
	call .inner_sub
	ldi (de),a
	; 1s
	ld a,'0'
	add a,l
	ld (de),a
	ret

; Return in A the digit (char).
.inner_sub:
	xor a
.sub_loop:
	inc a
	sbc hl,bc
	jr nc,.sub_loop
	add a,'0'-1
	add hl,bc
	ret

