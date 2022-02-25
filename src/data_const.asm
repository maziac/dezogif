;===========================================================================
; data.asm
;
; All volatile data is defined here.
;
; Note: The area does not need to be copied. i.e. is initialized on the fly.
;===========================================================================



; The dezogif program version:
 MACRO PRG_VERSION
 	defb "v2.1.0-a"
 ENDM


;===========================================================================
; Magic number addresses to recognize the debugger
;===========================================================================
magic_number_a:     equ 0x0000     ; Address 0x0000 (0xE000)
magic_number_b:     equ 0x0001
magic_number_c:     equ 0x0066      ; Address 0x0066 (0xE066)
magic_number_d:     equ 0x0067


;===========================================================================
; Const data
;===========================================================================

; 16 bit build time
build_time_abs: defw BUILD_TIME16
build_time_rel = build_time_abs-MAIN_ADDR;


; UI
INTRO_TEXT:
    defb AT, 0, 0
    defb "ZX Next UART DeZog Interface"
    defb AT, 0, 1*8
    PRG_VERSION
    defb " (DZRP v"
    defb DZRP_VERSION.MAJOR+'0', '.', DZRP_VERSION.MINOR+'0', '.', DZRP_VERSION.PATCH+'0'
    defb ")"
    defb AT, 0, 2*8
    defb "Core version: "
    defb AT, 0, 3*8
    defb "ESP UART Baudrate: "
    STRINGIFY BAUDRATE
    defb AT, 0, 4*8
    defb "Video timing:"

    defb AT, 0, 8*8
    defb "Keys:"
    defb AT, 0, 9*8
    defb "1 = Joy 1"
    defb AT, 0, 10*8
    defb "2 = Joy 2"
    defb AT, 0, 11*8
    defb "3 = No joystick port"
    defb AT, 0, 12*8
    defb "R = Reset"
    defb AT, 0, 13*8
    defb "B = Border"
    defb 0

JOY1_SELECTED_TEXT:
    defb AT, 0, 6*8, "Using Joy 1 (left)", 0
JOY2_SELECTED_TEXT:
    defb AT, 0, 6*8, "Using Joy 2 (right)", 0
NOJOY_SELECTED_TEXT:
    defb AT, 0, 6*8, "No joystick port used.", 0

SELECTED_TEXT_TABLE:
    defw NOJOY_SELECTED_TEXT
    defw JOY1_SELECTED_TEXT
    defw JOY2_SELECTED_TEXT


BORDER_OFF_TEXT:
    defb AT, 11*8, 13*8, "off", 0
BORDER_ON_TEXT:
    defb AT, 11*8, 13*8, "on", 0


; Error texts
TEXT_LAST_ERROR:
    defb AT, 0, 13*8, "Last Error:", AT, 0, 14*8, 0

TEXT_ERROR_RX_TIMEOUT: defb "RX Timeout", 0
TEXT_ERROR_TX_TIMEOUT: defb "TX Timeout", 0
TEXT_ERROR_WRONG_FUNC_NUMBER: defb "Wrong function number", 0
TEXT_ERROR_WRITE_MAIN_BANK: defb "CMD_WRITE_BANK: Can't write to  bank "
    STRINGIFY MAIN_BANK
    defb ". Bank is used by DeZog.", 0

ERROR_TEXT_TABLE:
    defw TEXT_ERROR_RX_TIMEOUT
    defw TEXT_ERROR_TX_TIMEOUT
    defw TEXT_ERROR_WRONG_FUNC_NUMBER
    defw TEXT_ERROR_WRITE_MAIN_BANK


