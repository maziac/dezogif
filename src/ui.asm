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
ERROR_RX_OVERFLOW:          equ 2
ERROR_TX_TIMEOUT:			equ 3
ERROR_WRONG_FUNC_NUMBER:	equ 4
ERROR_WRITE_MAIN_BANK:	    equ 5
ERROR_CORE_VERSION_NOT_SUPPORTED:  equ 6
ERROR_CMD_NOT_SUPPORTED:    equ 7
ERROR_FILE_WRITE:           equ 8
ERROR_FILE_READ:            equ 9


;===========================================================================
; Checks key "S".
; If pressed the setting values (async break, border flashing) are saved to a file.
;===========================================================================
check_key_save:
    ; Read port
    ld bc,PORT_KEYB_GFDSA
    in a,(c)
    bit 1,a ; "S"
    ret nz
    ; Wait on key release
.wait_on_release:
    call wait_on_key_release
    ; Save
    call save_settings
    jr nc,flash_border

    ; An write error occurred
    ld a,ERROR_FILE_WRITE
    jp drain_main


;===========================================================================
; Flash the border colors as confirmation of an action.
;===========================================================================
flash_border:
    ; Wait and flash the border
    ld bc,0x0000 ; 65536
.wait:
    ld a,c
    srl a : srl a : srl a
    and 0x07
    out (BORDER),a
    dec bc
    ld a,c
    or b
    jr nz,.wait
    out (BORDER),a  ; a is 0 = BLACK
    ret


;===========================================================================
; Checks key "R".
; If pressed a reset is done.
;===========================================================================
check_key_reset:
    ; Read port
    ld bc,PORT_KEYB_TREWQ
    in a,(c)
    bit 3,a ; "R"
    ret nz
    ; Wait on key release
.wait_on_release:
    call wait_on_key_release
    ; Reset
    nextreg REG_RESET, 01b


;===========================================================================
; Checks key "A".
; Turns async break on and off. Off is worth having for two reasons: the
; poll costs ~1288 T-states a frame, which is 0.230% of a frame at 28 MHz but
; 1.84% at 3.5 MHz, and a program that owns the Copper may want the debugger to
; keep its hands off it.
;===========================================================================
check_key_copper:
    ; Read port
    ld bc,PORT_KEYB_GFDSA
    in a,(c)
    bit 0,a ; "A"
    ret nz
    ; Wait on key release. BC still holds the port.
    call wait_on_key_release
    ; Toggle
    ld a,(copper_break_enabled)
    xor 1
    ld (copper_break_enabled),a
    jp show_ui


;===========================================================================
; Checks key "H" to display the help page.
;===========================================================================
check_key_help:
    call .key
    ret nz
    ; Show help page 1
    ld ix,HELP_TEXT_1
    call show_help
    ; Wait on next "H" key press
    call .wait_on_key_press

    ; Show help page 2
    ld ix,HELP_TEXT_2
    call show_help
    ; Wait on next "H" key press
    call .wait_on_key_press

    jp main ; Show main UI with cls

.wait_on_key_press:
    ; Check if something received at UART
    call check_uart_byte_available
    jr z,.wait_continue
    ; If uart byte received, leave help page
    pop af  ; Pop return address
    ret ; Leave check_key_help

.wait_continue:
    ; Check for key
    call .key
    jr nz,.wait_on_key_press
    ret

; Returns with NZ if "H" was not pressed, Z if it was pressed.
.key:
    ; Read port
    ld bc,PORT_KEYB_HJKLENTER
    in a,(c)
    bit 4,a ; "H"
    ret nz
    ; Wait on key release. BC still holds the port.
    jr wait_on_key_release ; Returns always with Z


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
    ld a,UART_PORT_JOY1
    jr .cont
.no_key_1:
    bit 1,a ; "2"
    jr nz,.no_key_2
    ld a,UART_PORT_JOY2
    jr .cont
.no_key_2:
    bit 2,a ; "3"
    ret nz
    ld a,UART_PORT_CN9

.cont:
    ld (uart_joyport_selection),a
    call wait_on_key_release
    jp show_ui


;===========================================================================
; Waits on key release.
; Parameters:
;   BC = the port to usefor the keys.
; Changes:
;   AF
; Returns:
;   Z
;===========================================================================
wait_on_key_release:
    in a,(c)
    and 0x1F
    cp 0x1F
    jr nz,wait_on_key_release
    ret


