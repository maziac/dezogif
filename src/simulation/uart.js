
/**
 * Returns 0 for the UART port.
 * This is the whole "uart simulation".
 */
API.readPort = (port) => {
	// Check for PORT_UART_TX=0x133B
	if (port == 0x133B)
		return 0;
	// Otherwise do nothing
	return undefined;
}
