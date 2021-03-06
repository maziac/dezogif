;=======================================================================
; ZX Next specific constants, registers and ports.
;=======================================================================



; Next Feature Control Registers.

; Register number. Write-only.
IO_NEXTREG_REG:	equ	0x243B

; Register value. Read or write.
IO_NEXTREG_DAT:	equ	0x253B

; Layer 2
LAYER_2_PORT:	equ 0x123B

; Plus 3 Memory Paging Control
PLUS_3_MEMORY_PAGING_CONTROL:	equ 0x1FFD

; Memory Paging Control
MEMORY_PAGING_CONTROL:	equ 0x7FFD

; Next Memory Bank Select
NEXT_MEMORY_BANK_SELECT:	equ 0xDFFD

; SpecDrum DAC Output
SPECDRUM_DAC_OUTPUT:    equ 0x00DF  ; High byte does not matter.

; Kempston Joystick 2 and UART
KEMPSTON_JOY_2:		equ	0x37


REG_MACHINE_ID:	equ	0
RMI_DE1A:	equ	1
RMI_DE2A:	equ	2
RMI_FBLABS:	equ	5
RMI_VTRUCCO:	equ	6
RMI_WXEDA:	equ	7
RMI_EMULATORS:	equ	8
RMI_ZXNEXT:	equ	10
RMI_MULTICORE:	equ	11
RMI_ZXNEXT_AB:	equ	250

REG_VERSION:	equ	1
RV_MAJOR:	equ	0xf0
RV_MINOR:	equ	0x0f

REG_RESET:	equ	2
RR_POWER_ON_RESET:	equ	0x04
RR_HARD_RESET:	equ	0x02
RR_SOFT_RESET:	equ	0x01

REG_MACHINE_TYPE:	equ	3
RMT_LOCK_TIMING:	equ	0x80
RMT_TIMING_48:	equ	0x10
RMT_TIMING_128:	equ	0x20
RMT_TIMING_P3E:	equ	0x30
RMT_TIMING_PENTAGON:	equ	0x40
RMT_CONFIG_MODE:	equ	0x00
RMT_48:	equ	0x01
RMT_128:	equ	0x02
RMT_P3E:	equ	0x03
RMT_PENTAGON:	equ	0x04

REG_RAM_PAGE:	equ	4
RRP_RAM_DIVMMC:	equ	0x08
RRP_ROM_DIVMMC:	equ	0x04
RRP_ROM_MF:	equ	0x05
RRP_ROM_SPECTRUM:	equ	0x00

REG_PERIPHERAL_1:	equ	5
RP1_JOY1_SINCLAIR:	equ	0x00
RP1_JOY1_KEMPSTON:	equ	0x40
RP1_JOY1_CURSOR:	equ	0x80
RP1_JOY2_SINCLAIR:	equ	0x00
RP1_JOY2_KEMPSTON:	equ	0x10
RP1_JOY2_CURSOR:	equ	0x20
RP1_RATE_50:	equ	0x00
RP1_RATE_60:	equ	0x04
RP1_ENABLE_SCANLINES:	equ	0x02
RP1_ENABLE_SCANDOUBLER:	equ	0x01

REG_PERIPHERAL_2:	equ	6
RP2_ENABLE_TURBO:	equ	0x80
RP2_DAC_I2S:	equ	0x00
RP2_DAC_JAP:	equ	0x40
RP2_ENABLE_LIGHTPEN:	equ	0x20
RP2_ENABLE_DIVMMC:	equ	0x10
RP2_ENABLE_MULTIFACE:	equ	0x08
RP2_PS2_KEYBOARD:	equ	0x00
RP2_PS2_MOUSE:	equ	0x04
RP2_PSGMODE_AY:	equ	0x03
RP2_PSGMODE_YM:	equ	0x02
RP2_PSGMODE_DISABLE:	equ	0x00

REG_TURBO_MODE:	equ	7
RTM_3MHZ:	equ	0x00
RTM_7MHZ:	equ	0x01
RTM_14MHZ:	equ	0x02
RTM_28MHZ:	equ	0x03

