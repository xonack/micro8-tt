# SPDX-FileCopyrightText: © 2024 Jens Honack
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge


@cocotb.test()
async def test_fibonacci(dut):
    """Run Fibonacci program and verify GPIO output sequence."""

    # Fibonacci program ROM
    rom = [0xE0] * 256  # NOP fill
    program = [
        0x40,  # LDI 0
        0x30,  # STR R0
        0x41,  # LDI 1
        0x31,  # STR R1
        0x4D,  # LDI 13
        0x32,  # STR R2
        0x29,  # MOV R1
        0xF1,  # OUT
        0x00,  # ADD R0
        0x33,  # STR R3
        0x29,  # MOV R1
        0x30,  # STR R0
        0x2B,  # MOV R3
        0x31,  # STR R1
        0x2A,  # MOV R2
        0xE6,  # DEC
        0x32,  # STR R2
        0xB4,  # BNE -12
        0xE1,  # HLT
    ]
    for i, b in enumerate(program):
        rom[i] = b

    dut._log.info("Starting Fibonacci test")

    # Start clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.ena.value = 1
    dut.rst_n.value = 0
    dut.uio_in.value = 0
    dut.ui_in.value = rom[0]
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1

    expected = [1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89, 144, 233]
    outputs = []
    out_pending = False

    for cycle in range(2000):
        # Combinational ROM feedback: feed instruction based on current PC
        pc = dut.uo_out.value.integer
        dut.ui_in.value = rom[pc]

        await RisingEdge(dut.clk)

        # If OUT executed last cycle, capture GPIO value now
        if out_pending:
            val = dut.uio_out.value.integer
            outputs.append(val)
            dut._log.info(f"  OUT[{len(outputs)-1}] = {val}")
            out_pending = False

        # Detect OUT instruction (0xF1) during execute phase
        # Access internal signals: state=1 means execute, ir=0xF1 means OUT
        try:
            state = dut.user_project.u_core.state.value.integer
            ir = dut.user_project.u_core.ir.value.integer
            if state == 1 and ir == 0xF1:
                out_pending = True
        except Exception:
            pass

        # Check for halt
        try:
            if dut.user_project.u_core.halted.value.integer == 1:
                dut._log.info(f"CPU halted after {cycle} cycles")
                break
        except Exception:
            pass

    # Capture final OUT if pending
    if out_pending:
        val = dut.uio_out.value.integer
        outputs.append(val)
        dut._log.info(f"  OUT[{len(outputs)-1}] = {val}")

    dut._log.info(f"Collected {len(outputs)} outputs: {outputs}")
    assert len(outputs) == 13, f"Expected 13 Fibonacci outputs, got {len(outputs)}: {outputs}"
    for i, (got, exp) in enumerate(zip(outputs, expected)):
        assert got == exp, f"Output[{i}]: got {got}, expected {exp}"

    dut._log.info("ALL 13 FIBONACCI OUTPUTS VERIFIED")


@cocotb.test()
async def test_reset(dut):
    """Verify reset clears all outputs to zero."""

    dut._log.info("Starting reset test")

    clock = Clock(dut.clk, 10, units="ns")
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
