# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

@cocotb.test()
async def test_project(dut):
    dut._log.info("Start")
    clock = Clock(dut.clk, 10, units="us")
    cocotb.start_soon(clock.start())

    dut._log.info("Reset")
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1

    dut._log.info("Test: verify reset state")
    await ClockCycles(dut.clk, 10)
    # After reset, SPI CS should be high (inactive)
    # uo_out[3] = spi_cs_n_m should be 1
    assert (dut.uo_out.value & 0x08) == 0x08, f"SPI CS should be high after reset, got {dut.uo_out.value}"
    dut._log.info("Test passed")
