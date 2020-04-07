;========================================================
; ut_backup.asm
;
; Unit tests for save/restore of registers.
;========================================================


    MODULE ut_backup

; To save the sp value
sp_backup:  defw    0


; Test that subroutine returns correctly.
UT_save_registers_returns:
    ld (sp_backup),sp
    ld sp,backup.af
    call save_registers
    ld sp,(sp_backup)
    ret 

    ENDMODULE
    