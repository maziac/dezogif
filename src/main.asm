;===========================================================================
; main.asm
;===========================================================================

    DEVICE ZXSPECTRUMNEXT

; The 8k memory bank to store the code to.
USED_MAIN_BANK:  EQU 95  ; Last 8k bank on unexpanded ZXNext
USED_SLOT:  EQU 1   ; 0x2000

USED_ROM_BANK:  EQU 94  ; Bank used to copy the ROM (0x0000) to and change the RST 0 address into a jump.


    MMU USED_SLOT e, USED_MAIN_BANK ; e -> Everything should fit inot one page, error if not.
    ORG USED_SLOT*0x2000


;===========================================================================
; Include modules
;===========================================================================

    include "zxnext/zxnext_regs.inc"
    include "utilities.asm"
    include "uart.asm"
    include "message.asm"
    include "commands.asm"
    include "backup.asm"

    
;===========================================================================
; Constants
;===========================================================================


    

;===========================================================================
; Data. 
;===========================================================================



;===========================================================================
; main routine - the code execution starts here.
;===========================================================================
main:
    ; Disable interrupts
    di
 
    ; Setup stack
    ld sp,stack_top

    ; Backup slot 6
    ld a,REG_MMU+6
    call read_tbblue_reg    ; returns the bank in A

    ; Switch in the bank at 0xC000
    nextreg REG_MMU+6,USED_ROM_BANK
    ; Copy the ROM at 0x0000 to bank USED_ROM_BANK
    ld bc,0x2000
    ld hl,0x0000
    ld de,0xC000
    ldir

    ; Overwrite the RST 0 address with a jump
    ld hl,0xC000
    ldi (hl),0xC3   ; JP
    ldi (hl),LOW enter_breakpoint
    ld (hl),HIGH enter_breakpoint

    ; Restore slot 6 bank
    nextreg REG_MMU+6,a

    ; Page in copied ROM bank to slot 0
    nextreg REG_MMU+0,USED_ROM_BANK


    ; Enable interrupts
    ;ei

    ld a,6
    out (BORDER),a

  IF 0
    ; Set baudrate
    call set_uart_baudrate
  ENDIF

    ; Init
    call clear_rx_buffer
    
main_loop:
    ; Check if byte available.
    call dbg_check_for_message

    inc a
    out (BORDER),a

    ; Some code
    ld bc,0xb1c1
    ld de,0xd1e1

    jr main_loop



;===========================================================================
; Called by RST 0.
; I.e. thispoint is reached when the program runs into a RST 0.
; I.e. this indicates that a breakpoint was hit.
; The location just after the breakpoint can be found from the SP.
; I.e. it was pushed on stack because of the RST.
;===========================================================================
enter_breakpoint:
    ret


;===========================================================================
; Stack. 
;===========================================================================

; Stack: this area is reserved for the stack
STACK_SIZE: equ 100    ; in words


; Reserve stack space
    defw 0  ; WPMEM, 2
stack_bottom:
    defs    STACK_SIZE*2, 0
stack_top:  
    defw 0  ; WPMEM, 2





;===========================================================================
; After loading the program starts here. Moves the bank to the destination 
; slot and jumps there.
;===========================================================================
    ORG 0xC000 
start_entry_point:
    ; At startup this program is mapped at 0xC000
    di
    ; Switch in the bank at 0x4000
    nextreg REG_MMU+USED_SLOT,USED_MAIN_BANK
    ; Now the right bank is mapped into the slot, jump to the slot and continue
    jp main


    ; Save NEX file
    SAVENEX OPEN BIN_FILE, start_entry_point, stack_top // 0xC000    //stack_top: CSpect has a problem (crashes the program immediately when it is run) is stack points to stack_top which is inside the 
    SAVENEX CORE 2, 0, 0        ; Next core 2.0.0 required as minimum
    ;SAVENEX CFG 0               ; black border
    ;SAVENEX BAR 0, 0            ; no load bar
    SAVENEX AUTO
    ;SAVENEX BANK 20
    SAVENEX CLOSE
