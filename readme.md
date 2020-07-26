# DeZog ZX Next Uart Interface

# Introduction

This is a ZXNext assembler program named 'dezogif' that communicates via the UART with a debugger on a PC.

It is intended to use this with the DeZog, a vscode debug adapter.



# Design

There are basically 2 states:
- the debugged program is running
- the debugged program is stopped

When the debugged program is running no communication takes place and the joy ports are restored for joystick usage.
When the debugged program is stopped the dezogif takes over and configures the joy port for UART communication.

This implies that it is not possible to stop the debugged program from DeZog.
to stop it you need to press the yellow NMI button.

When the NMI button was pressed dezogif send a DZRP pause notification to DeZog to notify about the state change. Then dezogif will wait for further requests from DeZog, e.g. to read register values etc.

The program is started when DeZog sends a DZRP continue request.

See [Design.md](documentation/Design.doc) for more info.


# Build

~~~
make main
~~~

will create the enNextMf.rom binary.


# Deployment

The enNextMf.rom binary needs to be copied to the ZX Next SD card under machines/next/enNextMf.rom.

There exists already one, so you need to backup the original.

The program (dezogif/enNextMf.rom) is started after NextOS has been started by pressing the yellow NMI button.

To re-initialize later you need to hold down the "Symbol Shift" (or CTRL) key while hitting the NMI button.


# License

This program is licensed under the [MIT license](https://github.com/maziac/dezogif/blob/master/LICENSE.txt).

The source code is available on [github](https://github.com/maziac/dezogif).


# Acknowledgements

Many thanks to Chris Kirby. I have used his NDS code https://github.com/Ckirby101/NDS-NextDevSystem as starting point and used e.g. his routine to set the baudrate.