;===========================================================================
; Switches to ULA mode and shows the UI.
;===========================================================================
init_and_show_ui:
    ; Switch to ULA
    nextreg REG_ULA_X_OFFSET, 0
    nextreg REG_ULA_Y_OFFSET, 0
    nextreg REG_ULA_CONTROL, 0
    nextreg REG_DISPLAY_CONTROL, 0
    nextreg REG_SPRITE_LAYER_SYSTEM, 00010000b   ; USL
    ; Turn off clipping (might have been used by screensaver)
    nextreg REG_CLIP_WINDOW_CONTROL, RCWC_RESET_ULA_CLIP_INDEX
    nextreg REG_CLIP_WINDOW_ULA, 0
    nextreg REG_CLIP_WINDOW_ULA, 255
    nextreg REG_CLIP_WINDOW_ULA, 0
    nextreg REG_CLIP_WINDOW_ULA, 191

    ; Clear the screen
    call cls

;===========================================================================
; Shows the intro text and the state.
; Displays also the keys to use to change the settings.
;===========================================================================
show_ui:
    ; Print text
    ld ix,INTRO_TEXT
	call text.ula.print_string

    ; Show core version
    ld a,REG_VERSION
    call read_tbblue_reg
    ld h,a  ; Save major and minor number
    ; Shift major number
    rra : rra : rra : rra
    and 0x0F
    ld de,text_core_version.major
    call itoa_2digits
    ; Minor version
    ld a,h
    and 0x0F
    ld de,text_core_version.minor
    call itoa_2digits
    ; Subminor
    ld a,REG_SUB_VERSION
    call read_tbblue_reg
    ld l,a    ; save subminor
    ld de,text_core_version.subminor
    call itoa_2digits

    ; Check version against core version 3.01.10 (minimum version)
    ; (hl = current version)
    ld de,(3 << 12) + (1 << 8) + (10)
    sbc hl,de   ; current version - 3.01.10
    jp p,.core_version_continue

    ; Core version not supported
	ld a,(last_error)
	or a
	jr nz,.core_version_continue	; There is already an error

    ; Report "core version not supported" error
    ld a,ERROR_CORE_VERSION_NOT_SUPPORTED
    ld (last_error),a

.core_version_continue:
    ; Print
    ld ix,text_core_version
	call text.ula.print_string

    ; Get display timing
    ld a,REG_VIDEO_TIMING
    call read_tbblue_reg
	and 0111b			;video timing is in bottom 3 bits, e.g. HDMI=111b
    ; Print the number
    add '0' ; convert to ASCII
    ld (text_one_char.char),a
    ld ix,text_one_char
	call text.ula.print_string

    ; Show right selected joy port option
    ld hl,SELECTED_TEXT_TABLE
    ld a,(uart_joyport_selection)
    add a   ; *2
    add hl,a
    ld de,(hl)
    ld ix,de
	call text.ula.print_string

    ; Show the async break option. Row 14, which was the one free row on this
    ; screen.
    ld ix,COPPER_OFF_TEXT
    ld a,(copper_break_enabled)
    or a
    jr z,.print_copper
    ld ix,COPPER_ON_TEXT
.print_copper:
    call text.ula.print_string

    ; Print 3 lines debugging
    DBG_PRINT

	; Show possibly error
	ld a,(last_error)
	or a
	ret z	; 0 = no error

	; Print "Last error:"
    ld ix,TEXT_LAST_ERROR
	call text.ula.print_string
	push hl	; Save pointer to screen

	; Print error message
	ld a,(last_error)
	dec a
	add a	; 2*A
	ld hl,ERROR_TEXT_TABLE
	add hl,a
    ld de,(hl)
    ld ix,de
	pop hl	; Restore pointer to screen
    ld c,BRIGHT+RED+WHITE*8
    jp text.ula.print_string_with_color



;===========================================================================
; Shows the help text.
; INPUT: IX = pointer to help text
;===========================================================================
show_help:
    call cls
	jp text.ula.print_string


;===========================================================================
; Clears the screen and attribute colors with zeroes.
;===========================================================================
cls:
    MEMCLEAR SCREEN, SCREEN_SIZE+COLOR_SCREEN_SIZE
    ret
