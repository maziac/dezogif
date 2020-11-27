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
    ld hl,.return
    ld (save_registers.ret_jump+1),hl

    ; Test
    jp save_registers
.return:

    ; Deinit
    ld sp,(sp_backup)
 TC_END


; Test that all registers are saved correctly.
UT_save_registers.UT_save:
    ; Init
    ld hl,.return
    ld (save_registers.ret_jump+1),hl
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

    ; I, R
    ld a,0x81
    ld i,a
    ld a,0x82
    ld r,a
    ld a,0x1A

    ld bc,0x1B1C
    ld de,0x1D1E
    ld hl,0x1112

    ld ix,0x1314
    ld iy,0x1516

    ; Test
    jp save_registers
.return:
    ld sp,(sp_backup)

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

    ; Test stack pointer
    TEST_MEM_CMP sp_backup, backup.sp, 2

 TC_END


; Test that all registers are restored correctly.
UT_save_registers.UT_restore:
    ; Init
    ld (sp_backup),sp

    ld hl,.continue     ; The jump address
    ld (restore_registers.ret_jump1+1),hl
    ld (restore_registers.ret_jump2+1),hl

    ld hl,0x1234    ; PC
    ld (backup.pc),hl
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

    ; A
    ld a,0xA1
    ld (backup.af+1),a

    ; Test
    jp restore_registers

    ; The call should never return
    TEST_FAIL

    ; But go on here
.continue:
    ; TEST ASSERTION bc == 0x1B1C
    ; TEST ASSERTION de == 0x1D1E
    ; TEST ASSERTION hl == 0x1112
    ; TEST ASSERTION ix == 0x1314
    ; TEST ASSERTION iy == 0x1516

    exx
    ex af,af'
    ; TEST ASSERTION a == 0x2A
    ; TEST ASSERTION bc == 0x2B2C
    ; TEST ASSERTION de == 0x2D2E
    ; TEST ASSERTION hl == 0x2122
    ex af,af'
    exx

    ld a,i
    ; TEST ASSERTION a == 0x81
    ;TEST_MEMORY_BYTE backup.r, 0x82   Useless to test

    TEST_MEMORY_WORD debugged_prgm_stack_copy.return1, 0x1234   ; PC
    TEST_MEMORY_BYTE debugged_prgm_stack_copy.af+1, 0xA1   ; A

    ; Test SP
    ld hl,(sp_backup)
    add hl,-4
    ld (sp_backup),sp
    ld de,(sp_backup)
    ; TEST ASSERTION hl == de

    ld sp,(sp_backup)
 TC_END


; Test that all registers are correctly enabled/disabled.
UT_save_registers.UT_restore_interrupts:
    ; The jump address for enable interrupts
    ld hl,.continue_ei
    ld (restore_registers.ret_jump1+1),hl
    ; The jump address for enable interrupts
    ld hl,.continue_di
    ld (restore_registers.ret_jump2+1),hl

    ; Enable interrupts
    ld a,00000100b
    ld (backup.interrupt_state),a

    ; Test
    call .test_intrpt

    ; TEST ASSERTION a == 1   ; Interrupts enabled

    ; Disable interrupts
    ld a,00000000b
    ld (backup.interrupt_state),a

    ; Test
    call .test_intrpt

    ; TEST ASSERTION a == 0   ; Interrupts enabled
 TC_END

.test_intrpt:
    ; Test
    ld (sp_backup),sp
    jp restore_registers
    ; The call should never return
    TEST_FAIL
    ; But here
.continue_ei:
    ld sp,(sp_backup)
    ld a,1
    ret
    ; Or here
.continue_di:
    ld sp,(sp_backup)
    ld a,0
    ret


; Test that memory is read correctly. Area outside ROM and slot 7.
UT_read_debugged_prgm_mem.UT_simple:
    ; Init
    MEMCLEAR .mem_write, .mem_length

    ld hl,.mem_read
    ld de,.mem_length
    ld bc,.mem_write
    call read_debugged_prgm_mem

    TEST_MEM_CMP .mem_read, .mem_write, .mem_length
 TC_END
