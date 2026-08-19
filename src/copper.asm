;===========================================================================
; copper.asm
;
; Contains the copper functionality.===========================================================================

	MODULE copper

;===========================================================================
; Installs the two-instruction Copper list that raises a Multiface NMI once per
; frame - the clock the break poll rides on, and therefore the whole of
; async break.
;
;   WAIT line,0    = 0x8000 | (hpos<<9) | line
;   MOVE $02,$08   = (reg<<8) | value   -> NR 0x02 bit 3, the Multiface NMI
;
; Encoding from device/copper.vhd:91-104.
;
; WHY THE DEBUGGER MAY INSTALL THIS AT ALL. The Copper's instruction list is
; WRITE-ONLY - both instruction RAMs discard their CPU-side read output
; (zxnext.vhd:3959-3976, :3980-3998) and NR 0x60/0x63 have no read decode
; (:6286-6287) - so whatever is installed here can never be given back. What
; makes it acceptable is WHEN: the only caller is cmd_init, which runs as a
; debug client opens a session, BEFORE it has pushed the program's banks and
; long before the program has run. There is nothing there yet to destroy. A
; program that uses the Copper installs its own list when it runs, overwriting
; this one - so it keeps its raster effects and carries the two instructions
; itself, as the user documentation describes.
;
; Changes:
;   AF, BC
;===========================================================================
break_install:
    ; NR 0x06 bit 3 gates EVERY Multiface NMI source and its power-on value is
    ; 0. NextZXOS leaves it set, so this is insurance rather than setup - but a
    ; program that had cleared it would otherwise kill the break silently, and
    ; nothing else here would ever put it back.
    call mf_nmi_enable

    ; Stop the Copper and put its write pointer at index 0.
    nextreg REG_COPPER_CONTROL_H,RCCH_COPPER_STOP
    nextreg REG_COPPER_CONTROL_L,0

    ; The list, MSB first.
    nextreg REG_COPPER_DATA,HIGH (0x8000+COPPER_BREAK_LINE)
    nextreg REG_COPPER_DATA,LOW (0x8000+COPPER_BREAK_LINE)
    nextreg REG_COPPER_DATA,REG_RESET
    nextreg REG_COPPER_DATA,00001000b

    ; Run from index 0, looping. The mode CHANGING to 01 is what resets the
    ; pointer (device/copper.vhd:69-78), which the stop above guarantees.
    nextreg REG_COPPER_CONTROL_H,RCCH_COPPER_RUN_LOOP_RESET
    ret


;===========================================================================
; Stops the Copper outright.
;
; Note what this does NOT do: remove our two instructions. The list cannot be
; read, so it cannot be edited - stopping the Copper is the only "off" there is,
; and it stops the debugged program's OWN list too if it installed one.
;
; Changes:
;   -
;===========================================================================
	MACRO COPPER_BREAK_STOP
	nextreg REG_COPPER_CONTROL_H,RCCH_COPPER_STOP
	ENDM


	ENDMODULE