REG_PERIPHERAL_3:	equ	8
RP3_STEREO_ABC:	equ	0x00
RP3_STEREO_ACB:	equ	0x20
RP3_ENABLE_SPEAKER:	equ	0x10
RP3_ENABLE_SPECDRUM:	equ	0x08
RP3_ENABLE_COVOX:	equ	0x08
RP3_ENABLE_TIMEX:	equ	0x04
RP3_ENABLE_TURBOSOUND:	equ	0x02
RP3_UNLOCK_7FFD:	equ	0x80
RP3_DISABLE_RAM_CONTENTION:	equ 0x40


REG_PERIPHERAL_4:	equ	9
RP4_AY2_MONO:       equ	0x80
RP4_AY1_MONO:       equ	0x40
RP4_AY0_MONO:       equ	0x20
RP4_SPRITE_ID_LOCK_STEP:    equ	0x10
RP4_DISABLE_KEMPSTON_PORT:  equ	0x08
RP4_DISABLE_DIVMMC_PORT:    equ	0x04
RP4_SCANLINES_OFF:     equ	0x00
RP4_SCANLINES_75:     equ	0x01
RP4_SCANLINES_50:     equ	0x10
RP4_SCANLINES_25:     equ	0x11


REG_SUB_VERSION:	equ	14

REG_VIDEO_PARAM:	equ	15

REG_ANTI_BRICK:	equ	16
RAB_COMMAND_NORMALCORE:	equ	0x80
RAB_BUTTON_DIVMMC:	equ	0x02
RAB_BUTTON_MULTIFACE:	equ	0x01

REG_VIDEO_TIMING:	equ	17

REG_LAYER_2_RAM_PAGE:	equ	18
RL2RP_MASK:	equ	0x3f
REG_LAYER_2_RAM_BANK:	equ	18
RL2RB_MASK:	equ	0x3f

REG_LAYER_2_SHADOW_RAM_PAGE:	equ	19
RL2SRP_MASK:	equ	0x3f
REG_LAYER_2_SHADOW_RAM_BANK:	equ	19
RL2SRB_MASK:	equ	0x3f

REG_GLOBAL_TRANSPARENCY_COLOR:	equ	20

REG_SPRITE_LAYER_SYSTEM:	equ	21
RSLS_ENABLE_LORES:	equ	0x80
RSLS_LAYER_PRIORITY_SLU:	equ	0x00
RSLS_LAYER_PRIORITY_LSU:	equ	0x04
RSLS_LAYER_PRIORITY_SUL:	equ	0x08
RSLS_LAYER_PRIORITY_LUS:	equ	0x0c
RSLS_LAYER_PRIORITY_USL:	equ	0x10
RSLS_LAYER_PRIORITY_ULS:	equ	0x14
RSLS_SPRITES_OVER_BORDER:	equ	0x02
RSLS_SPRITES_VISIBLE:	equ	0x01

REG_LAYER_2_OFFSET_X:	equ	22

REG_LAYER_2_OFFSET_Y:	equ	23

REG_CLIP_WINDOW_LAYER_2:	equ	24

REG_CLIP_WINDOW_SPRITES:	equ	25

REG_CLIP_WINDOW_ULA:	equ	26

REG_CLIP_WINDOW_CONTROL:	equ	28
RCWC_RESET_ULA_CLIP_INDEX:	equ	0x04
RCWC_RESET_SPRITE_CLIP_INDEX:	equ	0x02
RCWC_RESET_LAYER_2_CLIP_INDEX:	equ	0x01

REG_ACTIVE_VIDEO_LINE_H:	equ	30

REG_ACTIVE_VIDEO_LINE_L:	equ	31

REG_LINE_INTERRUPT_CONTROL:	equ	34
RLIC_INTERRUPT_FLAG:	equ	0x80
RLIC_DISABLE_ULA_INTERRUPT:	equ	0x04
RLIC_ENABLE_LINE_INTERRUPT:	equ	0x02
RLIC_LINE_INTERRUPT_VALUE_H:	equ	0x01

