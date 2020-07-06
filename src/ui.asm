;===========================================================================
; ui.asm
;
; The simple UI.
; Text output and keyboard input.
;===========================================================================



;===========================================================================
; Const data
;===========================================================================

; Error definitions
ERROR_RX_TIMEOUT:			equ 1
ERROR_TX_TIMEOUT:			equ 2
ERROR_WRONG_FUNC_NUMBER:	equ 3


;===========================================================================
; Checks key "0".
; If pressed a reset (jp 0) is done.
;===========================================================================
check_key_reset:
    ; Read port
    ld a,HIGH PORT_KEYB_67890
    in a,(LOW PORT_KEYB_67890)
    bit 0,a ; "0"
    ret nz 
    ; Reset
    nextreg REG_RESET, 01b


;===========================================================================
; Reads the joyport from the keyboard.
; Returns:
;  E: 0x00=00b => "3": no joystick port used
;     0x01=01b => "1": joyport 1
;     0x02=10b => "2": joyport 2
;     0xFF => no key pressed
;===========================================================================
read_key_joyport:
    ; Read port
    ld bc,PORT_KEYB_54321
    in a,(c)
    ld e,0xFF   ; Default
    bit 0,a ; "1"
    jr nz,.no_key_1
    ld e,0x01
    jr .cont
.no_key_1:
    bit 1,a ; "2"
    jr nz,.no_key_2
    ld e,0x02
    jr .cont
.no_key_2:
    bit 2,a ; "3"
    ret nz
    ld e,0x00

.cont:
    ; Wait on key release
    in a,(c)
    and 0x1F
    cp 0x1F
    jr nz,.cont
    ret


;===========================================================================
; Switches to ULA mode and shows the intro text.
; Displaying which keys can be used to change the joy port.
;===========================================================================
show_ui:    
    ; Switch to ULA
    nextreg REG_ULA_X_OFFSET,0
    nextreg REG_ULA_Y_OFFSET,0
    nextreg REG_ULA_CONTROL,0
    nextreg REG_DISPLAY_CONTROL,0
    nextreg REG_SPRITE_LAYER_SYSTEM,00010000b   ; USL
    
    ; Clear the screen
    MEMCLEAR SCREEN, SCREEN_SIZE
    ; Black on white
    MEMFILL COLOR_SCREEN, WHITE+(BLACK<<3), COLOR_SCREEN_SIZE

    ; Print text 
    ld de,INTRO_TEXT
	call text.ula.print_string

    ; Show right selected option
    ld hl,SELECTED_TEXT_TABLE
    ld a,(uart_joyport_selection)
    add a   ; *2
    add hl,a
    ld de,(hl)
	call text.ula.print_string

	; Show possibly error
	ld a,(last_error)
	or a
	ret z	; 0 = no error

	; Print "Last error:"
    ld de,TEXT_LAST_ERROR
	call text.ula.print_string
	push hl	; Save pointer to screen

	; Print error message
	ld a,(last_error)
	dec a
	add a	; 2*A
	ld hl,ERROR_TEXT_TABLE
	add hl,a
    ld de,(hl)
	pop hl	; Restore pointer to screen
	jp text.ula.print_string


