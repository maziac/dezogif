;===========================================================================
; data.asm
;
; All volatile data is defined here.
; 
; Note: The area does not need to be copied. i.e. is initialized on the fly.
;===========================================================================



; The dezogif program version:
 MACRO PRG_VERSION
 	defb "v0.11.0"
 ENDM 

 
;===========================================================================
; Magic number addresses to recognize the debugger
;===========================================================================
magic_number:   
.a      = 0x0000     ; Address 0x0000 (0xE000)
.b      = .a+1
.c      = 0x0066 ; Address 0x0066 (0xE066)
.d      = .c+1


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
    defb AT, 0, 2*8
    defb "ESP UART Baudrate: "
    STRINGIFY BAUDRATE

;    defb AT, 0, 4*8
;    defb "Tx=7, Rx=9"
    defb AT, 0, 5*8
    defb "Keys:"
    defb AT, 0, 6*8
    defb "1 = Joy 1"
    defb AT, 0, 7*8
    defb "2 = Joy 2"
    defb AT, 0, 8*8
    defb "3 = No joystick port"
    defb AT, 0, 9*8
    defb "0 = Reset"
;.end
    defb 0

JOY1_SELECTED_TEXT:
    defb AT, 0, 3*8, "Using Joy 1 (left)", 0
JOY2_SELECTED_TEXT:
    defb AT, 0, 3*8, "Using Joy 2 (right)", 0
NOJOY_SELECTED_TEXT:
    defb AT, 0, 3*8, "No joystick port used.", 0

SELECTED_TEXT_TABLE:
    defw NOJOY_SELECTED_TEXT
    defw JOY1_SELECTED_TEXT
    defw JOY2_SELECTED_TEXT


; Error texts
TEXT_LAST_ERROR:    
    defb AT, 0, 12*8, "Last Error:", AT, 0, 13*8, 0

TEXT_ERROR_TIMEOUT: defb "Rx Timeout", 0
TEXT_ERROR_WRONG_FUNC_NUMBER: defb "Wrong function number", 0

ERROR_TEXT_TABLE:  
    defw TEXT_ERROR_TIMEOUT
    defw TEXT_ERROR_WRONG_FUNC_NUMBER


