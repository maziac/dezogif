;===========================================================================
; main.asm
;===========================================================================

    SLDOPT COMMENT WPMEM, LOGPOINT, ASSERTION

    DEVICE ZXSPECTRUMNEXT

;===========================================================================
; Constants
;===========================================================================

    include "constants.asm"

    ORG MAIN_ADDR


/* TODO:
- solve github issues.
    - Clear copied memory
- stepOver:
	nop
	NEXTREG $51,12
    bei nop, stepped über beide
- add command for setting a port.
- Command to set a port to support setting 0x7FFD (to switch in the right ROM) when loading 128k SNA files.
- Enabling/disabling of the interrupt. For loading 48k and 128k SNA files: index 0x13 (iff2), bit 2 contains 0=di, 1=ei. https://sinclair.wiki.zxnet.co.uk/wiki/SNA_format (sjasmplus always sets 0),
- To be a little bit more future proof: Execute a little binary.
*/

;===========================================================================
; Include modules
;===========================================================================

    include "macros.asm"
    include "zx/zx.inc"
    include "zx/zxnext_regs.inc"
    include "breakpoints.asm"
    include "data_const.asm"
    include "mf.asm"
    include "utilities.asm"
    include "uart.asm"
    include "message.asm"
    include "commands.asm"
    include "backup.asm"
    include "text.asm"
    include "ui.asm"
    include "altrom.asm"
    ;include "debug.asm" ; Include for some rudimentary debug functionality


;===========================================================================
; After loading the program starts here. Moves the bank to the destination
; slot and jumps there.
;===========================================================================
    ;DISP $-MAIN_ADDR   ; Is in MF space.

; In MAIN_BANK/MAIN_SLOT.
main_bank_entry:
    di
    ; Setup stack
    ld sp,debug_stack.top

    ; Init state
    MEMCLEAR tmp_breakpoint_1, 2*TMP_BREAKPOINT

    ; Disable Multiface
    MF_PAGE_OUT

    ; Return from RETN (if called by NMI)
    call nmi_return ; Note: if not called by NMI nothing special will happen.

    ; Initialize the bank for slot 0 with the required code.
    call copy_altrom

    ; Copy the ZX character font from address ROM_FONT (0x3D00)
    ; to the debugger area at the end of the bank (0x2000-ROM_FONT_SIZE).
    ; Switch in ROM bank
    nextreg REG_MMU+0,ROM_BANK
    nextreg REG_MMU+1,ROM_BANK
    MEMCOPY MAIN_ADDR+0x2000-ROM_FONT_SIZE+MF_ORIGIN_ROM-MF.main_prg_copy, ROM_FONT, ROM_FONT_SIZE

    ; Restore SWAP_SLOT bank
    ;nextreg REG_MMU+SWAP_SLOT,a

    ; Set baudrate
    call set_uart_baudrate

    ; Init text printing
    call text.init

    ; The main program has been copied into MAIN_BANK
    ld a,2  ; Joy 2 selected
    ld (uart_joyport_selection),a
    xor a
    ld (last_error),a

    ; Enable flashing border
    call uart_flashing_border.enable

    ; Enable slow border change
    ld a,1
    ld (slow_border_change),a

    ; Return from NMI (Interrupts are disabled)
    call nmi_return

    ;DBG_CLEAR

    ; Flow through


;===========================================================================
; main routine - The main loop of the program.
;===========================================================================
main:
    di
    ; Setup stack
    ld sp,debug_stack.top

    ; Black border
    xor a
    out (BORDER),a

    ; Init layer 2
    ld bc,LAYER_2_PORT
    xor a
    out (c),a
    ld (backup.layer_2_port),a

    ; Init clock speed
    ld a,RTM_3MHZ
    ld (backup.speed),a

    ; Init state
    ld a,PRGM_IDLE
    ld (prgm_state),a

    ; Init interrupt state
    xor a
	ld (backup.interrupt_state),a

    ; Init slot 0 bank
    ld a,ROM_BANK
    ld (slot_backup.slot0),a

    ; Set UART
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
.continue:

.no_uart_byte:
    ; Check keyboard
    call check_key_reset
    call check_key_border
    jp z,main   ; Jump if "B" pressed
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


main_end:
    ASSERT main_end <= (MAIN_SLOT+1)*0x2000
    ASSERT main_end <= MAIN_ADDR+0x1F00



;===========================================================================
; Save bin file.
;===========================================================================

    SAVEBIN "out/main.bin", 0xE000, MF_ORIGIN_ROM+0x2000-MF.main_prg_copy

    ;SAVENEX CLOSE


;===========================================================================
; ROM for Multiface.
;===========================================================================

    include "mf_rom.asm"

