;===========================================================================
; prequel.asm
; Code that is executed in RAM before the main program (in ROM area)
; is started.
; It mainly prints the informational text.
;===========================================================================




;===========================================================================
; After loading the program starts here. Moves the bank to the destination 
; slot and jumps there.
;===========================================================================
start_entry_point:
    ; At startup this program is mapped at 0xA000
    di
    ld sp,stack_prequel.top

    ;jp divmmc_init

	; Maximize clock speed
	nextreg REG_TURBO_MODE,RTM_28MHZ

    ; Reset layer 2 writing/reading
    ld bc,LAYER_2_PORT
    xor a
    out (c),a

    ; Switch in ROM bank
    nextreg REG_MMU+0,ROM_BANK
    nextreg REG_MMU+1,ROM_BANK

 IF 0
    ld sp,stack_prequel.top

    ; Clear screen
	ld iy,VAR_ERRNR
    ;call ROM_CLS
    
    ; Print text    
    ld hl,INTRO_TEXT
	call print
 ENDIF


 IF 0   ; DIVMMC
    ; The main program has been loaded into LOADED_BANK and needs to be copied to DivMMC.

    ; Switch in loaded bank at SWAP_SLOT (0xE000)
    nextreg REG_MMU+SWAP_SLOT,LOADED_BANK

    ; TODO: Read and set only required bits.
    ; Bit 4: Enable DivMMC automap and DivMMC NMI by DRIVE button (0 after Hard-reset)
    ; Bit 3: Enable multiface NMI by M1 button (hard reset = 0)
    nextreg REG_PERIPHERAL_2,%10110001

    ; Enable DivMMC traps at 0x0000 and 0x0066
    nextreg REG_DIVMMC_TRAP_ENABLE_1, 0b00000001    ; 0x0000
    nextreg REG_DIVMMC_TRAP_ENABLE_2, 0b00000001    ; 0x0066 

    ; Page in Divmmc memory bank 3
    ; Bit 7: conmem
    ; Bit 6: mapram
    ; Bit 0/1: bank
    ld a,%10000011
    out (DIVIDE_CTRL_REG),a

    ; Copy loaded bank to DivMMC bank 3 (0x2000)
    MEMCOPY 0x2000, SWAP_SLOT*0x2000, 0x2000 

    ; Enable mapram, RAM bank 0 is at 0x2000
    ld a,%01000000
    out (DIVIDE_CTRL_REG),a
 ELSE 

    ; The main program has been loaded into LOADED_BANK and needs to be copied to USED_MAIN_BANK
    ; Switch in the bank at 0x0000
    nextreg REG_MMU+MAIN_SLOT,MAIN_BANK
    ; Switch in loaded bank at 0xC000
    nextreg REG_MMU+SWAP_SLOT,LOADED_BANK
    ; Copy the code
    MEMCOPY MAIN_SLOT*0x2000, SWAP_SLOT*0x2000, 0x2000   

 ENDIF


    ; Initialization.
    ; Setup stack
    ld sp,debug_stack.top
 IF 0   ; DIVMMC
    ; Without DivMMC we need RAM at 0x2000
    nextreg REG_MMU+USED_DATA_SLOT, USED_DATA_BANK
 ENDIF

    ; Init state
    MEMCLEAR tmp_breakpoint_1, 2*TMP_BREAKPOINT

    ; Backup SWAP_SLOT bank
    ld a,REG_MMU+SWAP_SLOT
    call read_tbblue_reg    ; returns the bank in A

    ; Switch in the bank at 0x0000
    nextreg REG_MMU+MAIN_SLOT,MAIN_BANK

    ; Initialize the bank for slot 0 with the required code.
    ;ld a,USED_ROM0_BANK
    ;call execute_init_slot0_bank.inner
    call copy_altrom

    ; Copy the ZX character font from address ROM_FONT (0x3D00)
    ; to the debugger area at the end of the bank (0x2000-ROM_FONT_SIZE).
    MEMCOPY (MAIN_SLOT+1)*0x2000-ROM_FONT_SIZE, ROM_FONT, ROM_FONT_SIZE

    ; Restore SWAP_SLOT bank
    nextreg REG_MMU+SWAP_SLOT,a

    ; Set baudrate
    call set_uart_baudrate

    ; Init text printing
    call text.init

    ; The main program has been copied into USED_MAIN_BANK
    ld a,2  ; Joy 2 selected
    ld (uart_joyport_selection),a
    xor a
    ld (last_error),a
    

    ; TODO :Remove
	ld a,REG_PERIPHERAL_2
	call read_tbblue_reg
	or 00001000b	; Enable MF NMI
	nextreg REG_PERIPHERAL_2,a

    jp main
    



