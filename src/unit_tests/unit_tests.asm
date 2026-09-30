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

; The program is loaded here for testing (NEX file)
LOADED_BANK:    EQU 92

    include "constants.asm"

    MMU MAIN_SLOT e, LOADED_BANK ; e -> Everything should fit into one page, error if not.
    ORG MAIN_ADDR    ; 0xE000

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
    include "data.asm"
    include "ui.asm"
    include "settings.asm"
    include "altrom.asm"
    include "debug.asm"
    include "dbg_send_log.asm"

    include "mf_rom.asm"


    ORG 0x7000
;PRG_START:
    include "unit_tests/unit_tests.inc"


; Sets the bank of a slot (0-6) in the MMU register and in slot_backup.
    MACRO UT_SET_SLOT slot?, bank?
    nextreg REG_MMU+slot?,bank?
    ld a,bank?
    ld (slot_backup+slot?),a
    ENDM

; Initializes slot_backup with the memory mapping at start of the unit tests.
; The mapping is also stored in ut_default_slots.
ut_init_slots:
    call save_slots
    ld a,LOADED_BANK
    ld (slot_backup.slot7),a
    MEMCOPY ut_default_slots, slot_backup, SLOT_BACKUP
    ret

; Restores the default memory mapping (MMU registers of slot 0-6 and slot_backup).
; To be used after a test that changed the mapping.
ut_reset_slots:
    MEMCOPY slot_backup, ut_default_slots, SLOT_BACKUP
    jp restore_slots

ut_default_slots:   defs SLOT_BACKUP

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
    ; Init the slot backup
    jp ut_init_slots
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
