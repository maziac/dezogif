;========================================================
; unit_tests.asm
;
; Collects and executes all unit tests.
;========================================================

    DEVICE ZXSPECTRUMNEXT

    DEFINE UNIT_TEST

 
; Need to be defined
BAUDRATE:   EQU 999999
//exit_code:    EQU 0
SWAP_SLOT:      EQU 6   ; 0xC000, used only temporary
;SWAP_SLOT1:      EQU SWAP_SLOT+1   ; 0xE000, used only temporary

MAIN_BANK: EQU 94  ; Last 8k bank on unexpanded ZXNext.
MAIN_SLOT:      EQU 7   ; 0xE000
USED_ROM0_BANK: EQU 93  
LOOPBACK_BANK:  EQU 91
LOADED_BANK:    EQU 92


MAIN_ADDR:      EQU MAIN_SLOT*0x2000


; Program title shown on screen.
    MACRO PROGRAM_TITLE
    defb "ZX Next UART DeZog Interface"
    ENDM

    MMU MAIN_SLOT e, LOADED_BANK ; e -> Everything should fit into one page, error if not.
    ORG MAIN_SLOT*0x2000    ; 0xE000
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
    include "data.asm"
    include "ui.asm"
    include "mf_rom.asm"

     
    ORG 0x7000
PRG_START:
    include "unit_tests/unit_tests.inc"  
    include "unit_tests/ut_utilities.asm"
    include "unit_tests/ut_uart.asm"
    include "unit_tests/ut_backup.asm"
    include "unit_tests/ut_commands.asm"
    include "unit_tests/ut_breakpoints.asm"
 
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
