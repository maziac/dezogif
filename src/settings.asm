;===========================================================================
; settings.asm
;
; The settings management.
; Reading and writing settings to a file.
;===========================================================================


;===========================================================================
; Save the settings (Async Break and Border flashing) to a file.
; Returns:
; C: File/write error
; NC: no error
;===========================================================================
save_settings:
    ld b,FA_WRITE | FA_CREATE
    ld a,'$'  ; System drive
    ld ix,SETTINGS_FILE_PATH
    rst $08
    defb F_OPEN
    ret c      ; Carry = Error, (A = Errorcode)

    ; A is file handle
    push af         ; Remember the file handle

    ld ix,settings_data         ; Pointer to settings data
    ld bc,settings_data.end-settings_data ; Count of bytes
    rst $08
    defb F_WRITE
    ret c      ; Carry = Error, (A = Errorcode)

    pop af          ; Retrieve file handle
    rst $08
    defb F_CLOSE
    ret        ; Carry = Error, (A = Errorcode)


;===========================================================================
; Opens the settings file for reading.
; Returns:
; C: error
; NC: no error
;===========================================================================
load_open:
    ld b, FA_READ
    ld a,'$'  ; System drive
    ld ix,SETTINGS_FILE_PATH
    rst $08
    defb F_OPEN
	ret

;===========================================================================
; Load the settings from a file.
;===========================================================================
load_settings:
    ; A is file handle
    push af         ; Remember the file handle

    ld ix,settings_data         ; Pointer to settings data
    ld bc,settings_data.end-settings_data ; Count of bytes
    rst $08
    defb F_READ
    jr c,.read_error      ; Carry = Error, (A = Errorcode)

    pop af          ; Retrieve file handle
    rst $08
    defb F_CLOSE
    ret nc   ; Return if no error occurred

    ; Flow through

.read_error:
    ; Error
    ld a,ERROR_FILE_READ
    jp drain_main
