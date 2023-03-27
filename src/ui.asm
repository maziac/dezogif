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
; Checks key "B".
; For turning slow border change on/off.
; Returns:
;   Z = B pressed
;   NZ = B not pressed
;===========================================================================
check_key_border:
    ; Read port
    ld bc,PORT_KEYB_BNMSHIFTSPACE
    in a,(c)
    bit 4,a ; "B"
    ret nz
    ; Wait on key release
    call wait_on_key_release
    ; Toggle
    ld a,(slow_border_change)
    xor 1
    ld (slow_border_change),a
    jr nz,.ret
    ; Turn border black
    xor a
    out (BORDER),a
.ret:
    xor a   ; Z
    ret


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
    ; Flow through wait_on_key_release


;===========================================================================
; Waits on key release.
; Parameters:
;   BC = the port to usefor the keys.
; Changes:
;   AF
;===========================================================================
wait_on_key_release:
    in a,(c)
    and 0x1F
    cp 0x1F
    jr nz,wait_on_key_release
    ret


;===========================================================================
; Switches to ULA mode and shows the intro text.
; Displaying which keys can be used to change the joy port.
;===========================================================================
show_ui:
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
    MEMCLEAR SCREEN, SCREEN_SIZE
    ; Black on white
    MEMFILL COLOR_SCREEN, WHITE+(BLACK<<3), COLOR_SCREEN_SIZE+15*COLOR_SCREEN_WIDTH
    ; Red on black for a probable error report
    MEMFILL COLOR_SCREEN+15*COLOR_SCREEN_WIDTH, RED+BRIGHT, 9*COLOR_SCREEN_WIDTH

    ; Print text
    ld de,INTRO_TEXT
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
    ld de,text_core_version
	call text.ula.print_string

    ; Get display timing
    ld a,REG_VIDEO_TIMING
    call read_tbblue_reg
	and 0111b			;video timing is in bottom 3 bits, e.g. HDMI=111b
    ; Print the number
    add '0' ; convert to ASCII
    ld (text_one_char.char),a
    ld de,text_one_char
	call text.ula.print_string

    ; Show right selected joy port option
    ld hl,SELECTED_TEXT_TABLE
    ld a,(uart_joyport_selection)
    add a   ; *2
    add hl,a
    ld de,(hl)
	call text.ula.print_string

    ; Show border option
    ld de,BORDER_ON_TEXT
    ld a,(slow_border_change)
    or a
    jr z,.print_border
    ld de,BORDER_OFF_TEXT
.print_border:
	call text.ula.print_string

    ; Print 3 lines debugging
    IFUSED dbg.clear
    ; Caclulate screen address
	ld de,256*8*dbg.TEXT_START_POSITION_LINE + 8*dbg.TEXT_START_POSITION_CLMN
	call text.ula.calc_address
	ld de,dbg.text
	call text.ula.print_string
    ENDIF

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
