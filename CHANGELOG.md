# Changelog

# 2.2.0
- Fixed a buffer overflow if a long write_mem was called after cmd_init.
- Fixed: on intitalization too much memory was copied.
- Temp banks now cleared after initialization.
- cmd_init now initializes the slots.
- Changed to DZRP 2.1.0.

# 2.1.0
- Support for Core 03.01.10.
- No support for Core 03.01.05, use 2.0.0 instead.
- Removed superfluous code for calling functions from the debugged program though RST 0.
- NMI stackless mode (and non stackless mode) supported.
- Use of next register 11 to set the IO mode for the joyports.
- Display of Core version.

## 2.0.0
- Changed to DZRP 2.0.0.

## 1.0.0
- Released.

## 0.14.1
- Optimized Rx timing.
- Border colors disabled after loading.
- With "B" the slowly changing border color can be turned on/off.
- "0" changed to "R" for reset now.
- Prints out video timings.

## 0.14.0
- Version for beta testing.

## 0.13.1
- New error output if trying to overwrite MAIN_BANK.
- IM is returned as 0xFF.

## 0.13.0
- Removed command for dezog_poll.

## 0.12.0
- enNextMf.rom version: M1/NMI working now to PAUSE the debugged program.

## 0.11.0
- Moved main functionality to slot 7 to allow correct read of slot 0 if set to ROM (ROM is only visible correctly in slot 0/1).
- Error output on main screen.

## 0.10.0
- Interoperable with Layer 2 read/write.
- M1/NMI disabled/re-enabled.

## 0.9.1
- Key "0" to reset.
- Moved debug code from address 0x0000 to 0x0066.
- Extended interface to debugged program to init bank at slot 0.

## 0.9.0
- Use of DZRP 1.6.0: Support of CMD_CLOSE.

## 0.8.0
- Use of DZRP 1.5.0: Support of loop back test.

## 0.7.0
- DivMMC removed. ROM used instead.

## 0.6.0
- DivMMC used.

## 0.5.0
- DZRP 1.3.0:
	- Breakpoint commands: CM_SET_BREAKPOINTS and CMD_RESTORE_MEM implemented.

## 0.4.0
- Changed SW breakpoints: more logic moved to DeZog.
- Temporary breakpoints implemented.

## 0.3.3
- SW breakpoints working again.
- Changed to DZRP 1.2.0.