; The preliminary stack
stack_prequel:
	defs 2*20
.top



;===========================================================================
; Copies the ROM to AltROM and modifies 
; 8 bytes at address 0 and 14 bytes at address 66h.
; As the ROM banks (0xFF) can't be paged to other slots than 0 and 1
; the contents is first copied to SWAP_SLOT/B, then the altrom is paged in
; and the SWAP_SLOT contents is copied to slot 0/1.
;===========================================================================
copy_altrom:
 IF 0
    ; Test code
    nextreg REG_ALTROM,00000000b
    nextreg REG_MMU,ROM_BANK
    nextreg REG_ALTROM,11000000b
    ld hl,0
    ld (hl),0xAA    ; AA to AltROM

    nextreg REG_ALTROM,10000000b
    nextreg REG_ALTROM,00000000b
    nextreg REG_ALTROM,10000000b
    nextreg REG_ALTROM,00000000b
 ENDIF

    ; First 128K ROM
    ld a,0
    call copy_modify_altrom
    ; Then 48K ROM
    ld a,00010000b
    call copy_modify_altrom
    ret


;===========================================================================
; Copies the ROM to AltROM and modifies 
; 8 bytes at address 0 and 14 bytes at address 66h.
; Does ti for both, the 48K ROM and the 128K ROM.
;===========================================================================
copy_modify_altrom:
    ; 128k or 48K ROM
    ld bc,MEMORY_PAGING_CONTROL
    out (c),a

 IF 0
.loop
    ld a,0
    out (c),a
    ld a,00010000b
    out (c),a
    jr .loop
 ENDIF

    ; Disable ALTROM
    nextreg REG_ALTROM,0
    ; Copy ROM
    nextreg REG_MMU+SWAP_SLOT,TMP_BANK
    nextreg REG_MMU,ROM_BANK
    MEMCOPY SWAP_SLOT*0x2000, 0x0000, 0x2000
    nextreg REG_MMU+SWAP_SLOT,TMP_BANKB
    nextreg REG_MMU+1,ROM_BANK
    MEMCOPY SWAP_SLOT*0x2000, 0x2000, 0x4000
    ; Restore MAIN_BANK
    nextreg REG_MMU,MAIN_BANK
    ; Modify
    nextreg REG_MMU+MAIN_SLOT,MAIN_BANK
    nextreg REG_MMU+SWAP_SLOT,TMP_BANK
    ld a,ROM_BANK
    call modify_bank
    ; Copy to AltROM: Enable AltRom and make it writable
    nextreg REG_MMU,ROM_BANK
    nextreg REG_MMU+1,ROM_BANK
    nextreg REG_ALTROM,11000000b
    nextreg REG_MMU+SWAP_SLOT,TMP_BANK
    MEMCOPY 0x0000, SWAP_SLOT*0x2000, 0x2000
    nextreg REG_MMU+SWAP_SLOT,TMP_BANKB
    MEMCOPY 0x2000, SWAP_SLOT*0x2000, 0x2000
    nextreg REG_ALTROM,10000000b

 IF 0
    ; For testing
    nextreg REG_ALTROM,00000000b
    nextreg REG_ALTROM,10000000b
    nextreg REG_ALTROM,00000000b
    nextreg REG_ALTROM,10000000b
    nextreg REG_ALTROM,00000000b
    nextreg REG_ALTROM,10000000b
 ENDIF
        
    ; Switch back debugger code in used bank
    nextreg REG_MMU,MAIN_BANK
    ret



