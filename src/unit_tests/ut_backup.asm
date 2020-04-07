;========================================================
; ut_backup.asm
;
; Unit tests for save/restore of registers.
;========================================================


    MODULE ut_backup


; Test that subroutine returns correctly.
UT_save_registers_returns:
    call save_registers
    ret 

    ENDMODULE
    