# 32-bit Multicycle MIPS CPU

A Verilog implementation of the classic **multicycle MIPS datapath and control unit**, built around a shared ALU and a finite state machine (FSM) controller. The design fetches, decodes, and executes instructions over multiple clock cycles per instruction (as opposed to a single-cycle or pipelined design), reusing hardware such as the ALU and memory across cycles.

## Technical Specifications

| | |
|---|---|
| Architecture | Multi-cycle (3–5 clock cycles per instruction) |
| Data path width | 32-bit |
| Memory | Unified 256 × 32-bit RAM (instructions + data), word-aligned addressing |
| Register file | 32 × 32-bit GPRs, `$0` hardwired to 0, async dual-port read, sync write |
| ALU operations | ADD, SUB, AND, OR, SLT |
| Control unit | 12-state Moore FSM |

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
 mips_top
┌───────────────────────────────────────────────────────────────┐
│                                                                 │
│   mips_core (core)                                             │
│  ┌───────────────────────────────────────────────────────┐    │
│  │                                                         │    │
│  │   controller_fsm (ctrl)                                 │    │
│  │   opcode, funct, Zero ──▶ [FSM] ──▶ control signals ────┼──┐ │
│  │                                                         │  │ │
│  └─────────────────────────────────────────────────────────┘  │ │
│                                                                 │ │
│  ┌───────────────────────────────────────────────────────┐    │ │
│  │   datapath (dp)                                        │◀───┘ │
│  │   PC, IR, MDR, A/B regs, ALUOut, register_file, alu,    │      │
│  │   sign_extend, shift_left_2                             │      │
│  │                                                         │      │
│  └───────────────────────────────────────────────────────┘      │
│         │ mem_address, mem_write_data      ▲ mem_read_data       │
│         ▼                                  │                     │
└─────────┼──────────────────────────────────┼─────────────────────┘
          │           MemRead, MemWrite      │
          ▼                                  │
      ┌───────────────────────────────────────────┐
      │   memory (ram)                             │
      │   256 x 32-bit unified instruction/data RAM │
      └───────────────────────────────────────────┘
```

`mips_core` wires the `datapath` and `controller_fsm` together internally. `mips_top` sits one level above and connects `mips_core` to the unified `memory` module via `mem_address`, `mem_write_data`, `mem_read_data`, `MemRead`, and `MemWrite` to form the complete system — matching the RTL schematic exported from synthesis.

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

## Supported Instruction Set (ISA)

| Instruction | Type | Opcode | Funct | Syntax | Operation |
|---|---|---|---|---|---|
| ADD | R | 0x00 | 0x20 | `add $rd, $rs, $rt` | `$rd = $rs + $rt` |
| SUB | R | 0x00 | 0x22 | `sub $rd, $rs, $rt` | `$rd = $rs - $rt` |
| AND | R | 0x00 | 0x24 | `and $rd, $rs, $rt` | `$rd = $rs & $rt` |
| OR | R | 0x00 | 0x25 | `or $rd, $rs, $rt` | `$rd = $rs \| $rt` |
| SLT | R | 0x00 | 0x2A | `slt $rd, $rs, $rt` | `$rd = ($rs < $rt) ? 1 : 0` |
| LW | I | 0x23 | — | `lw $rt, imm($rs)` | `$rt = Mem[$rs + SignExt(imm)]` |
| SW | I | 0x2B | — | `sw $rt, imm($rs)` | `Mem[$rs + SignExt(imm)] = $rt` |
| ADDI | I | 0x08 | — | `addi $rt, $rs, imm` | `$rt = $rs + SignExt(imm)` |
| BEQ | I | 0x04 | — | `beq $rs, $rt, offset` | `if ($rs == $rt) PC = BranchTarget` |
| J | J | 0x02 | — | `j target` | `PC = JumpTarget` |

## FSM State Flow

```
FETCH ──▶ DECODE ─┬─(R-type)──▶ EXECUTE ──▶ R_WB ─────┐
                   ├─(lw/sw)──▶ MEM_ADDR ─┬─(lw)──▶ MEM_READ ──▶ MEM_WB ─┐
                   │                      └─(sw)──▶ MEM_WRITE ──────────┤
                   ├─(addi)───▶ ADDI_EXEC ──▶ ADDI_WB ───────────────────┤
                   ├─(beq)────▶ BRANCH ─────────────────────────────────┤
                   └─(j)──────▶ JUMP ────────────────────────────────────┤
                                                                          ▼
                                                                       FETCH
```

## Repository Structure

```
.
├── mips_core.v                        # Datapath, controller FSM, ALU, register file, PC, and all core CPU modules
├── mips_top.v                         # Top-level module: instantiates mips_core + unified memory
├── Screenshot 2026-08-14 112727.png   # RTL schematic screenshot
├── Screenshot 2026-08-14 112952.png   # GTKWave simulation waveform screenshot
└── docs/
    ├── MIPS_CPU_Schematic_core.pdf    # Full RTL schematic of mips_core (datapath + controller)
    └── MIPS_CPU_Schematic_top.pdf     # Full RTL schematic of mips_top (core + memory)
```

## Getting Started

### Prerequisites

Any standard Verilog simulator, e.g.:
- [Icarus Verilog](http://iverilog.icarus.com/) + [GTKWave](http://gtkwave.sourceforge.net/)
- Xilinx Vivado / ISE
- ModelSim / QuestaSim

### Simulate with Icarus Verilog

```bash
iverilog -o mips_sim mips_top.v mips_core.v tb_mips.v
vvp mips_sim
gtkwave mips_waveform.vcd
```

> Add your own `tb_mips.v` testbench that instantiates `mips_top`, drives `clk`/`reset`, and preloads the `mem` array in `memory` with test instructions.

## RTL & Waveform Screenshots

### RTL Schematic

![RTL Schematic](./Screenshot%202026-08-14%20112727.png)

Full synthesized schematics (higher resolution, per-module) are available as PDFs:
- [`MIPS_CPU_Schematic_core.pdf`](docs/MIPS_CPU_Schematic_core.pdf) — internals of `mips_core` (datapath + controller FSM)
- [`MIPS_CPU_Schematic_top.pdf`](docs/MIPS_CPU_Schematic_top.pdf) — top-level view (`mips_core` + `memory`)

### Simulation Waveform

![Simulation Waveform](./Screenshot%202026-08-14%20112952.png)

The GTKWave capture above shows a sequence of instructions moving through the FSM states (`FETCH → DECODE → EXECUTE/MEM_ADDR → WB`), with `PC`, `IR`, `ALUOut`, `MDR`, and register file signals updating each cycle.

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