; The code below is from Matt Davies to catch the DRIVE button press with DivMMC.
; Still unsolved is how to detect multiple presses.
; I.e. this works only once. Most probably it need to be reset somehow.
divmmc_init:
    di
    
    ld sp,0x9000

    ld a,CYAN
    out (BORDER),a

    ;jr $

    nextreg REG_MMU, 60
    ld hl,0x0000
    ldi (hl),0   ; NOP
    ldi (hl),0   ; NOP
    ldi (hl),0   ; NOP
    ldi (hl),0xC9   ; RET
    ldi (hl),0xC9   ; RET
    ldi (hl),0x55
    ldi (hl),0x55
    ldi (hl),0x55

    ; Set border
    ld a,BLUE
    out (BORDER),a
    
    ; Bit 4: Enable DivMMC automap and DivMMC NMI by DRIVE button (0 after Hard-reset)
    ; Bit 3: Enable multiface NMI by M1 button (hard reset = 0)
    nextreg REG_PERIPHERAL_2,%10110001

    ; Page in Divmmc memory bank 3
    ; Bit 7: conmem
    ; Bit 6: mapram
    ; Bit 0/1: bank
    ld      a,%10000011
    out     ($e3),a

    ; Copy esxDos to DivMMC bank 3
    ld      hl,0
    ld      de,$2000
    ld      bc,$2000
    ldir

    ; Patch NMI routine
    ld      hl,RomPatch
    ld      de,$2066
    ld      bc,RomPatchLen
    ldir


    ld hl,0x2000
    ldi (hl),0xC9   ; RET
    ldi (hl),0xC9   ; RET
    ldi (hl),0xAA
    ldi (hl),0xAA
    ldi (hl),0xAA
    ldi (hl),0xAA

    ; Enable mapram
    ld      a,%01000000
    out     ($e3),a

    call 0x0000

    ld a,[0x0002]
    cp 0xAA
    ld a,GREEN
    jr z,.ok
    ld a,RED ; Error
.ok:
    out (BORDER),a

    jr      $


TestRoutine:
    ld a,YELLOW
    out (BORDER),a


    ld a,[0x0000]
    cp 0xAA
    ld a,GREEN
    jr z,.ok
    ld a,CYAN ; Error
.ok:
    out (BORDER),a

    jr $

    inc a
    and 7
    out (BORDER),a
    retn 

    jr  $


RomPatch:
    nop ; PUSH AF in original ROM
    jp      TestRoutine
RomPatchLen:    equ     $-RomPatch


/*
Original:
                org $c000

Start:
                ld      a,1
                out     ($fe),a
                
                nextreg $06,%10110001

                ; Page in Divmmc memory bank 3
                ld      a,%10'000011
                out     ($e3),a

                ; Copy esxDos to bank 3
                ld      hl,0
                ld      de,$2000
                ld      bc,$2000
                ldir

                ; Patch NMI routine
                ld      hl,RomPatch
                ld      de,$2066
                ld      bc,RomPatchLen
                ldir

                ; Enable mapram
                ld      a,%01'000000
                out     ($e3),a

                jr      $


TestRoutine:
                ld      a,2
                out     ($fe),a
                jr      $


RomPatch:
                nop
                jp      TestRoutine
RomPatchLen     equ     $-RomPatch
*/


/*
Multiface:

garryl:
So pressing the NMI button will swap the Multiface ROM in, how can one switch back?
@Maziac Once the NMI button is pressed, paging is under software control:
IN A,($bf): pages the MF ROM/RAM out
IN A,($3f): pages the MF ROM/RAM back in
If you do an OUT ($3f),A before the IN A,($bf) then the MF is again hidden and can only be paged back by pressing the NMI button.

*/
