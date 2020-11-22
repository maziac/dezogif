
var unitTestData = [];
var portUartTxData = [];

/**
 * Returns 0 for the UART port.
 * This is the whole "uart simulation".
 */
API.readPort = (port) => {
	// Check for port 0x0001 = Read TX data for unit testing
	if (port == 0x0001) {
		// Port 0 (on reading) returns the data in the portUartTxData buffer
		const value = portUartTxData.shift();
		if (value == undefined) {
			// Error in test, too less data.
			API.log("Reading from port 0x0000: No data available.");
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

	// Check for PORT_UART_TX=0x133B
	if (port == 0x133B) {
		// Reads the status. Bit 0: 0=RX empty, 1=RX not empty
		let status = 0;
		if (unitTestData.length != 0)
			status |= 0b01;
		return status;
	}
	// Check for PORT_UART_RX=0x143B
	if (port == 0x143B) {
		// Reads a byte
		const value = unitTestData.shift();
		//API.log("Reading from PORT_UART_RX=0x143B: "+value);
		if (value == undefined) {
			// Error in test, too less data.
			API.log("Reading from PORT_UART_RX=0x143B although no test data available.");
			return 0;
		}
		return value;
	}
	// Otherwise do nothing
	return undefined;
}


/**
 * Simulate writing of ports.
 */
API.writePort = (port, value) => {
	// Check for port 0 = Unit test data
	if (port == 0x0000) {
		// Store test data
		API.log("Pushed test data: " + value);
		unitTestData.push(value);
	}
	// Check for PORT_UART_TX=0x133B
	if (port == 0x133B) {
		// Store the written byte.
		portUartTxData.push(value);
	}
	// Otherwise do nothing
	return undefined;
}
