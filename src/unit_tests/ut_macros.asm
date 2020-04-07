;========================================================
; unit_macros.asm
;
; Unit tests for macros in unit_tests.inc
;========================================================

    MODULE ut_macros



UT_TEST_UNCHANGED:
    DEFAULT_REGS
    TEST_UNCHANGED_A
    TEST_UNCHANGED_BC
    TEST_UNCHANGED_DE
    TEST_UNCHANGED_HL
    TEST_UNCHANGED_BC_DE
    TEST_UNCHANGED_BC_DE_HL
    TEST_UNCHANGED_B
    TEST_UNCHANGED_C
    TEST_UNCHANGED_D
    TEST_UNCHANGED_E
    TEST_UNCHANGED_H
    TEST_UNCHANGED_L
    ret
test_mem_byte:  defb 0x12
test_mem_word:  defw 0x3456

UT_TEST_MEMORY_BYTE:
    DEFAULT_REGS
    TEST_MEMORY_BYTE test_mem_byte, 0x12

    TEST_UNCHANGED_A
    TEST_UNCHANGED_BC_DE_HL
    ret

UT_TEST_MEMORY_WORD:
    DEFAULT_REGS

    TEST_MEMORY_WORD test_mem_word, 0x3456

    TEST_UNCHANGED_A
    TEST_UNCHANGED_BC_DE_HL
    ret

UT_TEST_A:
    DEFAULT_REGS

    ld a,5
    TEST_A 5

    TEST_UNCHANGED_BC_DE_HL
    ret

UT_TEST_A_UNEQUAL:
    DEFAULT_REGS

    ld a,5
    TEST_A_UNEQUAL 6

    TEST_UNCHANGED_BC_DE_HL
    ret

UT_TEST_REG:
    DEFAULT_REGS
    ld b,5
    TEST_REG b, 5
    TEST_UNCHANGED_A
    TEST_UNCHANGED_DE
    TEST_UNCHANGED_HL
    TEST_UNCHANGED_C

    ld a,4
    TEST_REG a, 4   ; pathological, anyway

    ld c,6
    TEST_REG c, 6

    ld d,7
    TEST_REG d, 7

    ld e,8
    TEST_REG e, 8

    ld h,9
    TEST_REG h, 9

    ld l,10
    TEST_REG l, 10
    ret

UT_TEST_REG_UNEQUAL:
    DEFAULT_REGS
    ld b,5
    TEST_REG_UNEQUAL b, 255
    TEST_UNCHANGED_A
    TEST_UNCHANGED_DE
    TEST_UNCHANGED_HL
    TEST_UNCHANGED_C

    ld a,4
    TEST_REG_UNEQUAL a, 255   ; pathological, anyway

    ld c,6
    TEST_REG_UNEQUAL c, 255

    ld d,7
    TEST_REG_UNEQUAL d, 255

    ld e,8
    TEST_REG_UNEQUAL e, 255

    ld h,9
    TEST_REG_UNEQUAL h, 255

    ld l,10
    TEST_REG_UNEQUAL l, 255
    ret


UT_TEST_DREG:
    DEFAULT_REGS
    ld bc,0x1234
    TEST_DREG bc, 0x1234
    TEST_UNCHANGED_A
    TEST_UNCHANGED_DE
    TEST_UNCHANGED_HL
    
    ld de,0x5678
    TEST_DREG de, 0x5678

    ld hl,0x9ABC
    TEST_DREG hl, 0x9ABC

    ld ix,0xDEF0
    TEST_DREG ix, 0xDEF0

    ld iy,0x2345
    TEST_DREG iy, 0x2345
    ret

UT_TEST_DREG_UNEQUAL:
    DEFAULT_REGS
    ld bc,0x1234
    TEST_DREG_UNEQUAL bc, 0xFFFF
    TEST_UNCHANGED_A
    TEST_UNCHANGED_DE
    TEST_UNCHANGED_HL
    
    ld de,0x5678
    TEST_DREG_UNEQUAL de, 0xFFFF

    ld hl,0x9ABC
    TEST_DREG_UNEQUAL hl, 0xFFFF

    ld ix,0xDEF0
    TEST_DREG_UNEQUAL ix, 0xFFFF

    ld iy,0x2345
    TEST_DREG_UNEQUAL iy, 0xFFFF
    ret

UT_TEST_DREGS:
    DEFAULT_REGS
    ld bc,0x1234
    ld de,0x1234
    TEST_DREGS bc, de
    TEST_UNCHANGED_A
    TEST_UNCHANGED_HL
    TEST_DREG de, 0x1234
    TEST_DREG bc, 0x1234

    ld de,0x5678
    ld hl,0x5678
    TEST_DREGS de, hl
    ret

UT_TEST_DREGS_UNEQUAL:
    DEFAULT_REGS
    ld bc,0x1234
    ld de,0x1235
    TEST_DREGS_UNEQUAL bc, de
    TEST_UNCHANGED_A
    TEST_UNCHANGED_HL
    TEST_DREG de, 0x1235
    TEST_DREG bc, 0x1234

    ld de,0x5678
    ld hl,0x5679
    TEST_DREGS_UNEQUAL de, hl
    ret


UT_TEST_STRING:
    DEFAULT_REGS

    TEST_STRING test_string, '123456', 0    ; with null termination
    
    TEST_UNCHANGED_A
    TEST_UNCHANGED_BC_DE_HL

    TEST_STRING test_string, '1234', 1  ; without null termination
    ret
test_string: defb '123456', 0

UT_TEST_FLAG_Z:
    xor a   ; Set Z
    DEFAULT_REGS   
    TEST_FLAG_Z ; Test Z
    TEST_UNCHANGED_A
    TEST_UNCHANGED_BC_DE_HL
    ret

UT_TEST_FLAG_NZ:
    ld a,1
    or a   ; Reset Z
    DEFAULT_REGS   
    TEST_FLAG_NZ ; Test Z
    TEST_UNCHANGED_A
    TEST_UNCHANGED_BC_DE_HL
    ret

UT_USE_ALL_REGS:
    ; Clear all registers
    ld a,0 
    ld bc,0
    ld de,0
    ld hl,0
    ld ix,0
    ld iy,0
    exx
    ld a,0
    ld bc,0
    ld de,0
    ld hl,0
    exx

    USE_ALL_REGS

    ; Check
    TEST_A_UNEQUAL 0
    TEST_REG_UNEQUAL b, 0
    TEST_REG_UNEQUAL c, 0
    TEST_REG_UNEQUAL d, 0
    TEST_REG_UNEQUAL e, 0
    TEST_REG_UNEQUAL h, 0
    TEST_REG_UNEQUAL l, 0
    TEST_DREG_UNEQUAL ix, 0
    TEST_DREG_UNEQUAL iy, 0
    exx    
    TEST_A_UNEQUAL 0
    TEST_REG_UNEQUAL b, 0
    TEST_REG_UNEQUAL c, 0
    TEST_REG_UNEQUAL d, 0
    TEST_REG_UNEQUAL e, 0
    TEST_REG_UNEQUAL h, 0
    TEST_REG_UNEQUAL l, 0
    exx
    ret 

    ENDMODULE

