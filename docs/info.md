## How it works

This chip implements a bidirectional I2C↔SPI bridge. It can operate in two modes:

1. **I2C to SPI**: An external I2C master sends data to this chip (I2C address 0x42), which forwards it to an SPI slave device.
2. **SPI to I2C**: An external SPI master sends data to this chip, which forwards it to an I2C slave device.

The bridge contains an I2C slave controller, an I2C master controller, an SPI master controller, and an SPI slave controller, connected via internal FIFOs.

## How to test

Connect an I2C master to the SDA/SCL inputs and write to address 0x42. Send command byte 0x01 followed by data to trigger an I2C→SPI transfer. Verify the data appears on the SPI master output pins.

## External hardware

- I2C master device (for I2C slave interface testing)
- SPI slave device (e.g. sensor or memory)
- Logic analyzer recommended for verification
