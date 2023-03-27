;===========================================================================
; altrom.asm
;
; Code to modify the alternative ROM.
;===========================================================================



;===========================================================================
; Copies the ROM to AltROM and modifies
; 8 bytes at address 0 and 14 bytes at address 66h.
; As the ROM banks (0xFF) can't be paged to other slots than 0 and 1
; the contents is first copied to SWAP_SLOT/B, then the altrom is paged in
; and the SWAP_SLOT contents is copied to slot 0/1.
;===========================================================================
copy_altrom:
    nextreg REG_MEMORY_MAPPING,011b ; ROM3 = 48k Basic
    jp copy_modify_altrom


;===========================================================================
; Copies the ROM to AltROM and modifies
; 8 bytes at address 0 and 14 bytes at address 66h.
; Multiface is not allowed to be enabled here.
;===========================================================================
copy_modify_altrom:
    ; Disable ALTROM
    nextreg REG_ALTROM,0
    ; Copy ROM to SWAP_SLOT
    nextreg REG_MMU+SWAP_SLOT,TMP_BANK
    nextreg REG_MMU,ROM_BANK
    MEMCOPY SWAP_ADDR, 0x0000, 0x2000
    nextreg REG_MMU+SWAP_SLOT,TMP_BANKB
    nextreg REG_MMU+1,ROM_BANK
    MEMCOPY SWAP_ADDR, 0x2000, 0x2000
    ; Restore MAIN_BANK
    ;nextreg REG_MMU,MAIN_BANK
    ; Modify
    nextreg REG_MMU+MAIN_SLOT,MAIN_BANK
    nextreg REG_MMU+SWAP_SLOT,TMP_BANK
    ld a,ROM_BANK
    call modify_bank
    ; Enable AltRom and make it writable
    nextreg REG_ALTROM,11000000b
    nextreg REG_MMU,ROM_BANK
    nextreg REG_MMU+1,ROM_BANK
    ; Copy modified ROM in SWAP_SLOT to AltROM:
    nextreg REG_MMU+SWAP_SLOT,TMP_BANK
    MEMCOPY 0x0000, SWAP_ADDR, 0x2000
    MEMCLEAR SWAP_ADDR, 0x2000  ; Clear src
    nextreg REG_MMU+SWAP_SLOT,TMP_BANKB
    MEMCOPY 0x2000, SWAP_ADDR, 0x2000
    MEMCLEAR SWAP_ADDR, 0x2000  ; Clear src
    ; Enable AltRom
    nextreg REG_ALTROM,10000000b
    ret

;===========================================================================
; Modifies the
; 8 bytes at address 0 and 14 bytes at address 66h
; of the bank at 0xC000.
; Parameters:
;   A = bank number to write into the bank.
; Changes:
;  HL, DE, BC
;===========================================================================
modify_bank:
     ; Overwrite the address 0 and 66h with code
    MEMCOPY SWAP_ADDR, copy_rom_start_0000h_code, copy_rom_start_0000h_code_end-copy_rom_start_0000h_code

    MEMCOPY SWAP_ADDR+copy_rom_start_0066h_code, MAIN_ADDR+copy_rom_start_0066h_code, copy_rom_start_0066h_code_end-copy_rom_start_0066h_code

    ; Save the bank number inside the bank (self modifying code)
    ld (SWAP_ADDR+dbg_enter.bank),a
	ret

