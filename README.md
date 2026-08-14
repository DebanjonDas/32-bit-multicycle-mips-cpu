# 32-bit Multicycle MIPS CPU

A Verilog implementation of the classic **multicycle MIPS datapath and control unit**, built around a shared ALU and a finite state machine (FSM) controller. The design fetches, decodes, and executes instructions over multiple clock cycles per instruction (as opposed to a single-cycle or pipelined design), reusing hardware such as the ALU and memory across cycles.

## Features

- 32-bit datapath with a 32 x 32-bit register file (`$0`–`$31`, with `$0` hardwired to zero)
- Single shared ALU used for PC increment, branch target calculation, address calculation, and R-type operations
- FSM-based controller with 12 states covering fetch, decode, memory access, execution, and write-back
- Unified instruction/data memory (256 x 32-bit words)
- Supports core MIPS instructions:
  - **R-type:** `add`, `sub`, `and`, `or`, `slt`
  - **I-type:** `lw`, `sw`, `beq`, `addi`
  - **J-type:** `j`
- Fully synchronous reset
- Verified with waveform simulation (screenshot included)

## Architecture

The design follows the standard Patterson & Hennessy multicycle MIPS architecture, split into two main blocks:

- **Datapath** (`datapath`) — contains the PC, instruction register (IR), memory data register (MDR), A/B pipeline registers, ALU output register, register file, ALU, sign extender, and shift-left-2 unit.
- **Controller** (`controller_fsm`) — a Moore-style FSM that generates all control signals (`PCWrite`, `IRWrite`, `RegWrite`, `MemRead`, `MemWrite`, `ALUSrcA/B`, `PCSource`, `RegDst`, `MemtoReg`, `ALUControl`, `IorD`) based on the current state, opcode, and funct field.

```
                ┌─────────────────────┐
                │   controller_fsm    │
                │  (control signals)  │
                └─────────┬───────────┘
                          │ control signals
                          ▼
   clk/reset ──▶ ┌─────────────────────┐        mem_address
                 │      datapath       │───────▶ mem_write_data
                 │  (mips_core.dp)     │◀─────── mem_read_data
                 └─────────────────────┘
```

`mips_core` wires the datapath and controller together, and `mips_top` connects `mips_core` to a unified `memory` module to form the complete system.

### FSM States

| State | Description |
|---|---|
| `FETCH` | Read instruction from memory into IR, increment PC |
| `DECODE` | Decode opcode, precompute branch target |
| `MEM_ADDR` | Compute effective address (base + offset) for `lw`/`sw` |
| `MEM_READ` | Read data memory into MDR |
| `MEM_WB` | Write loaded data back to register file |
| `MEM_WRITE` | Write data memory |
| `EXECUTE` | Perform R-type ALU operation |
| `R_WB` | Write ALU result back to register file |
| `ADDI_EXEC` | Compute `addi` result |
| `ADDI_WB` | Write `addi` result back to register file |
| `BRANCH` | Compare registers, conditionally update PC |
| `JUMP` | Update PC with jump target |

## Repository Structure

```
.
├── mips_core.v     # Datapath, controller FSM, ALU, register file, PC, and all core CPU modules
├── mips_top.v       # Top-level module: instantiates mips_core + unified memory
└── docs/
    ├── MIPS_CPU_Schematic.pdf   # Full RTL schematic (generated from synthesis)
    └── waveform.png             # Simulation waveform showing instruction execution
```

## Getting Started

### Prerequisites

Any standard Verilog simulator, e.g.:
- [Icarus Verilog](http://iverilog.icarus.com/) + [GTKWave](http://gtkwave.sourceforge.net/)
- Xilinx Vivado / ISE
- ModelSim / QuestaSim

### Simulate with Icarus Verilog

```bash
iverilog -o mips_sim mips_top.v mips_core.v testbench.v
vvp mips_sim
gtkwave dump.vcd
```

> Add your own `testbench.v` that instantiates `mips_top`, drives `clk`/`reset`, and preloads the `mem` array in `memory` with test instructions.

## Simulation Waveform

The waveform below shows a sequence of instructions moving through the FSM states (`FETCH → DECODE → EXECUTE/MEM_ADDR → WB`), with `PC`, `IR`, `ALUOut`, `MDR`, and register file signals updating each cycle.

![Waveform](docs/waveform.png)

## RTL Schematic

A synthesized RTL schematic of the full design (datapath + controller + memory hierarchy) is available in [`docs/MIPS_CPU_Schematic.pdf`](docs/MIPS_CPU_Schematic.pdf).

## Design Notes / Limitations

- Memory is a single unified 256-word array shared for instructions and data (no separate I-cache/D-cache).
- Only a subset of the MIPS ISA is implemented (`add`, `sub`, `and`, `or`, `slt`, `lw`, `sw`, `beq`, `addi`, `j`); other opcodes fall back to `FETCH`.
- No hazard handling is needed since this is a multicycle (not pipelined) design — each instruction completes before the next begins.
- No exception/interrupt handling.

## Future Improvements

- [ ] Add more instructions (`jal`, `jr`, `bne`, `addiu`, `andi`, `ori`, etc.)
- [ ] Add a testbench with a full instruction-level test program
- [ ] Parameterize memory size
- [ ] Add exception handling (overflow, invalid opcode)
- [ ] Convert to a pipelined 5-stage implementation for comparison

## License

This project is open-source and available under the [MIT License](LICENSE).

## Author

Built as an academic/portfolio project to demonstrate multicycle CPU design in Verilog, following the classic Hennessy & Patterson multicycle MIPS architecture.