REG_LINE_INTERRUPT_VALUE_L:	equ	35

REG_ULA_X_OFFSET:		equ 38
REG_ULA_Y_OFFSET:		equ 39

REG_KEYMAP_ADDRESS_H:	equ	40

REG_KEYMAP_ADDRESS_L:	equ	41

REG_KEYMAP_DATA_H:	equ	42

REG_KEYMAP_DATA_L:	equ	43

REG_DAC_MONO:	equ	45

REG_LORES_OFFSET_X:	equ	50

REG_LORES_OFFSET_Y:	equ	51

REG_PALETTE_INDEX:	equ	64

REG_PALETTE_VALUE_8:	equ	65

REG_ULANEXT_PALETTE_FORMAT:	equ	66

REG_PALETTE_CONTROL:	equ	67
RPC_DISABLE_AUTOINC:	equ	0x80
RPC_SELECT_ULA_PALETTE_0:	equ	0x00
RPC_SELECT_ULA_PALETTE_1:	equ	0x40
RPC_SELECT_LAYER_2_PALETTE_0:	equ	0x10
RPC_SELECT_LAYER_2_PALETTE_1:	equ	0x50
RPC_SELECT_SPRITES_PALETTE_0:	equ	0x20
RPC_SELECT_SPRITES_PALETTE_1:	equ	0x60
RPC_ENABLE_SPRITES_PALETTE_0:	equ	0x00
RPC_ENABLE_SPRITES_PALETTE_1:	equ	0x08
RPC_ENABLE_LAYER_2_PALETTE_0:	equ	0x00
RPC_ENABLE_LAYER_2_PALETTE_1:	equ	0x04
RPC_ENABLE_ULA_PALETTE_0:	equ	0x00
RPC_ENABLE_ULA_PALETTE_1:	equ	0x02
RPC_ENABLE_ULANEXT:	equ	0x01

REG_PALETTE_VALUE_16:	equ	68

REG_FALLBACK_COLOR:	equ	74

; First of the 8 MMU slot registers
REG_MMU:	equ 0x50  ; = 80

ROM_BANK:	equ 0xFF

MMU4_DEFAULT_BANK:	equ 4


REG_COPPER_DATA:	equ	96

REG_COPPER_CONTROL_L:	equ	97

REG_COPPER_CONTROL_H:	equ	98
RCCH_COPPER_STOP:	equ	0x00
RCCH_COPPER_RUN_LOOP_RESET:	equ	0x40
RCCH_COPPER_RUN_LOOP:	equ	0x80
RCCH_COPPER_RUN_VBI:	equ	0xc0

REG_ULA_CONTROL:	equ 104
REG_DISPLAY_CONTROL:	equ 105

REG_ALTROM:		equ 140

REG_MEMORY_MAPPING:		equ 142

REG_DIVMMC_TRAP_ENABLE_1:	equ 178
REG_DIVMMC_TRAP_ENABLE_2:	equ 180

REG_DEBUG:	equ	255



;-----------------------------------------------------------------------------
; Sprites.
;-----------------------------------------------------------------------------


; Maximum number of HW sprites.
MAX_HW_SPRITES: equ 64


; nextreg 75: Sprite Transparency Colour
REG_SPRITE_TRANSPARENCY_COLOR_INDEX: equ  75  ; the transparent RGB332 colour



; PORT 0x303B: Sprite Slot Selection (write only)
; Defines the sprite slot to be configured by ports 0x57 and 0x5B, and also initializes the address of the palette.
IO_SPRITE_SLOT:	equ	0x303b

; PORT 0x303B: Global Sprites Flag (read only)
; If read:
; 	Bits 7-2: Reserved, always 0.
; 	Bit 1: max sprites per line flag.
; 	Bit 0: Collision flag.
; Reading from the port resets the bits
IO_SPRITE_FLAGS:	equ	0x303b

; Sprite port-mirror Index Register. Same as IO_SPRITE_SLOT but as ZX Next register.
REG_SPRITE_SLOT:    equ 0x34


