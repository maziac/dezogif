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
SWAP_SLOT1:      EQU SWAP_SLOT+1   ; 0xE000, used only temporary

USED_BANK: EQU 94  ; Last 8k bank on unexpanded ZXNext.
USED_SLOT:      EQU 0   ; 0x0000
USED_ROM0_BANK: EQU 93  

    ORG 0x7000
PRG_START:
    include "macros.asm"
    include "zxnext/zxnext_regs.inc"
    include "breakpoints.asm"
    include "utilities.asm"
    include "print.asm"
    include "uart.asm"
    include "message.asm"
    include "commands.asm"
    include "backup.asm"
    include "data.asm"

     
    include "unit_tests/unit_tests.inc"  
    include "unit_tests/ut_utilities.asm"
    include "unit_tests/ut_uart.asm"
    include "unit_tests/ut_backup.asm"
    include "unit_tests/ut_commands.asm"
    include "unit_tests/ut_breakpoints.asm"
 
    ; Initialization routine.
    UNITTEST_INITIALIZE
    ret
PRG_END:


; Check to avoid that program is put i a memory area that is used 
; in unit testing.
    ASSERT PRG_START >= 0x7000
    ASSERT PRG_END <= 0xBFFF

    ; Save NEX file
    SAVENEX OPEN BIN_FILE
    SAVENEX CORE 2, 0, 0        ; Next core 2.0.0 required as minimum
    ;SAVENEX CFG 0               ; black border
    ;SAVENEX BAR 0, 0            ; no load bar
    SAVENEX AUTO
    SAVENEX CLOSE