.mem_read:  defb 0xA1, 0xA2, 0xA3
.mem_length:    equ $-.mem_read
.mem_write: defs .mem_length


; Test that memory is read correctly. Area inside slot 7.
UT_read_debugged_prgm_mem.UT_slot7:
    ; Init
    ; Use bank 40 for testing
    ld a,40
    ld (slot_backup.slot7),a
    nextreg REG_MMU+MAIN_SLOT,a
    ld a,0xB0
    ld hl,0xE000
    ld b,5
.loop:
    ldi (hl),a
    inc a
    djnz .loop


    ld hl,0xE000
    ld de,5
    ld bc,.mem_write
    nextreg REG_MMU+MAIN_SLOT,LOADED_BANK
    call read_debugged_prgm_mem

    TEST_MEMORY_BYTE .mem_write, 0xB0
    TEST_MEMORY_BYTE .mem_write+1, 0xB1
    TEST_MEMORY_BYTE .mem_write+2, 0xB2
    TEST_MEMORY_BYTE .mem_write+3, 0xB3
    TEST_MEMORY_BYTE .mem_write+4, 0xB4
 TC_END
.mem_write: defs 5


; Test that memory is read correctly. Area at border 0xDFFF-0xE000.
UT_read_debugged_prgm_mem.UT_border_0xE000:
    ; Init
    ; Use bank 40 for testing in slot 7, slot 6 is anyway swap slot, i.e. don't care
    ld a,40
    ld (slot_backup.slot7),a
    nextreg REG_MMU+MAIN_SLOT,a
    ld a,0xB0
    ld hl,0xDFFD
    ld b,5
.loop:
    ldi (hl),a
    inc a
    djnz .loop

    ld hl,0xDFFD
    ld de,5
    ld bc,.mem_write
    nextreg REG_MMU+MAIN_SLOT,LOADED_BANK
    call read_debugged_prgm_mem

    TEST_MEMORY_BYTE .mem_write, 0xB0
    TEST_MEMORY_BYTE .mem_write+1, 0xB1
    TEST_MEMORY_BYTE .mem_write+2, 0xB2
    TEST_MEMORY_BYTE .mem_write+3, 0xB3
    TEST_MEMORY_BYTE .mem_write+4, 0xB4
 TC_END
.mem_write: defs 5

; Test that memory is read correctly. Area at border 0xFFFF-0x0000.
UT_read_debugged_prgm_mem.UT_border_0x0000:
    ; Init
    ; Use bank 40 for testing in slot 7
    ; and bank 39 for slot 0
    ld a,40
    ld (slot_backup.slot7),a
    nextreg REG_MMU+MAIN_SLOT,a
    dec a
    nextreg REG_MMU,a
    ld a,0xC0
    ld hl,0xFFFD
    ld b,5
.loop:
    ldi (hl),a
    inc a
    djnz .loop

    ld hl,0xFFFD
    ld de,5
    ld bc,.mem_write
    nextreg REG_MMU+MAIN_SLOT,LOADED_BANK
    call read_debugged_prgm_mem

    TEST_MEMORY_BYTE .mem_write, 0xC0
    TEST_MEMORY_BYTE .mem_write+1, 0xC1
    TEST_MEMORY_BYTE .mem_write+2, 0xC2
    TEST_MEMORY_BYTE .mem_write+3, 0xC3
    TEST_MEMORY_BYTE .mem_write+4, 0xC4
 TC_END
.mem_write: defs 5


; Test that memory is read correctly. Area outside ROM and slot 7.
UT_write_debugged_prgm_mem.UT_simple:
    ; Init
    MEMCLEAR .mem_write, .mem_length

    ld hl,.mem_write
    ld de,.mem_length
    ld bc,.mem_read
    call write_debugged_prgm_mem

    TEST_MEM_CMP .mem_write, .mem_read, .mem_length
 TC_END
.mem_read:  defb 0xA1, 0xA2, 0xA3
.mem_length:    equ $-.mem_read
.mem_write: defs .mem_length


    ENDMODULE
