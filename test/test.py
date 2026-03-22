# SPDX-FileCopyrightText: © 2024 Jens Honack
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge, FallingEdge, Timer


async def rom_driver(dut, rom):
    """Continuously drive ui_in from ROM based on uo_out (PC).

    Updates on both rising and falling edges to ensure the ROM data
    is always available when the CPU needs it for fetch.
    """
    while True:
        await FallingEdge(dut.clk)
        pc = dut.uo_out.value.to_unsigned()
        dut.ui_in.value = rom[pc]


@cocotb.test()
async def test_fibonacci(dut):
    """Run Fibonacci program and verify GPIO output sequence."""

    # Fibonacci program ROM
    rom = [0xE0] * 256  # NOP fill
    program = [
        0x40,  # 0:  LDI 0
        0x30,  # 1:  STR R0
        0x41,  # 2:  LDI 1
        0x31,  # 3:  STR R1
        0x4D,  # 4:  LDI 13
        0x32,  # 5:  STR R2
        0x29,  # 6:  MOV R1
        0xF1,  # 7:  OUT
        0x00,  # 8:  ADD R0
        0x33,  # 9:  STR R3
        0x29,  # 10: MOV R1
        0x30,  # 11: STR R0
        0x2B,  # 12: MOV R3
        0x31,  # 13: STR R1
        0x2A,  # 14: MOV R2
        0xE6,  # 15: DEC
        0x32,  # 16: STR R2
        0xB4,  # 17: BNE -12
        0xE1,  # 18: HLT
    ]
    for i, b in enumerate(program):
        rom[i] = b

    dut._log.info("Starting Fibonacci test")

    # Start clock
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())

    # Start ROM driver coroutine (mimics: always @(*) ui_in = rom[uo_out])
    cocotb.start_soon(rom_driver(dut, rom))

    # Reset
    dut.ena.value = 1
    dut.rst_n.value = 0
    dut.uio_in.value = 0
    dut.ui_in.value = rom[0]
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1

    expected = [1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89, 144, 233]
    outputs = []

    # OUT detection: the Verilog TB uses a one-cycle delayed capture.
    # When the CPU executes OUT (ext_code 0x11), io_out updates via NBA.
    # We detect OUT by watching PC transition from 7 to 8 (execute completion).
    # The GPIO value is valid immediately after the execute rising edge.
    prev_pc = 0

    for cycle in range(600):
        await RisingEdge(dut.clk)

        new_pc = dut.uo_out.value.to_unsigned()

        # Detect OUT execution: PC transitions from 7 to 8
        if prev_pc == 7 and new_pc == 8:
            # Wait a tiny bit to ensure NBA propagation
            await Timer(1, unit="ns")
            val = dut.uio_out.value.to_unsigned()
            outputs.append(val)
            dut._log.info(f"  OUT[{len(outputs)-1}] = {val}")

        prev_pc = new_pc

        # Stop once we have all expected outputs
        if len(outputs) == len(expected):
            dut._log.info(f"All outputs collected at cycle {cycle}")
            break

    dut._log.info(f"Collected {len(outputs)} outputs: {outputs}")
    assert len(outputs) == 13, f"Expected 13 Fibonacci outputs, got {len(outputs)}: {outputs}"
    for i, (got, exp) in enumerate(zip(outputs, expected)):
        assert got == exp, f"Output[{i}]: got {got}, expected {exp}"

    dut._log.info("ALL 13 FIBONACCI OUTPUTS VERIFIED")


@cocotb.test()
async def test_reset(dut):
    """Verify reset clears all outputs to zero."""

    dut._log.info("Starting reset test")

    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())

    # Hold in reset
    dut.ena.value = 1
    dut.rst_n.value = 0
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    await ClockCycles(dut.clk, 5)

    # Verify outputs are zero during reset
    assert dut.uo_out.value == 0, f"PC should be 0 during reset, got {dut.uo_out.value}"
    assert dut.uio_out.value == 0, f"GPIO out should be 0 during reset, got {dut.uio_out.value}"
    assert dut.uio_oe.value == 0, f"GPIO dir should be 0 during reset, got {dut.uio_oe.value}"

    dut._log.info("Reset test passed")
