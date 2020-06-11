;========================================================
; ut_backup.asm
;
; Unit tests for save/restore of registers.
;========================================================


    MODULE ut_backup

; To save the sp value
sp_backup:  defw    0


; Test that subroutine returns correctly.
UT_save_registers.UT_returns:
    ; Init
    ld (sp_backup),sp
    ld sp,backup.af

    ; Test
    call save_registers

    ; Deinit
    ld sp,(sp_backup)
 TC_END


; Test that all registers are saved correctly.
UT_save_registers.UT_save:
    ; Remember SP
    ld (sp_backup),sp

    ; Prepare registers
    exx 
    ex af,af'
    ld a,0x2A
    ld bc,0x2B2C
    ld de,0x2D2E
    ld hl,0x2122
    ex af,af'
    exx

    push 0x9765    ; Push a test value used as PC

    ld a,0x1A
    push af

    ld bc,0x1B1C
    ld de,0x1D1E
    ld hl,0x1112
    
    ld ix,0x1314
    ld iy,0x1516

    ; I, R
    ld a,0x81
    ld i,a
    ld a,0x82
    ld r,a

    ; Test
    call save_registers

    TEST_MEMORY_BYTE backup.af+1, 0x1A
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

    TEST_MEMORY_WORD backup.pc, 0x9765
 
    ; Test stack pointer
    ld hl,(sp_backup)       ; Remember
    ld (sp_backup),sp       ; Store to check
    TEST_MEMORY_WORD sp_backup, debug_stack_top

    ; Deinit
    ld sp,hl
 TC_END


; Test that all registers are restored correctly.
UT_save_registers.UT_restore:
    ; Init
    ld hl,.continue     ; The jump address
    ld (backup.pc),hl   ; Continue at return address
    ld (backup.sp),sp

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
 TC_END


; Test that save register function for coop works.
UT_save_registers:
    ; Remember SP
    ld (sp_backup),sp

    ; Prepare registers
    exx 
    ex af,af'
    ld a,0x2A
    ld bc,0x2B2C
    ld de,0x2D2E
    ld hl,0x2122
    ex af,af'
    exx

    ld a,0x1A
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
    push 0x9768    ; Push a test value used as reurn address/PC
    call save_registers

    TEST_MEMORY_BYTE backup.af+1, 0x1A
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

    TEST_MEMORY_WORD backup.pc, 0x9768
 
    ; Test stack pointer
    ld hl,(sp_backup)       ; Remember
    ld (sp_backup),sp       ; Store to check
    TEST_MEMORY_WORD sp_backup, debug_stack_top

    ; Deinit
    ld sp,hl
 TC_END


    ENDMODULE
    