# Debug Uart Interface

# Introduction

This is a ZXNext assembler program that communicates via the UART with a debugger on a PC.

It is intended to use this with the DeZog, a vscode debug adapter.



# Design

This uart driver needs cooperation by the debugged program.
I.e. the debugged program needs to call it in it's main loop.

The UART driver receive register is checked. If nothing has been received then the driver immediately returns. 
Thus the overhead for a program should be just a few instructions.

When a byte has been received the UART driver takes over control.
It disables interrupts and receives the complete UART message.
When received the message/command is interpreted.
A response is sent. E.g. the register values are sent.

The UART driver stays in it's own loop waiting for the next message/command.
This goes on until the UART driver receives a CONTINUE command.
The UART driver will restore all registers and return to the debugged program's main loop.


# Acknowledgements

Many thanks to Chris Kirby. I have used his NDS code https://github.com/Ckirby101/NDS-NextDevSystem as starting point and used e.g. his routine to set the baudrate.



