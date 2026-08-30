;===========================================================================
; data.asm
;
; All volatile data is defined here.
;
; Note: The area does not need to be copied. i.e. is initialized on the fly.
;===========================================================================



; The dezogif program version:
 MACRO PRG_VERSION
 	defb "v2.3.0-rc1"
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

; File path for the settings file
SETTINGS_FILE_PATH:
    defb "/machines/next/dezogif.cfg", 0

; UI
INTRO_TEXT:
    AT 0, 0
    COLOR BRIGHT+YELLOW
    defb "ZX Next UART DeZog Interface"
    defb COLOR, WHITE
    AT 0, 1
    PRG_VERSION
    defb " (DZRP v"
    defb DZRP_VERSION.MAJOR+'0', '.', DZRP_VERSION.MINOR+'0', '.', DZRP_VERSION.PATCH+'0'
    defb ")"
    AT 0, 2
    defb "Core: "
    AT 0, 3
    defb "ESP UART Baudrate: "
    STRINGIFY BAUDRATE
    AT 0, 4
    defb "Video timing:"

    AT 0, 6
    defb "UART:"
    AT 0, 7
    defb "Async break:"
    AT 0, 8
    defb "Border:"

    AT 0, 10
    defb "Keys:"
    AT 0, 11
    defb "1 = Joy 1"
    AT 0, 12
    defb "2 = Joy 2"
    AT 0, 13
    defb "3 = CN9 ESP"
    AT 0, 14
    defb "R = Reset"
    AT 0, 15
    defb "B = Border"
    AT 0, 16
    defb "A = Async break"
    AT 0, 17
    defb "S = Save settings"
    defb 0

JOY1_SELECTED_TEXT:
    AT 6, 6
    defb "Joy 1 (left)", 0
JOY2_SELECTED_TEXT:
    AT 6, 6
    defb "Joy 2 (right)", 0
CN9_SELECTED_TEXT:
    AT 6, 6
    defb "CN9 ESP", 0

SELECTED_TEXT_TABLE:
    defw CN9_SELECTED_TEXT
    defw JOY1_SELECTED_TEXT
    defw JOY2_SELECTED_TEXT


BORDER_OFF_TEXT:
    AT 8, 8
    defb "black", 0
BORDER_ON_TEXT:
    AT 8, 8
    defb "changing", 0

; Async break text:
COPPER_OFF_TEXT:
    AT 13, 7
    defb "off", 0
COPPER_ON_TEXT:
    AT 13, 7
    defb "on", 0


; Error texts
TEXT_LAST_ERROR:
    AT 0, 19
    COLOR_WITH_BCKG BRIGHT+RED, WHITE
    defb "Last Error:"
    AT 0, 20
    defb 0

TEXT_ERROR_RX_TIMEOUT: defb "RX Timeout", 0
TEXT_ERROR_RX_OVERFLOW: defb "RX Buffer overflow", 0
TEXT_ERROR_TX_TIMEOUT: defb "TX Timeout", 0
TEXT_ERROR_WRONG_FUNC_NUMBER: defb "Wrong function number", 0
TEXT_ERROR_WRITE_MAIN_BANK: defb "CMD_WRITE_BANK: Can't write to  bank "
    STRINGIFY MAIN_BANK
    defb ". Bank is used by DeZog.", 0
TEXT_ERROR_CORE_VERSION_NOT_SUPPORTED: ; Core not supported
    defb "Core Version not supported,     should be >= 03.01.10", 0
TEXT_CMD_NOT_SUPPORTED: ; Core not supported
    defb "Command not supported", 0

TEXT_ERROR_FILE_WRITE: defb "File write error", 0

ERROR_TEXT_TABLE:
    defw TEXT_ERROR_RX_TIMEOUT
    defw TEXT_ERROR_RX_OVERFLOW
    defw TEXT_ERROR_TX_TIMEOUT
    defw TEXT_ERROR_WRONG_FUNC_NUMBER
    defw TEXT_ERROR_WRITE_MAIN_BANK
    defw TEXT_ERROR_CORE_VERSION_NOT_SUPPORTED
    defw TEXT_CMD_NOT_SUPPORTED
    defw TEXT_ERROR_FILE_WRITE
