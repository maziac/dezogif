;===========================================================================
; main.asm
;===========================================================================

    DEVICE ZXSPECTRUMNEXT

; Program title shown on screen.
    MACRO PROGRAM_TITLE
    defb "ZX Next UART DeZog Interface"
    ENDM


; The program is loaded here first, then copied to USED_MAIN_BANK. So dezogif can also load itself. Debugged programs may use this bank.
LOADED_BANK:    EQU 92    

; Is temporarily used. E.g. to change the AltROM. The debugged program can use this bank.
TMP_BANK:       EQU 90  
TMP_BANKB:       EQU TMP_BANK+1  

; The 8k memory bank to store the code to.
; Debugged programs cannot use this bank.
MAIN_BANK:      EQU 94  ; Last 8k bank on unexpanded ZXNext.

MAIN_SLOT:      EQU 7   ; 0xE000
SWAP_SLOT:      EQU 6   ; 0xC000, used only temporary
;SWAP_SLOTB:     EQU SWAP_SLOT+1   ; 0xC000, used only temporary

LOOPBACK_BANK:  EQU 91 ; Used for the loopback test. Could be any bank as the loopback test is not done with a running debugged program.

    MMU MAIN_SLOT e, LOADED_BANK ; e -> Everything should fit into one page, error if not.
    ORG MAIN_SLOT*0x2000


; The address that correspondends to the main bank.
MAIN_ADDR:      EQU MAIN_SLOT*0x2000


;===========================================================================
; Include modules
;===========================================================================

    include "macros.asm"
    include "zx/zx.inc"
    include "zx/zxnext_regs.inc"
    include "breakpoints.asm"
    include "functions.asm"
    include "nmi.asm"
    include "utilities.asm"
    include "uart.asm"
    include "message.asm"
    include "commands.asm"
    include "backup.asm"
    include "text.asm"
 


;===========================================================================
; Constants
;===========================================================================

; UART baudrate
;BAUDRATE:   equ 2000000
;BAUDRATE:   equ 1958400
;BAUDRATE:   equ 1228800
BAUDRATE:   equ 921600
;BAUDRATE:   equ 614400
;BAUDRATE:   equ 460800
;BAUDRATE:   equ 230400


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
    nextreg REG_ALTROM,0
    nextreg REG_MMU,ROM_BANK
    nextreg REG_MMU+1,ROM_BANK
    jp 0


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
; main routine - The main loop of the program.
;===========================================================================
main:
    di
    ; Setup stack
    ld sp,debug_stack.top

    ; Disable the M1 (MF NMI) button
    call mf_nmi_disable

    ; Init layer 2
    ld bc,LAYER_2_PORT
    xor a
    out (c),a
    ld (backup.layer_2_port),a

    ; Init clock speed
    ld a,RTM_3MHZ
    ld (backup.speed),a

    ; Init interrupt state
    xor a
	ld a,(backup.interrupt_state)

    ; Set UART
    ld a,(uart_joyport_selection)
    ld e,a
    call set_uart_joystick

    ; Drain
    call drain_rx_buffer

    ; Show the text
    call show_ui

    ; Border color timer
    ld c,1     
    ld de,0
main_loop:
    push bc, de

    ; Check if byte available.
    call check_uart_byte_available
    ; If so leave loop and enter command loop
    jp nz,cmd_loop    

.no_uart_byte:
    ; Check keyboard
    call check_key_reset
    call read_key_joyport
    inc e
    jr z,.no_keyboard
    
    ; Key pressed
    dec e
    ld a,e
    ld (uart_joyport_selection),a
    jp main

.no_keyboard:
    pop de, bc
    ; Check border color timer
    dec de
    ld a,d
    or e
    jr nz,main_loop
    dec c 
    jr nz,main_loop

    ; Change color of the border
    call change_border_color
    ld c,4
    jr main_loop


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
	jp text.ula.print_string


;===========================================================================
; DATA: All (writable) data needs to be located in
; area 0x2000-0x3FFF.
;===========================================================================
   
    ; Note: Page and slot doesn't matter as this is bss area and will be located in divmmc.
    ; However for testing (without divmmc) it is better that a bank is mapped
    ;MMU USED_DATA_SLOT e, USED_DATA_BANK
    ;ORG 0x2000

    ; Note: The area does not need to be copied. i.e. is initialized on the fly.
    include "data.asm"

    ASSERT $ <= (MAIN_SLOT+1)*0x2000
    ASSERT $ <= MAIN_SLOT*0x2000+0x1F00



;===========================================================================
; After loading the program starts here. 
;===========================================================================
    ; Default slots: 254, 255, 10, 11, 4, 5, 0, 1
    MMU 4 e, 4, 0x8000 ; Slot 4 = Bank 4 (standard)

    include "prequel.asm"


    ; Save NEX file
    SAVENEX OPEN BIN_FILE, start_entry_point, stack_prequel.top //stack_top: The ZX Next has a problem (crashes the program immediately when it is run) if stack points to stack_top 
    SAVENEX CORE 3, 1, 5  
    ;SAVENEX CFG 0               ; black border
    ;SAVENEX BAR 0, 0            ; no load bar
    SAVENEX AUTO
    ;SAVENEX BANK 20
    SAVENEX CLOSE
