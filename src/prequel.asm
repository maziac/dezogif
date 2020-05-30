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

    ; Initialization.
    ; Setup stack
    ld sp,stack_top

    ; Init state
    xor a
    ld (state),a
    MEMCLEAR tmp_breakpoint_1, 2*TMP_BREAKPOINT

 IF 0   ; TODO: Re-enable
     ; Backup slot 6
    ld a,REG_MMU+6
    call read_tbblue_reg    ; returns the bank in A

    ; Switch in the bank at 0xC000
    nextreg REG_MMU+6,USED_ROM_BANK
    ; Copy the ROM at 0x0000 to bank USED_ROM_BANK
    MEMCOPY SWAP_SLOT*0x2000, 0x0000, 0x2000

    ; Overwrite the RST 0 address with a jump
    ld hl,0xC000
    ldi (hl),0xC3   ; JP
    ldi (hl),LOW enter_breakpoint
    ld (hl),HIGH enter_breakpoint

    ; Restore slot 6 bank
    nextreg REG_MMU+6,a
 ENDIF

    ; Page in copied ROM bank to slot 0
    nextreg REG_MMU+0,USED_ROM_BANK

    ; Set baudrate
    call set_uart_baudrate

    ; Init
    call drain_rx_buffer

    ; Set uart at joystick port
    ld e,2  ; Joy 2
    call set_text_and_joyport

    ; Border color timer
    ld c,1     
    ld de,0
    ; The main program has been copied into USED_MAIN_BANK
    jp main_loop
    


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


