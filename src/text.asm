;========================================================
; text.asm
;========================================================


; Code to use in strings for positioning: AT x, y (in pixels)
AT:             equ 0x16
; Code to use in strings for changing the color. e.g. COLOR BLACK*8+WHITE (white on black)
COLOR:          equ 0x17



; Routines that draw text on the ULA or layer2 screen.
; Can be used as substitute for the original ZX Spectrum
; text drawing routines.
    MODULE text

; -----------------------------------------------------------------------
; ULA routines.

; Prints a single character at ULA screen address in HL.
; IN:
;   HL = screen address to write to.
;   A = character to write.
;   C = color
; OUT:
;   -
; Changed registers:
;   DE, BC, AF
ula.print_char:
    push hl
    push hl
    ld b,8  ; 8 byte per character

    ; Calculate offset of character in font
    ld e,a
    ld d,b  ; 8 byte per character
    mul d,e
    ; Add to font start address
    ld hl,FONT
    add hl,de
    ex de,hl    ; de points to character in font
    ; Now copy the character to the screen
    pop hl

.loop:
    ldi a,(de)  ; Load from font
    ld (hl),a
    ; Next line
    PIXELDN
    ; Next
    djnz .loop

    ; Restore screen address
    pop hl
    ret


; Prints a complete string (until 0) at ULA screen address in HL.
; IN:
;   IX = pointer to 0-terminated string
;   HL = screen address to write to. If AT is immediately set in
; the IX string, then HL can be omitted.
;   IY = color attribute screen address. If AT is immediately
; set in the IX string, IY can be omitted.
; OUT:
;   HL (or better L only) increased by 1, pointing to the next screen address.
; Changed registers:
;   AF, HL, DE, IX, BC
ula.print_string:
    ld c,WHITE  ; Default color: white on black
ula.print_string_with_color:
.loop:
    ldi a,(ix)
    or a
    ret z   ; Return on 0

    ; Check for AT
    cp AT
    jr z,.at

    ; Check for AT
    cp COLOR
    jr z,.color

    ; Set color attribute
    ldi (iy),c

    ; print one character
    call ula.print_char

    ; Next
    inc l   ; Increase x-position
    jr .loop
    ret

.at:
    ; AT x, y (pixels)
    ldi e,(ix)   ; x
    ldi d,(ix)   ; y
    PIXELAD

    ; Calculate the color attribute screen address
    ; and store in iy
    ld a,h
    and 0x18
    rrca: rrca : rrca ; shift bit 4,3 to 1,0
    or HIGH(COLOR_SCREEN)
    ld iyh,a
    ld a,l
    ld iyl,a

    jr .loop

.color:
    ldi c,(ix)   ; color
    jr .loop

    ENDMODULE

