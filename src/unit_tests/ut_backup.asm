;========================================================
; ut_backup.asm
;
; Unit tests for save/restore of registers.
;========================================================


    MODULE ut_backup

; To save the sp value
sp_backup:  defw    0


; Test that subroutine returns correctly.
save_registers.UT_returns:
    ; Init
    ld (sp_backup),sp
    ld sp,backup.af

    ; Test
    call save_registers

    ; Deinit
    ld sp,(sp_backup)
    ret 


; Test that all registers are saved correctly.
save_registers.UT_save:
    ; Init
    ld (sp_backup),sp
    ld sp,backup.af

    ; Prepare registers
    exx 
    ex af,af'
    ld a,0x2A
    ld bc,0x2B2C
    ld de,0x2D2E
    ld hl,0x2122
    ex af,af'
    exx

    ld bc,0x1B1C
    ld de,0x1D1E
    ld hl,0x1112
    
    ld ix,0x1314
    ld iy,0x1516

    ; I, R
    push af
    ld a,0x81
    ld i,a
    ld a,0x82
    ld r,a
    pop af

    ; Test
    call save_registers

    TEST_MEMORY_WORD backup.bc, 0x1B1C
    TEST_MEMORY_WORD backup.de, 0x1D1E
    TEST_MEMORY_WORD backup.hl, 0x1112
    TEST_MEMORY_WORD backup.ix, 0x1314
    TEST_MEMORY_WORD backup.iy, 0x1516

    TEST_MEMORY_BYTE backup.af2+1, 0x2A
    TEST_MEMORY_WORD backup.bc2, 0x2B2C
    TEST_MEMORY_WORD backup.de2, 0x2D2E
    TEST_MEMORY_WORD backup.hl2, 0x2122

    TEST_MEMORY_BYTE backup.i, 0x81
    ;TEST_MEMORY_BYTE backup.r, 0x82   Useless to test
 
    ; Test stack pointer
    ld hl,(sp_backup)       ; Remember
    ld (sp_backup),SP       ; Store to check
    TEST_MEMORY_WORD sp_backup, debug_stack_top

    ; Deinit
    ld sp,hl
    ret 


; Test that all registers are restored correctly.
save_registers.UT_restore:
    ; Init
    ld hl,.continue     ; The jump address
    push hl     ; Continue us used a return address
    ld (backup.sp),sp
    ld sp,backup.af

    ; Prepare data
    ld a,0x2A
    ld (backup.af2+1),a

    ld hl,0x2B2C
    ld (backup.bc2),hl
    ld hl,0x2D2E
    ld (backup.de2),hl
    ld hl,0x2122
    ld (backup.hl2),hl

    ld hl,0x1B1C
    ld (backup.bc),hl
    ld hl,0x1D1E
    ld (backup.de),hl
    ld hl,0x1112
    ld (backup.hl),hl
    
    ld hl,0x1314
    ld (backup.ix),hl
    ld hl,0x1516
    ld (backup.iy),hl
    
    ; I
    ld a,0x81
    ld (backup.i),a

    ld a,0x1A
    ld (backup.af+1),a
 
    ; TODO: Do I neet to test backup.pc?

    ; Test
    jp restore_registers

    ; The call should never return
    TEST_FAIL

    ; But go on here
.continue:
    TEST_DREG bc, 0x1B1C
    TEST_DREG de, 0x1D1E
    TEST_DREG hl, 0x1112
    TEST_DREG ix, 0x1314
    TEST_DREG iy, 0x1516

    exx
    ex af,af'
    TEST_REG a, 0x2A
    TEST_DREG bc, 0x2B2C
    TEST_DREG de, 0x2D2E
    TEST_DREG hl, 0x2122
    ex af,af'
    exx

    TEST_REG i, 0x81
    ;TEST_MEMORY_BYTE backup.r, 0x82   Useless to test
 
    ret 


    ENDMODULE
    