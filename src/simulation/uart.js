
var unitTestData = [];
var portUartTxData = [];
var portRegReset = 0;
var whichNextReg = 0;
var nextRegContents = new Map();	// Any values written to a next reg will be stored here as well.


portUartTxData.length = 0;

/**
 * Returns 0 for the UART port.
 * This is the whole "uart simulation".
 */
API.readPort = (port) => {
	// Check for port 0x0001 = Read TX data for unit testing
	if (port == 0x0001) {
		// Port 0001 (on reading) returns the data in the portUartTxData buffer
		const value = portUartTxData.shift();
		if (value == undefined) {
			// Error in test, too less data.
			API.log("  Reading from port 0x0000: No data available.");
			return undefined;
		}
		return value;
	}
	// Check for port 0x0002/3 = Read length of TX data for unit testing
	if (port == 0x0002) {
		// Port 0 (on reading) returns the data in the portUartTxData buffer
		return portUartTxData.length & 0xFF;	// LOW byte
	}
	if (port == 0x0003) {
		// Port 0 (on reading) returns the data in the portUartTxData buffer
		return (portUartTxData.length>>>8)&0xFF;	// HIGH byte
	}
	if (port == 0x0004) {
		// Return the last write to the nextreg register
		return nextRegContents.get(whichNextReg);
	}

	// Check for PORT_UART_TX=0x133B
	if (port == 0x133B) {
		// Reads the status. Bit 0: 0=RX empty, 1=RX not empty
		let status = 0;
		if (unitTestData.length != 0)
			status |= 0b01;
		status |= 0b010000; // UART_TX_EMPTY = always empty, simulate immediately read
		API.log("  portUartTxData.length = " + portUartTxData.length);
		return status;
	}
	// Check for PORT_UART_RX=0x143B
	if (port == 0x143B) {
		// Reads a byte
		const value = unitTestData.shift();
		API.log("  Reading from PORT_UART_RX=0x143B: "+value);
		if (value == undefined) {
			// Error in test, too less data.
			API.log("  Reading from PORT_UART_RX=0x143B although no test data available.");
			return 0;
		}
		return value;
	}

	// Simulate reading REG_RESET, REG_SUB_VERSION and REG_VERSION
	if (port == 0x253B /*IO_NEXTREG_DAT*/) {
		API.log("  Reading from port IO_NEXTREG_DAT=0x253B.");
		if (whichNextReg == 1 /*REG_VERSION*/) {
			const majMin = 0x31;
			API.log("    Reading register REG_VERSION=1: " + majMin.toString(16) + "h");
			return majMin;
		}
		if (whichNextReg == 14 /*REG_SUB_VERSION*/) {
			const subminor = 10;
			API.log("    Reading register REG_VERSION=14: " + subminor);
			return subminor;
		}
		if (whichNextReg == 2 /*REG_RESET*/) {
			API.log("    Reading register REG_RESET=2: " + portRegReset);
			return portRegReset;
		}
	}

	if (port == 0x80AC) {
		// Value that will be read from port 80AC
		return port80ACValue;
	}
	// Otherwise do nothing
	return undefined;
}


/**
 * Simulate writing of ports.
 */
API.writePort = (port, value) => {
	// Check for port 1 = Unit test data
	if (port == 0x8000) {
		// Note: writing to e.g. port 0 would also trigger changing the memory (port 0x7FFD)
		// Store test data
		API.log("  Pushed test data: " + value);
		unitTestData.push(value);
	}
	// Check for PORT_UART_TX=0x133B
	else if (port == 0x133B) {
		// Store the written byte.
		portUartTxData.push(value);
	}
	// Check for port 2 = REG_RESET data that will be read on reading a next register.
	else if (port == 0x0002) {
		// Store test data
		API.log("  Store test data for RESET_REG: " + value);
		portRegReset = value;
	}
	else if (port == 0x243B /*IO_NEXTREG_REG*/) {
		// Select next reg
		API.log("  Select nextreg register: " + value);
		whichNextReg = value;
	}
	else if (port == 0x253B /*IO_NEXTREG_DAT*/) {
		// Select next reg
		API.log("  Writing to nextreg register" + whichNextReg + ": " + value);
		nextRegContents.set(whichNextReg, value);
	}
	else if (port == 0x80AC) {
		// Value that will be output when reading from port 80AC
		port80ACValue = value;
	}
	// Otherwise do nothing
}
