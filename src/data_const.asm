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

    MACRO STATUS_COL
    COLOR BRIGHT+GREEN
    ENDM

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

    STATUS_COL
    AT 0, 6
    defb "UART:"
    AT 0, 7
    defb "Async-Break:"

    COLOR WHITE
    AT 0, 9
    defb "Keys:"
    AT 0, 10
    defb "1=Joy 1"
    AT 0, 11
    defb "2=Joy 2"
    AT 0, 12
    defb "3=CN9 ESP"
    AT 0, 13
    defb "A=Async-Break"
    AT 16, 10
    defb "R=Reset"
    AT 16, 11
    defb "S=Save settings"
    AT 16, 12
    defb "H=Help"
    defb 0

JOY1_SELECTED_TEXT:
    STATUS_COL
    AT 6, 6
    defb "Joy 1 (left) ", 0
JOY2_SELECTED_TEXT:
    STATUS_COL
    AT 6, 6
    defb "Joy 2 (right)", 0
CN9_SELECTED_TEXT:
    STATUS_COL
    AT 6, 6
    defb "CN9 ESP      ", 0

SELECTED_TEXT_TABLE:
    defw CN9_SELECTED_TEXT
    defw JOY1_SELECTED_TEXT
    defw JOY2_SELECTED_TEXT

; Async break text:
COPPER_OFF_TEXT:
    STATUS_COL
    AT 13, 7
    defb "off", 0
COPPER_ON_TEXT:
    STATUS_COL
    AT 13, 7
    defb "on ", 0


; Help texts
HELP_TEXT_1:
    AT 0, 0
    defb COLOR, GREEN, "Help 1/2:"
    AT 26, 0
    defb COLOR, BLUE, "H=Next"
    AT 0, 2
    defb COLOR, YELLOW, "UART:", COLOR, WHITE
    AT 0, 3
    defb "Select here which port to use   "
    defb "for UART communication. Either  "
    defb "one of the 2 ", COLOR, MAGENTA, "joystick ports", COLOR, WHITE, " or  "
    defb "the ", COLOR, MAGENTA, "CN9 ESP port", COLOR, WHITE, " can be used."
    AT 0, 7
    defb "For CN9 you need to open your ZX"
    AT 0, 8
    defb "Next and solder RX/TX to the ", COLOR, MAGENTA, "CN9"
    defb "header", COLOR, WHITE, "."
    AT 0, 11
    defb COLOR, YELLOW, "Save settings:", COLOR, WHITE
    AT 0, 12
    defb "Will save your current settings "
    defb "(UART, Async-break) in          "
    defb COLOR, MAGENTA, "dezogif.cfg", COLOR, WHITE, " near ", COLOR, MAGENTA, "enNextMf.rom", COLOR, WHITE, ".  "
    defb "The settings will be loaded"
    AT 0, 16
    defb "automatically on next startup."

    AT 0, 18
    defb COLOR, YELLOW, "Reset:", COLOR, WHITE
    AT 0, 19
    defb "Will reset the ZX Next."

    defb 0

HELP_TEXT_2:
    AT 0, 0
    defb COLOR, GREEN, "Help 2/2:"
    AT 26, 0
    defb COLOR, BLUE, "H=Next"
    AT 0, 2
    defb COLOR, YELLOW, "Async-break:", COLOR, WHITE
    AT 0, 3
    defb "Enabling Async-Break allows to  "
    defb "break execution of your debugged"
    defb "program by pressing ", COLOR, MAGENTA, "PAUSE in    "
    defb "DeZog", COLOR, WHITE, ". If ", COLOR, MAGENTA, "not enabled", COLOR, WHITE, " you need  "
    defb "to break your program by        "
    AT 0, 8
    defb "pressing the ", COLOR, MAGENTA, "NMI button", COLOR, WHITE, ".        "
    defb "The Async-Break features comes  "
    defb "with a few small ", COLOR, MAGENTA, "limitations:", COLOR, WHITE
    AT 0, 11
    defb "- it uses < 1% of the ", COLOR, MAGENTA, "CPU time", COLOR, WHITE, "  "
    defb "- if you use the UART through   "
    defb " joystick port 1 or 2 you cannot"
    defb " use the additional buttons of  "
    defb " an ", COLOR, MAGENTA, "MD joystick", COLOR, WHITE
    AT 0, 16
    defb "- to use Async-Break with a     "
    defb " program that uses the Copper   "
    defb " itself please ", COLOR, MAGENTA, "refer to the     "
    defb " documentation"

    defb 0


; Error texts
TEXT_LAST_ERROR:
    AT 0, 15
    COLOR_WITH_BCKG BRIGHT+RED, WHITE
    defb "Last Error:"
    AT 0, 16
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
TEXT_ERROR_FILE_READ: defb "File read error", 0

ERROR_TEXT_TABLE:
    defw TEXT_ERROR_RX_TIMEOUT
    defw TEXT_ERROR_RX_OVERFLOW
    defw TEXT_ERROR_TX_TIMEOUT
    defw TEXT_ERROR_WRONG_FUNC_NUMBER
    defw TEXT_ERROR_WRITE_MAIN_BANK
    defw TEXT_ERROR_CORE_VERSION_NOT_SUPPORTED
    defw TEXT_CMD_NOT_SUPPORTED
    defw TEXT_ERROR_FILE_WRITE
    defw TEXT_ERROR_FILE_READ
