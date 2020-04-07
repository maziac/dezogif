;========================================================
; unit_tests.asm
;
; Collects and executes all unit tests.
;========================================================


    DEFINE UNIT_TEST

     
    include "main.asm"
    include "unit_tests/unit_tests.inc"  
    include "unit_tests/ut_macros.asm"  
;    include "unit_tests/ut_audio.asm"
 
    ; Initialization routine.
    UNITTEST_INITIALIZE
    ret