ISF_MAX_SPRITES_PER_LINE:	equ	0x02  ; set if more than 12 sprites appear on any scanline
ISF_COLLISION:	equ	0x01             ; set if non-transparent pixels of any two sprites overlap

IO_303B_MAX_SPRITES_PER_LINE:	equ	ISF_MAX_SPRITES_PER_LINE
IO_303B_COLLISION:	equ	ISF_COLLISION

; PORT 0x53: Sprite Palette (write only)
; Each sprite's 8-bit pixel value passes through this palette to generate
; a new 8-bit value.  This 8-bit value is then passed through the sprite
; RGB333 palette to produce a 9-bit colour.  The 256 bytes of this palette
; are written to this port after selecting the initial index 0-255 via
; port 0x303b.  Each write auto-increments the palette index.
IO_SPRITE_PALETTE:	equ	0x53

; PORT 0x57: Sprite Attributes (write only)
; Each of the 64 sprites are described by a four byte attribute:
;   BYTE 0 : X position (bits 7..0)
;   BYTE 1 : Y position (0-255)
;   BYTE 2 : bits 7..4 palette offset, bit 3 = X mirror, bit 2 = Y mirror, bit 1 = rotate, bit 0 = X MSB
;   BYTE 3 : bit 7 = visible, bits 5..0 pattern index (0-63)
;   BYTE 4 : bit 7 = 4 bit color, pattern index or relative/anchor.
; To write a specific sprite's attributes, write the sprite_number to the slot selection port 0x303b
; and then write the bytes to this port.  Each write auto-increments the attribute index.
IO_SPRITE_ATTRIBUTE:	equ	0x57

; Sprite port-mirror Attribute Registers.
REG_SPRITE_ATTRIBUTE_0:    equ 0x35 ; Sameas IO_SPRITE_ATTRIBUTE/Byte 0
REG_SPRITE_ATTRIBUTE_1:    equ 0x36 ; Sameas IO_SPRITE_ATTRIBUTE/Byte 1
REG_SPRITE_ATTRIBUTE_2:    equ 0x37 ; Sameas IO_SPRITE_ATTRIBUTE/Byte 2
REG_SPRITE_ATTRIBUTE_3:    equ 0x38 ; Sameas IO_SPRITE_ATTRIBUTE/Byte 3
REG_SPRITE_ATTRIBUTE_4:    equ 0x39 ; Sameas IO_SPRITE_ATTRIBUTE/Byte 4

; Increment sprite slot index. If this is ORed to one of the REG_SPRITE_ATTRIBUTE_N above the slot index will be incremented additionally.
SPRITE_INC_SLOT:    equ 0x40


; PORT 0x5B: Sprite Patterns (write only)
; Up to 64 sprite patterns can exist, with each pattern 16x16 pixels in size.  Each pixel
; is 8-bits so each each sprite pattern occupies 256 bytes.  To change a sprite pattern,
; first write the pattern id 0-63 to the slot selection port 0x303b and then write the bytes
; to this port.  Each write auto-increments the pattern index.
IO_SPRITE_PATTERN:	equ	0x5b



;-----------------------------------------------------------------------------
; DMA.
;-----------------------------------------------------------------------------
DMA_DISABLE:    equ 0x83
DMA_ENABLE:     equ 0x87
DMA_LOAD:       equ 11001111b
ZXN_DMA_PORT:   equ 0x6b



;-----------------------------------------------------------------------------
; MMU.
;-----------------------------------------------------------------------------

; 8K slots. Use in confunction with REG_MMU, e.g. REG_MMU+MMU_SLOT_4000_5FFF.
; Can alos be used alone for sjasmplus "MMU" directive.
SLOT_0000_1FFF:	equ 0
SLOT_2000_3FFF:	equ 1
SLOT_4000_5FFF:	equ 2
SLOT_6000_7FFF:	equ 3
SLOT_8000_9FFF:	equ 4
SLOT_A000_BFFF:	equ 5
SLOT_C000_DFFF:	equ 6
SLOT_E000_FFFF:	equ 7


; 8k Memory banks 
MMU_BANK:	equ 0 ; Start bank
