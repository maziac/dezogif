;===========================================================================
; constants.asm
;
; Definition of the main constants.
;===========================================================================



; Is temporarily used. E.g. to change the AltROM. The debugged program can use this bank.
TMP_BANK:       EQU 92
TMP_BANKB:       EQU 93

; The 8k memory bank to store the code to.
; Debugged programs cannot use this bank.
MAIN_BANK:      EQU 94  ; Last 8k bank on unexpanded ZXNext.

MAIN_SLOT:      EQU 7   ; 0xE000
SWAP_SLOT:      EQU 6   ; 0xC000, used only temporary

LOOPBACK_BANK:  EQU 91 ; Used for the loopback test. Could be any bank as the loopback test is not done with a running debugged program.

; The address that correspondends to the main bank.
MAIN_ADDR:      EQU MAIN_SLOT*0x2000

; The address that correspondends to the swap slot bank.
SWAP_ADDR:      EQU SWAP_SLOT*0x2000

; Use the build time
BUILD_TIME16: equ BUILD_TIME & 0xFFFF
; DISPLAY "BUILD_TIME: ", BTIME



; UART baudrate
;BAUDRATE:   equ 2000000
;BAUDRATE:   equ 1958400
;BAUDRATE:   equ 1228800
BAUDRATE:   equ 921600
;BAUDRATE:   equ 614400
;BAUDRATE:   equ 460800
;BAUDRATE:   equ 230400

; UART port
UART_PORT_CN9:  equ 0
UART_PORT_JOY1: equ 1
UART_PORT_JOY2: equ 2


; Program states
PRGM_IDLE:		equ 1	; Waiting for a new program (at program start and after CMD_CLOSE)
PRGM_LOADING:	equ 2	; After CMD_INIT until the first CMD_CONTINUE
PRGM_STOPPED:	equ 3	; After breakpoint or NMI
PRGM_RUNNING:	equ 4	; After CMD_CONTINUE


; The raster line at which the asynchronous-break Copper list raises its
; Multiface NMI. Any line works; 0 is the first line just after the
; vertical blank.
COPPER_BREAK_LINE:	equ 0
