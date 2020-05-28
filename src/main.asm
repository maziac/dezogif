;===========================================================================
; main.asm
;===========================================================================

    DEVICE ZXSPECTRUMNEXT

; The 8k memory bank to store the code to.
USED_MAIN_BANK:  EQU 95  ; Last 8k bank on unexpanded ZXNext
USED_SLOT:  EQU 1   ; 0x2000

USED_ROM_BANK:  EQU 94  ; Bank used to copy the ROM (0x0000) to and change the RST 0 address into a jump.


    MMU USED_SLOT e, USED_MAIN_BANK ; e -> Everything should fit inot one page, error if not.
    ORG USED_SLOT*0x2000


    
;===========================================================================
; Include modules
;===========================================================================

    include "zxnext/zxnext_regs.inc"
    include "utilities.asm"
    include "print.asm"
    include "uart.asm"
    include "message.asm"
    include "commands.asm"
    include "backup.asm"
    include "breakpoints.asm"



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

INTRO_TEXT: 
    defb OVER, 0
    defb AT, 0, 0
    defb "ZX Next UART loopback"
    defb AT, 1, 0
    defb "ESP UART Baudrate: "
    STRINGIFY BAUDRATE
    ;Line 2 used for joyport configuration
    defb AT, 3, 0
    defb "Tx=7, Rx=9"
    defb AT, 5, 0
    defb "Keys:"
    defb AT, 6, 0
    defb "1 = Joy 1"
    defb AT, 7, 0
    defb "2 = Joy 2"
    defb AT, 8, 0
    defb "3 = No joystick port"
.end
    defb EOS

JOY1_TEXT:
    defb AT, 2, 0, "Using Joy 1 (left)    ", EOS
JOY2_TEXT:
    defb AT, 2, 0, "Using Joy 2 (right)   ", EOS
NOJOY_TEXT:
    defb AT, 2, 0, "No joystick port used.", EOS



;===========================================================================
; Sets up the ESP UART at joystick port and displays a text.
; Parameters:
;  E: 0x0=00b => no joystick port used
;     0x1=01b => joyport 1
;     0x2=10b => joyport 2
;===========================================================================
set_text_and_joyport:
    call set_uart_joystick
    ld hl,JOY2_TEXT
    bit 1,e
    jr nz,.print
    ld hl,JOY1_TEXT
    bit 0,e
    jr nz,.print
    ld hl,NOJOY_TEXT
.print:
	jp print


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
; main routine - the code execution starts here.
;===========================================================================
main:
    ; Disable interrupts
    di
 
	; Maximize clock speed
	ld a,RTM_28MHZ
	nextreg REG_TURBO_MODE,a

    ; Setup stack
    ld sp,stack_top

    ; Init state
    xor a
    ld (state),a
    MEMCLEAR tmp_breakpoint_1, 2*TMP_BREAKPOINT

    ; Backup slot 6
    ld a,REG_MMU+6
    call read_tbblue_reg    ; returns the bank in A

    ; Switch in the bank at 0xC000
    nextreg REG_MMU+6,USED_ROM_BANK
    ; Copy the ROM at 0x0000 to bank USED_ROM_BANK
    MEMCOPY 0xC000, 0x0000, 0x2000

    ; Overwrite the RST 0 address with a jump
    ld hl,0xC000
    ldi (hl),0xC3   ; JP
    ldi (hl),LOW enter_breakpoint
    ld (hl),HIGH enter_breakpoint

    ; Restore slot 6 bank
    nextreg REG_MMU+6,a

    ; Page in copied ROM bank to slot 0
    nextreg REG_MMU+0,USED_ROM_BANK

    ; Set baudrate
    call set_uart_baudrate

    ; Init
    call drain_rx_buffer

    ; Clear screen
	;ld iy,VAR_ERRNR
    call ROM_CLS
    
    ; Print text    
    ld hl,INTRO_TEXT
	call print

    ; Set uart at joystick port
    ld e,2  ; Joy 2
    call set_text_and_joyport

    ; Border color timer
    ld c,1     
main_loop:
    push bc, de

    ; Check if byte available.
    call dbg_check_for_message

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
; After loading the program starts here. Moves the bank to the destination 
; slot and jumps there.
;===========================================================================
    ORG 0xC000 
start_entry_point:
    ; At startup this program is mapped at 0xC000
    di
    ; Switch in the bank at 0x4000
    nextreg REG_MMU+USED_SLOT,USED_MAIN_BANK
    ; Now the right bank is mapped into the slot, jump to the slot and continue
    jp main


    ; Save NEX file
    SAVENEX OPEN BIN_FILE, start_entry_point, stack_top // 0xC000    //stack_top: CSpect has a problem (crashes the program immediately when it is run) is stack points to stack_top which is inside the 
    SAVENEX CORE 2, 0, 0        ; Next core 2.0.0 required as minimum
    ;SAVENEX CFG 0               ; black border
    ;SAVENEX BAR 0, 0            ; no load bar
    SAVENEX AUTO
    ;SAVENEX BANK 20
    SAVENEX CLOSE
