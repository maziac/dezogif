
; Function numbers (after RST $08)
F_OPEN:    equ $9a
F_CLOSE:   equ $9b
F_READ:    equ $9d
F_WRITE:   equ $9e

; Opening modes (Register B with F_OPEN)
FA_READ:   equ $01
FA_WRITE:  equ $02
FA_CREATE: equ $08
