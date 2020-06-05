;===========================================================================
; main.asm
;===========================================================================

    DEVICE ZXSPECTRUMNEXT

; Program can be compiled as simple loopback program.
 IFDEF LOOPBACK
    MACRO PROGRAM_TITLE
    defb "UART Loopback"
    ENDM
 ELSE
    MACRO PROGRAM_TITLE
    defb "ZX Next UART DeZog Interface"
    ENDM
 ENDIF

; The 8k memory bank to store the code to.
USED_MAIN_BANK: EQU 95  ; Last 8k bank on unexpanded ZXNext. Debugged programs cannot use this bank.
USED_ROM_BANK:  EQU 94  ; Bank used to copy the ROM (0x0000) to and change the RST 0 address into a jump. Debugged programs cannot use this bank.
LOADED_BANK:    EQU 93    ; The program is loaded here first, then copied to USED_MAIN_BANK. So dezogif can also load itself. Debugged programs may use this bank.
USED_SLOT:      EQU 1   ; 0x2000
SWAP_SLOT:      EQU 7   ; 0xE000, used only temporary


    MMU USED_SLOT e, LOADED_BANK ; e -> Everything should fit into one page, error if not.
    ORG USED_SLOT*0x2000
    ;ORG 0x8000


;===========================================================================
; Include modules
;===========================================================================

    include "macros.asm"
    include "zxnext/zxnext_regs.inc"
    include "coop.asm"
    include "utilities.asm"
    include "uart.asm"
    include "breakpoints.asm"
    include "message.asm"
    include "commands.asm"
    include "backup.asm"

 IFDEF LOOPBACK
    include "loopback.asm"
 ENDIF
 



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
; Data. 
;===========================================================================

;===========================================================================
; Sets up the ESP UART at joystick port and displays a text.
; Parameters:
;  E: 0x0=00b => no joystick port used
;     0x1=01b => joyport 1
;     0x2=10b => joyport 2
;===========================================================================
set_text_and_joyport:
    call set_uart_joystick
    ; Make all text invisible: INK color = paper color
    push de
    ld a,(COLOR_SCREEN) ; Get current PAPER and INK color
    ld c,a
    and 11111000b
    ld b,a
    ld a,c
    rrca : rrca : rrca
    and 00000111b
    or b
    ; Fill all 3 lines
    MEMFILL COLOR_SCREEN+32*JOY1_ROW, a, 3*32
    pop de

    ; Now make right line visible
    ld d,JOY1_ROW
    bit 0,e
    jr nz,.show
    inc d
    bit 1,e
    jr nz,.show
    inc d
.show:
    ld e,32
    mul de
    add de,COLOR_SCREEN
    ld bc,32-1
    ld hl,de
    inc de
    ld a,(COLOR_SCREEN) ; Get current PAPER and INK color
    ld (hl),a
    ldir
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
    ; Wait on key release
    in a,(c)
    and 0x1F
    cp 0x1F
    jr nz,.cont
    ret


;===========================================================================
; main routine - The main loop of the program.
;===========================================================================
main_loop:
    push bc, de

 IFDEF LOOPBACK
    ; Special loopback functionality.
    call uart_loopback
 ELSE
    ; Normal dezog functionality.
    ; Check if byte available.
    call check_uart_byte_available
    ; If so leave loop and enter command loop
    jp nz,cmd_loop    
 ENDIF

.no_uart_byte:
    ; Check keyboard
    call read_key_joyport
    inc e
    jr z,.no_keyboard
    
    ; Key pressed
    dec e
    call set_text_and_joyport

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
; Stack. 
;===========================================================================

; Stack: this area is reserved for the stack
STACK_SIZE: equ 100    ; in words


; Reserve stack space
    defw 0  ; WPMEM, 2
stack_bottom:
    defs    STACK_SIZE*2, 0
stack_top:  
    defw 0  ; WPMEM, 2





;===========================================================================
; After loading the program starts here. 
;===========================================================================
    ORG 0xC000 

    include "prequel.asm"
    include "print.asm"


    ; Save NEX file
    SAVENEX OPEN BIN_FILE, start_entry_point, stack_prequel.top // 0xC000    //stack_top: CSpect has a problem (crashes the program immediately when it is run) is stack points to stack_top which is inside the 
    SAVENEX CORE 2, 0, 0        ; Next core 2.0.0 required as minimum
    ;SAVENEX CFG 0               ; black border
    ;SAVENEX BAR 0, 0            ; no load bar
    SAVENEX AUTO
    ;SAVENEX BANK 20
    SAVENEX CLOSE
