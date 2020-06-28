;========================================================
; text.asm
;========================================================


; Code to use in strings for positioning: AT x, y (in pixels)
AT:             equ 0x16


; Routines that draw text on the ULA or layer2 screen.
; Can be used as substitute for the original ZX Spectrum
; text drawing routines.
    MODULE text 


; Note: The loader copies the original spectrum font to the ROM_FONT address.
; This subroutine initializes the used font to ROM_FONT address.
; This is also the default value.
; IN:
;   -
; OUT:
;   -
; Changed registers:
;   HL, DE, BC
init:
    ; Store the used font address. The font starts normally at char index 0, so
    ; it's lower than the original address.
    ;ld hl,ROM_START+ROM_SIZE-ROM_FONT_SIZE-0x20*8
    ld hl,(MAIN_SLOT+1)*0x2000-ROM_FONT_SIZE-0x20*8
    ; Flow through


; Sets the font address.
; IN:
;   HL = address of font to use. Contains 256 character, but the first 8 bytes are not used (0).
; OUT:
;   -
; Changed registers:
;   -
set_font:
    ; Store the used font address.
    ld (font_address),hl
    ret 


; -----------------------------------------------------------------------
; ULA routines.

; Calculates the address in the screen from x and y position.
; Use this before you call any 'print' subroutine.
; In general this uses the PIXELDN instructions to calculate
; the screen address. But additionally it sets the B register
; with X mod 8, so that it can be used by the print sub routines.
; IN:
;   E = x-position, [0..255]
;   D = y-position, [0..191]
; OUT:
;   HL = points to the corresponding address in the ULA screen.
;   B = x mod 8
; Changed registers:
;   HL, B
ula.calc_address:
    ; Get x mod 8
    ld a,e
    and 00000111b
    ld b,a
    ; Calculate screen address
    PIXELAD
    ret 

; Prints a single character at ULA screen address in HL.
; IN:
;   HL = screen address to write to.
;   B = x mod 8, i.e. the number to shift the character
;   A = character to write.
; OUT:
;   -
; Changed registers:
;   DE, BC, IX
ula.print_char:
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
.loop:
    ldi d,(ix)  ; Load from font
    ld e,0
    bsrl de,b   ; shift
    ; XOR screen with character (1)
    ld a,(hl)
    xor d
    ld (hl),a 
    ; Next address on screen 
    inc l
    ; XOR screen with character (2)
    ld a,(hl)
    xor e
    ld (hl),a 
    ; Correct x-position
    dec l
    ; Next line
    PIXELDN
    ; Next
    dec c 
    jr nz,.loop

    ; Restore screen address
    pop hl  ; Restore screen address
    ret 


; Prints a complete string (until 0) at ULA screen address in HL.
; IN:
;   HL = screen address to write to.
;   DE = pointer to 0-terminated string
;   B = x mod 8, i.e. the number to shift the character
; OUT:
;   -
; Changed registers:
;   HL, DE, C
ula.print_string:
.loop:
    ld a,(de)
    or a
    ret z   ; Return on 0

    ; Check for AT
    cp AT 
    jr z,.at
    
    ; print one character
    push de
    call ula.print_char 
    pop de

    ; Next
    inc de
    inc l   ; Increase x-position
    jr .loop
    ret 

.at:
    ; AT x, y (pixels)
    inc de
    ldi a,(de)  ; x
    ld l,a
    ldi a,(de)   ; y
    push de
    ld e,l
    ld d,a
    call ula.calc_address
    pop de
    jr .loop

    ENDMODULE

