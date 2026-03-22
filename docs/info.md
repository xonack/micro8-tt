## How it works

Micro8 is a minimal 8-bit accumulator-based CPU with Harvard architecture. It executes one instruction per two clock cycles (fetch + execute).

**Architecture:**
- 8-bit accumulator (ACC)
- 8 latch-based registers (R0-R7) — uses MCPU5's latch trick for minimal cell count
- 8-bit program counter with wraparound
- Zero (Z) and Carry (C) flags
- 8-bit bidirectional GPIO port

**Instruction Set (20 instructions in 4 groups):**
- **Group A** (register ALU): ADD, SUB, AND, OR, XOR, MOV, STR, CMP
- **Group B** (immediates): LDI (5-bit), ADDI (5-bit)
- **Group C** (branches): BEQ, BNE, BRA with ±16 offset range
- **Group D** (extended): CLR, NOT, NEG, INC, DEC, SHL, SHR, ROL, ROR, JMP, JSR, LDIR, STIR, SWAP, INP, OUT, SETDIR, LUI, NOP, HLT

**Pin interface:**
- `ui_in[7:0]`: Instruction input from external ROM
- `uo_out[7:0]`: Program counter output (ROM address)
- `uio[7:0]`: Bidirectional GPIO (direction set by SETDIR instruction)

The CPU outputs its PC on `uo_out`. An external ROM (or FPGA fabric) feeds the instruction at that address back on `ui_in`. This combinational ROM loop executes programs from external memory.

**Loading full 8-bit constants:** Use `LDI <hi3>`, `LUI`, `ADDI <lo5>` (3 instructions to load any 8-bit value).

## How to test

1. Connect an external ROM to `ui_in` addressed by `uo_out`
2. Load a program into the ROM (e.g., the Fibonacci sequence program)
3. Assert reset (`rst_n` low) for at least 2 clock cycles, then release
4. Observe GPIO output (`uio_out`) for program results
5. The included cocotb test runs a Fibonacci program and verifies the output sequence: 1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89, 144, 233

## External hardware

- External ROM (SRAM, Flash, or FPGA LUT-based) connected: address from `uo_out`, data to `ui_in`
- Optional: LEDs on `uio_out` for GPIO visualization
- Optional: DIP switches on `uio_in` for GPIO input (directly on pins configured as input by SETDIR)

For the simplest test setup, implement a small ROM in FPGA fabric that maps `uo_out` addresses to instruction bytes.
