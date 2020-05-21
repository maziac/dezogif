;========================================================
; unit_tests.asm
;
; Collects and executes all unit tests.
;========================================================

    DEVICE ZXSPECTRUMNEXT

    DEFINE UNIT_TEST

    ORG 0x7000
 

    include "zxnext/zxnext_regs.inc"
    include "utilities.asm"
    include "uart.asm"
    include "message.asm"
    include "commands.asm"
    include "backup.asm"
    include "breakpoints.asm"

     
    include "unit_tests/unit_tests.inc"  
    include "unit_tests/ut_utilities.asm"
    include "unit_tests/ut_uart.asm"
    include "unit_tests/ut_backup.asm"
    include "unit_tests/ut_commands.asm"
 
    ; Initialization routine.
    UNITTEST_INITIALIZE
    ret


    ; Save NEX file
    SAVENEX OPEN BIN_FILE
    SAVENEX CORE 2, 0, 0        ; Next core 2.0.0 required as minimum
    ;SAVENEX CFG 0               ; black border
    ;SAVENEX BAR 0, 0            ; no load bar
    SAVENEX AUTO
    SAVENEX CLOSE
