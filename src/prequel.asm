;===========================================================================
; prequel.asm
; Code that is executed in RAM before the main program (in ROM area)
; is started.
; It mainly prints the informational text.
;===========================================================================



;===========================================================================
; After loading the program starts here. Moves the bank to the destination 
; slot and jumps there.
;===========================================================================
start_entry_point:
    ; At startup this program is mapped at 0xC000
    di

	; Maximize clock speed
	ld a,RTM_28MHZ
	nextreg REG_TURBO_MODE,a

    ; Switch in ROM bank
    nextreg REG_MMU+0,ROM_BANK
    nextreg REG_MMU+1,ROM_BANK

 IF 01
    ;ld sp,stack_prequel.top


    ; Clear screen
	ld iy,VAR_ERRNR
    call ROM_CLS
    
    ; Print text    
    ld hl,INTRO_TEXT
	call print
 ENDIF

    ; The main program has been loaded into LOADED_BANK and needs to be copied to USED_MAIN_BANK
    ; Switch in the bank at 0x4000
    nextreg REG_MMU+USED_SLOT,USED_MAIN_BANK
    ; Switch in loaded bank at 0xE000
    nextreg REG_MMU+SWAP_SLOT,LOADED_BANK
    ; Copy the code
    MEMCOPY USED_SLOT*0x2000, SWAP_SLOT*0x2000, 0x2000   
    ; The main program has been copied into USED_MAIN_BANK
    jp main
    


; The preliminary stack
stack_prequel:
	defs 2*20
.top



; The info text to show.
JOY1_ROW:	equ 2
JOY2_ROW:	equ 3
NOJOY_ROW:	equ 4

INTRO_TEXT: 
    defb OVER, 0
    defb AT, 0, 0
    ;defb "ZX Next UART DeZog Interface"
    PROGRAM_TITLE
    defb AT, 1, 0
    defb "ESP UART Baudrate: "
    STRINGIFY BAUDRATE

    defb AT, JOY1_ROW, 0, "Using Joy 1 (left)"
    defb AT, JOY2_ROW, 0, "Using Joy 2 (right)"
    defb AT, NOJOY_ROW, 0, "No joystick port used."

    defb AT, 5, 0
    defb "Tx=7, Rx=9"
    defb AT, 6, 0
    defb "Keys:"
    defb AT, 7, 0
    defb "1 = Joy 1"
    defb AT, 8, 0
    defb "2 = Joy 2"
    defb AT, 9, 0
    defb "3 = No joystick port"
;.end
    defb EOS


