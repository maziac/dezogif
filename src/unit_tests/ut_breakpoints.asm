;========================================================
; ut_breakpoints.asm
;
; Unit tests for testing the breakpoints.
;========================================================


    MODULE ut_breakpoints

; Test value
;breakpoint_test_address:	defb  0


; Test first entry.
UT_get_free_breakpoint.UT_simple:
    ; Init

	; Test memory

    ret 


; Test a few entries.
UT_get_free_breakpoint.UT_few_entries:
    ; Init
    ret 


; Test too many entries.
UT_get_free_breakpoint.UT_too_many_entries:
    ; Init
    ret 





; Test no breakpoint.
UT_find_breakpoint.UT_simple:
    ; Init
	
    ret 


; Test to find the bp at the first location.
UT_find_breakpoint.UT_find_first_entry:
    ; Init
    ret 


; Test to find the bp at some location.
UT_find_breakpoint.UT_some_entry:
    ; Init
    ret 

; Test to find the bp at teh last location.
UT_find_breakpoint.UT_last_entry:
    ; Init
    ret 



    ENDMODULE
    