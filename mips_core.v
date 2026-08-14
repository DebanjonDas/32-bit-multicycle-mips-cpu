// Program Counter Register
module pc(
    input clk,
    input reset,
    input pc_write,
    input [31:0] pc_next,
    output reg [31:0] pc
);

always @(posedge clk or posedge reset)
begin
    if(reset)
        pc <= 0;
    else if(pc_write)
        pc <= pc_next;
end
endmodule

// Register File (32 x 32-bit)
module register_file (
    input clk,
    input reset,
    input RegWrite,
    input  [4:0] read_reg1,   // rs
    input  [4:0] read_reg2,   // rt
    input  [4:0] write_reg,   // rd or rt
    input  [31:0] write_data,
    output [31:0] read_data1,
    output [31:0] read_data2
);
    reg [31:0] registers [31:0];
    integer i;

    always @(posedge clk or posedge reset) begin
        if(reset) begin
            for(i = 0; i < 32; i = i + 1)
                registers[i] <= 32'b0;
        end else if(RegWrite) begin
            if(write_reg != 5'd0)      // $zero register is hardwired to 0
                registers[write_reg] <= write_data;
        end
    end

   assign read_data1 = (read_reg1 == 0) ? 32'b0 : registers[read_reg1];
    assign read_data2 = (read_reg2 == 0) ? 32'b0 : registers[read_reg2];
endmodule

// Arithmetic Logic Unit (ALU)
module alu (
    input  [31:0] A,
    input  [31:0] B,
    input  [2:0] ALUControl,
    output reg [31:0] Result,
    output Zero
);

always @(*)
begin
    case(ALUControl)
        3'b000: Result = A + B;                  // ADD
        3'b001: Result = A - B;                  // SUB
        3'b010: Result = A & B;                  // AND
        3'b011: Result = A | B;                  // OR
        3'b100: Result = ($signed(A) < $signed(B)) ? 32'd1 : 32'd0;       // SLT
        default: Result = 32'd0;
    endcase
end
assign Zero = (Result == 32'd0);
endmodule

module instruction_register(
    input clk,
    input reset,
    input IRWrite,
    input [31:0] mem_data,
    output reg [31:0] IR
);
always @(posedge clk or posedge reset) begin
    if(reset)
        IR <= 32'b0;
    else if(IRWrite)
        IR <= mem_data;
end
endmodule

module mdr(
    input clk,
    input reset,
    input [31:0] mem_data,
    output reg [31:0] MDR
);
always @(posedge clk or posedge reset) begin
    if(reset)
        MDR <= 32'b0;
    else
        MDR <= mem_data;
end
endmodule

module A_register(
    input clk,
    input reset,
    input [31:0] read_data1,
    output reg [31:0] A
);
always @(posedge clk or posedge reset) begin
    if(reset)
        A <= 32'b0;
    else
        A <= read_data1;
end
endmodule

module B_register(
    input clk,
    input reset,
    input [31:0] read_data2,
    output reg [31:0] B
);
always @(posedge clk or posedge reset) begin
    if(reset)
        B <= 32'b0;
    else
        B <= read_data2;
end
endmodule

module aluout_register(
    input clk,
    input reset,
    input [31:0] alu_result,
    output reg [31:0] ALUOut
);
always @(posedge clk or posedge reset) begin
    if(reset)
        ALUOut <= 32'b0;
    else
        ALUOut <= alu_result;
end
endmodule

module sign_extend(
    input [15:0] imm,
    output [31:0] sign_ext
);
assign sign_ext = {{16{imm[15]}}, imm};
endmodule

module shift_left_2(
    input [31:0] in,
    output [31:0] out
);
assign out = in << 2;
endmodule

module alu_control(
    input [5:0] funct,
    output reg [2:0] ALUControl
);

always @(*)
begin
    case(funct)
    6'b100000: ALUControl = 3'b000; // add
    6'b100010: ALUControl = 3'b001; // sub
    6'b100100: ALUControl = 3'b010; // and
    6'b100101: ALUControl = 3'b011; // or
    6'b101010: ALUControl = 3'b100; // slt
    default:ALUControl = 3'b000;
    endcase
end
endmodule

module datapath(
    input clk,
    input reset,
    input IorD,
    input IRWrite,
    input RegDst,
    input MemtoReg,
    input RegWrite,
    input ALUSrcA,
    input [1:0] ALUSrcB,
    input [1:0] PCSource,
    input PCWrite,
    input [2:0] ALUControl,
    output [5:0] opcode,
    output [5:0] funct,
    output Zero,
    // Memory Interface
    output [31:0] mem_address,
    output [31:0] mem_write_data,
    input  [31:0] mem_read_data
);
// Internal wires
    wire [31:0] PC, IR, MDR, ALUOut;
    wire [31:0] read_data1, read_data2, A, B;
    wire [31:0] sign_ext, shift_out, Result;
    wire [4:0]  write_reg;
    wire [31:0] reg_write_data, alu_in1;
    reg  [31:0] alu_in2;
    reg  [31:0] pc_next;

assign opcode = IR[31:26];
assign funct  = IR[5:0];
assign mem_address = (IorD) ? ALUOut : PC;
assign mem_write_data = B;
assign write_reg = (RegDst) ? IR[15:11] : IR[20:16];
assign reg_write_data = (MemtoReg) ? MDR : ALUOut;
assign alu_in1 = (ALUSrcA) ? A : PC;

sign_extend se(
    .imm(IR[15:0]),
    .sign_ext(sign_ext)
);
shift_left_2 sl2(
    .in(sign_ext),
    .out(shift_out)
);
always @(*)
begin
    case(ALUSrcB)
        2'b00: alu_in2 = B;
        2'b01: alu_in2 = 32'd4;
        2'b10: alu_in2 = sign_ext;
        2'b11: alu_in2 = shift_out;
        default: alu_in2 = B;
    endcase
end
alu alu1(
    .A(alu_in1),
    .B(alu_in2),
    .ALUControl(ALUControl),
    .Result(Result),
    .Zero(Zero)
);
aluout_register aluout1(
    .clk(clk),
    .reset(reset),
    .alu_result(Result),
    .ALUOut(ALUOut)
);
// Jump Address
wire [31:0] jump_addr;
assign jump_addr ={PC[31:28],IR[25:0],2'b00};

always @(*)
begin
    case(PCSource)
        2'b00: pc_next = Result;
        2'b01:pc_next = ALUOut;
        2'b10:pc_next = jump_addr;
        default: pc_next = Result;
    endcase
end
pc pc1(
    .clk(clk),
    .reset(reset),
    .pc_write(PCWrite),
    .pc_next(pc_next),
    .pc(PC)
);
instruction_register ir1(
    .clk(clk),
    .reset(reset),
    .IRWrite(IRWrite),
    .mem_data(mem_read_data),
    .IR(IR)
);
mdr mdr1(
    .clk(clk),
    .reset(reset),
    .mem_data(mem_read_data),
    .MDR(MDR)
);
register_file rf(
    .clk(clk),
    .reset(reset),
    .RegWrite(RegWrite),
    .read_reg1(IR[25:21]),
    .read_reg2(IR[20:16]),
    .write_reg(write_reg),
    .write_data(reg_write_data),
    .read_data1(read_data1),
    .read_data2(read_data2)
);
A_register Areg(
    .clk(clk),
    .reset(reset),
    .read_data1(read_data1),
    .A(A)
);
B_register Breg(
    .clk(clk),
    .reset(reset),
    .read_data2(read_data2),
    .B(B)
);
endmodule

// Controller Finite State Machine (FSM)
module controller_fsm(
    input clk,
    input reset,
    input [5:0] opcode,
    input [5:0] funct,
    input Zero,

    output reg IorD,
    output reg MemRead,
    output reg MemWrite,
    output reg IRWrite,
    output reg RegWrite,
    output reg RegDst,
    output reg MemtoReg,
    output reg ALUSrcA,
    output reg [1:0] ALUSrcB,
    output reg PCWrite,
    output reg [1:0] PCSource,
    output reg [2:0] ALUControl
);
parameter FETCH      = 4'd0;
parameter DECODE     = 4'd1;
parameter MEM_ADDR   = 4'd2;
parameter MEM_READ   = 4'd3;
parameter MEM_WB     = 4'd4;
parameter MEM_WRITE  = 4'd5;
parameter EXECUTE    = 4'd6;
parameter R_WB       = 4'd7;
parameter BRANCH     = 4'd8;
parameter JUMP       = 4'd9;
parameter ADDI_EXEC = 4'd10;
parameter ADDI_WB   = 4'd11;

reg [3:0] state, next_state;

always @(posedge clk or posedge reset) begin
    if(reset)
        state <= FETCH;
    else
        state <= next_state;
end

always @(*)
begin
    case(state)
    FETCH: next_state = DECODE;
    DECODE:begin
       case (opcode)
                    6'b000000: next_state = EXECUTE;   // R-type
                    6'b100011: next_state = MEM_ADDR;  // lw
                    6'b101011: next_state = MEM_ADDR;  // sw
                    6'b000100: next_state = BRANCH;    // beq
                    6'b000010: next_state = JUMP;      // j
                    6'b001000: next_state = ADDI_EXEC; // addi
                    default:   next_state = FETCH;
                endcase
    end
    MEM_ADDR:  next_state = (opcode == 6'b100011) ? MEM_READ : MEM_WRITE;
    MEM_READ:  next_state = MEM_WB;
    MEM_WB:    next_state = FETCH;
    MEM_WRITE: next_state = FETCH;
    EXECUTE:   next_state = R_WB;
    R_WB:      next_state = FETCH;
    ADDI_EXEC: next_state = ADDI_WB;
    ADDI_WB:   next_state = FETCH;
    BRANCH:    next_state = FETCH;
    JUMP:      next_state = FETCH;
    default:   next_state = FETCH;
endcase
end

always @(*)
begin
    IorD       = 0;
    MemRead    = 0;
    MemWrite   = 0;
    IRWrite    = 0;
    RegWrite   = 0;
    RegDst     = 0;
    MemtoReg   = 0;
    ALUSrcA    = 0;
    ALUSrcB    = 2'b00;
    PCWrite    = 0;
    PCSource   = 2'b00;
    ALUControl = 3'b000;
case(state)
    FETCH: begin
        MemRead    = 1;
        IRWrite    = 1;
        ALUSrcA    = 0;
        ALUSrcB    = 2'b01;// PC + 4
        ALUControl = 3'b000; // ADD
        PCWrite    = 1;
        PCSource   = 2'b00;
    end
     DECODE:begin
        ALUSrcA    = 0;
        ALUSrcB    = 2'b11;// Precompute Branch Target
        ALUControl = 3'b000;
    end
      MEM_ADDR:begin
        ALUSrcA    = 1;
        ALUSrcB    = 2'b10;// Sign Extended Immediate
        ALUControl = 3'b000;
    end
     MEM_READ:begin
        MemRead = 1;
        IorD    = 1;
    end
     MEM_WB:begin
        RegWrite = 1;
        RegDst   = 0;// Write to rt
        MemtoReg = 1;// From MDR
    end
     MEM_WRITE:begin
        MemWrite = 1;
        IorD     = 1;
    end
     EXECUTE:begin
        ALUSrcA = 1;
        ALUSrcB = 2'b00;
        case(funct)
            6'b100000: ALUControl = 3'b000; // ADD
            6'b100010: ALUControl = 3'b001; // SUB
            6'b100100: ALUControl = 3'b010; // AND
            6'b100101: ALUControl = 3'b011; // OR
            6'b101010: ALUControl = 3'b100; // SLT
            default:   ALUControl = 3'b000;
        endcase
    end
     R_WB:begin
        RegWrite = 1;
        RegDst   = 1;// Write to rd
        MemtoReg = 0;// From ALUOut
    end
    ADDI_EXEC: begin
        ALUSrcA    = 1;
        ALUSrcB    = 2'b10; // Sign-extended Imm
        ALUControl = 3'b000; // ADD
    end
    ADDI_WB: begin
        RegWrite = 1;
        RegDst   = 0; // Write to rt
        MemtoReg = 0; // From ALUOut
    end
     BRANCH:begin
        ALUSrcA    = 1;
        ALUSrcB    = 2'b00;
        ALUControl = 3'b001; // SUB
        PCSource   = 2'b01;// Branch Target from ALUOut
        if(Zero) PCWrite = 1;
    end
    JUMP:begin
        PCWrite  = 1;
        PCSource = 2'b10;
    end
    endcase
end
endmodule

// Top CPU Core Module
module mips_core (
    input clk,
    input reset,
    output [31:0] mem_address,
    output [31:0] mem_write_data,
    input  [31:0] mem_read_data,
    output MemRead,
    output MemWrite
);
    wire IorD, IRWrite, RegWrite, RegDst, MemtoReg, ALUSrcA, PCWrite, Zero;
    wire [1:0] ALUSrcB, PCSource;
    wire [2:0] ALUControl;
    wire [5:0] opcode, funct;

    datapath dp (
        .clk(clk),
        .reset(reset),
        .IorD(IorD),
        .IRWrite(IRWrite),
        .RegDst(RegDst),
        .MemtoReg(MemtoReg),
        .RegWrite(RegWrite),
        .ALUSrcA(ALUSrcA),
        .ALUSrcB(ALUSrcB),
        .PCSource(PCSource),
        .PCWrite(PCWrite),
        .ALUControl(ALUControl),
        .opcode(opcode),
        .funct(funct),
        .Zero(Zero),
        .mem_address(mem_address),
        .mem_write_data(mem_write_data),
        .mem_read_data(mem_read_data)
    );

    controller_fsm ctrl (
        .clk(clk),
        .reset(reset),
        .opcode(opcode),
        .funct(funct),
        .Zero(Zero),
        .IorD(IorD),
        .MemRead(MemRead),
        .MemWrite(MemWrite),
        .IRWrite(IRWrite),
        .RegWrite(RegWrite),
        .RegDst(RegDst),
        .MemtoReg(MemtoReg),
        .ALUSrcA(ALUSrcA),
        .ALUSrcB(ALUSrcB),
        .PCWrite(PCWrite),
        .PCSource(PCSource),
        .ALUControl(ALUControl)
    );
endmodule