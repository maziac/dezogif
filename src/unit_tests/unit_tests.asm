;========================================================
; unit_tests.asm
;
; Collects and executes all unit tests.
;========================================================


    DEFINE UNIT_TEST

    ORG 0x7000
    
    include "unit_tests/unit_tests.inc"  
    include "unit_tests/ut_backup.asm"
 
    ; Initialization routine.
    UNITTEST_INITIALIZE
    ret

    include "main.asm"
 