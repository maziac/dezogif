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

;===========================================================================
; Include modules
;===========================================================================

    ; Define this for some rudimentary debug functionality
    DEFINE DEBUG
    ; Define this for sending debug logs over UART
    DEFINE DBG_SEND_LOG

    include "macros.asm"
    include "zx/zx.inc"
    include "zx/zxnext_regs.inc"
    include "zx/esxdos.inc"
    include "breakpoints.asm"
    include "data_const.asm"
    include "mf.asm"
    include "utilities.asm"
    include "uart.asm"
    include "copper.asm"
    include "message.asm"
    include "commands.asm"
    include "backup.asm"
    include "text.asm"
    include "ui.asm"
    include "settings.asm"
    include "altrom.asm"
    include "debug.asm"
    include "dbg_send_log.asm"


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


    ; Enable flashing border
    call uart_flashing_border.enable


    ; Return from NMI (Interrupts are disabled)
    call nmi_return


    ; Load settings
    xor a   ; No error
    ld (last_error),a
    call load_open
    jr c,.default_values  ; File not found
    call load_settings
    jr nc,drain_main.skip_store
    ; Read error
    ld a,ERROR_FILE_READ
    ld (last_error),a

.default_values:
    ; Load default values
    ld a,2  ; Joy 2 selected
    ld (uart_joyport_selection),a
    ; Enable async break
    dec a ; A=1
    ld (copper_break_enabled),a
    jr drain_main.skip_store

;===========================================================================
; main entry - Jump here in case of an error.
; A contains the error.
;===========================================================================
drain_main:
    ; Store error
    ld (last_error),a
drain_main.skip_store:
    ; Drain
    call drain_rx_buffer

    ; Flow through


main_with_copper_stop:
    ; Stop the copper list if it is running.
    nextreg REG_COPPER_CONTROL_H, %00000000   ; Copper stoppen (Bits 7-6 = 00)
    nextreg REG_PALETTE_CONTROL, 0
    call set_ula_default_palette
    call copper.break_stop
    SEND_NTF_LOG "main_with_copper_stop", 0

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

    ; Show the text
    call init_and_show_ui

main_loop:
    ; Check if byte available.
    call check_uart_byte_available
    ; If so leave loop and enter command loop
    jp nz,cmd_loop
.continue:

.no_uart_byte:
    ; Check keyboard
    call read_key_joyport
    call check_key_copper
    call check_key_reset
    call check_key_save
    call check_key_help

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

    ; The real ceiling is lower than either of the two above, and neither of
    ; them can see it: main_bank_entry copies the ZX font into the top of this
    ; bank and nothing in the source emits a byte there, so growing past that
    ; address aliases the debugger's variables onto the glyph bitmaps - silently
    ; and in both directions. Same expression as the MEMCOPY that fills it.
    ASSERT main_end <= MAIN_ADDR+0x2000-ROM_FONT_SIZE+MF_ORIGIN_ROM-MF.main_prg_copy



;===========================================================================
; Save bin file.
;===========================================================================

    SAVEBIN "out/main.bin", 0xE000, MF_ORIGIN_ROM+0x2000-MF.main_prg_copy

    ;SAVENEX CLOSE


;===========================================================================
; ROM for Multiface.
;===========================================================================

    include "mf_rom.asm"

