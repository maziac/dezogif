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
    ; Copy program also to bank 1 to survive the MEMORY_PAGING_CONTROL
    nextreg REG_MMU+SWAP_SLOT,1
    MEMCOPY SWAP_ADDR, MAIN_ADDR, 0x2000   
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
; Does it for both, the 48K ROM and the 128K ROM.
; Multiface is not allowed to be enabled here.
;===========================================================================
copy_modify_altrom:
    ; 128k or 48K ROM
    ld bc,MEMORY_PAGING_CONTROL ; Switches also to bank 1
    out (c),a

    ; Disable ALTROM
    nextreg REG_ALTROM,0
    ; Copy ROM
    nextreg REG_MMU+SWAP_SLOT,TMP_BANK
    nextreg REG_MMU,ROM_BANK
    MEMCOPY SWAP_ADDR, 0x0000, 0x2000
    nextreg REG_MMU+SWAP_SLOT,TMP_BANKB
    nextreg REG_MMU+1,ROM_BANK
    MEMCOPY SWAP_ADDR, 0x2000, 0x2000
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
    MEMCOPY 0x0000, SWAP_ADDR, 0x2000
    nextreg REG_MMU+SWAP_SLOT,TMP_BANKB
    MEMCOPY 0x2000, SWAP_ADDR, 0x2000
    nextreg REG_ALTROM,10000000b

    ; Switch back debugger code in used bank
    nextreg REG_MMU,MAIN_BANK
    ret


