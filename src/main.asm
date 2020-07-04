;===========================================================================
; main.asm
;===========================================================================


;===========================================================================
; Constants
;===========================================================================

    include "constants.asm"



    MMU MAIN_SLOT e, LOADED_BANK ; e -> Everything should fit into one page, error if not.
    ORG MAIN_ADDR


;===========================================================================
; Include modules
;===========================================================================

    include "macros.asm"
    include "zx/zx.inc"
    include "zx/zxnext_regs.inc"
    include "breakpoints.asm"
    include "data_const.asm"
    include "functions.asm"
    include "mf.asm"
    include "utilities.asm"
    include "uart.asm"
    include "message.asm"
    include "commands.asm"
    include "backup.asm"
    include "text.asm"
    include "ui.asm"
    include "altrom.asm"
 

;===========================================================================
; After loading the program starts here. Moves the bank to the destination 
; slot and jumps there.
;===========================================================================
    ;DISP $-MAIN_ADDR   ; Is in MF space.

; In MAIN_BANK/MAIN_SLOT.
main_bank_entry:
    di
    ; Init state
    MEMCLEAR tmp_breakpoint_1, 2*TMP_BREAKPOINT

    ; Disable MF M1 button
    call mf_nmi_disable

    ; Disable Multiface
    call mf_page_out

    ; Return from RETN (if called by NMI)
    call nmi_return ; Note: if not called by NMI nothing special will happen.

    ; Initialize the bank for slot 0 with the required code.
    ;ld a,USED_ROM0_BANK
    call copy_altrom 

    ; Copy the ZX character font from address ROM_FONT (0x3D00)
    ; to the debugger area at the end of the bank (0x2000-ROM_FONT_SIZE).
    MEMCOPY MAIN_ADDR+0x2000-ROM_FONT_SIZE, ROM_FONT, ROM_FONT_SIZE

    ; Restore SWAP_SLOT bank
    ;nextreg REG_MMU+SWAP_SLOT,a

    ; Set baudrate
    call set_uart_baudrate

    ; Init text printing
    call text.init

    ; The main program has been copied into USED_MAIN_BANK
    ld a,2  ; Joy 2 selected
    ld (uart_joyport_selection),a
    xor a
    ld (last_error),a
    
    ; Return from NMI (Interrupts are disabled)
    call nmi_return

    jp main
    ;ENT


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

    ; Init state
    ld a,PRGM_STOPPED
    ld (prgm_state),a 

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

    ; Clear possibly error code
    xor a
    ld (last_error),a

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
; DATA: All (writable) data needs to be located in
; area 0x2000-0x3FFF.
;===========================================================================
   
    ; Note: Page and slot doesn't matter as this is bss area and will be located in divmmc.
    ; However for testing (without divmmc) it is better that a bank is mapped
    ;MMU USED_DATA_SLOT e, USED_DATA_BANK
    ;ORG 0x2000

    ; Note: The area does not need to be copied. i.e. is initialized on the fly.
    include "data.asm"

; TODO: REMOVE, just for testing
    defs 0xF000-$
fake_nmi:
    push af, bc 
    ld bc,PORT_KEYB_YUIOP
    in a,(c)    ; Chec key "I"
    pop bc
    bit 2,a
    jr z,.pressed 
    pop af 
    ret 
.pressed:
    pop af
    jp MF.nmi66h

    ; TODO: REMOVE:
 IF 0
   	; Save registers
	push hl
	ld hl,mf_nmi_button_pressed.save_registers_continue
	ld (save_registers.ret_jump+1),hl
	pop hl
    jp mf_nmi_button_pressed.for_test
    ;jp mf_nmi_button_pressed
 ENDIF 

main_end:
    ASSERT main_end <= (MAIN_SLOT+1)*0x2000
    ASSERT main_end <= MAIN_ADDR+0x1F00



;===========================================================================
; After loading the program starts here. 
;===========================================================================
    ; Default slots: 254, 255, 10, 11, 4, 5, 0, 1
    ; TODO: Remove when MF is used
    MMU 4 e, 4, 0x8000 ; Slot 4 = Bank 4 (standard)
start_entry_point2:
    di
    nextreg REG_MMU+MAIN_SLOT,LOADED_BANK
    jp MF.init_main_bank

    OUTEND




;===========================================================================
; NEX file is used for testing.
;===========================================================================
     DEVICE ZXSPECTRUMNEXT

 IF 01
    ; Save NEX file
    SAVENEX OPEN BIN_FILE, start_entry_point2, debug_stack.top //stack_top: The ZX Next has a problem (crashes the program immediately when it is run) if stack points to stack_top 
    SAVENEX CORE 3, 1, 5  
    ;SAVENEX CFG 0               ; black border
    ;SAVENEX BAR 0, 0            ; no load bar
    SAVENEX AUTO
    ;SAVENEX BANK 20

    SAVEBIN "out/main.bin", 0xE000, MF_ORIGIN_ROM+0x2000-MF.main_prg_copy

    SAVENEX CLOSE

 ENDIF


;===========================================================================
; ROM for Multiface.
;===========================================================================

    include "mf_rom.asm"

