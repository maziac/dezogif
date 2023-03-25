;========================================================
; unit_tests.asm
;
; Collects and executes all unit tests.
;========================================================

    SLDOPT COMMENT WPMEM, LOGPOINT, ASSERTION

    DEVICE ZXSPECTRUMNEXT

    DEFINE UNIT_TEST

    DEFINE MF_FAKE  ; For some tests of the NMI

; Required labels:
main_bank_entry:    equ 0x0000  ; Not used
main_end:    equ 0xE100  ; Not used


    include "constants.asm"

    MMU MAIN_SLOT e, LOADED_BANK ; e -> Everything should fit into one page, error if not.
    ORG MAIN_ADDR    ; 0xE000

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
    include "data.asm"
    include "ui.asm"
    include "altrom.asm"
    include "debug.asm"

    include "mf_rom.asm"


    ORG 0x7000
PRG_START:
    include "unit_tests/unit_tests.inc"
    include "unit_tests/ut_utilities.asm"
    include "unit_tests/ut_uart.asm"
    include "unit_tests/ut_backup.asm"
    include "unit_tests/ut_commands.asm"
    include "unit_tests/ut_message.asm"
    include "unit_tests/ut_breakpoints.asm"
    include "unit_tests/ut_nmi.asm"

; Required labels:
main_loop.continue:     ret

    ; Initialization routine.
    UNITTEST_INITIALIZE
    ; Page in main bank
    nextreg REG_MMU+MAIN_SLOT,LOADED_BANK
    ret
PRG_END:


; Check to avoid that program is put in a memory area that is used
; in unit testing.
    ;ASSERT PRG_START >= 0x7000
    ASSERT PRG_END <= 0xBFFF

    ; Save NEX file
    SAVENEX OPEN BIN_FILE
    SAVENEX CORE 2, 0, 0        ; Next core 2.0.0 required as minimum
    ;SAVENEX CFG 0               ; black border
    ;SAVENEX BAR 0, 0            ; no load bar
    SAVENEX AUTO
    SAVENEX CLOSE
