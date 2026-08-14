// Unified Memory Module (Instructions + Data)
module memory(
    input clk,
    input MemRead,
    input MemWrite,
    input [31:0] address,
    input [31:0] write_data,
    output reg [31:0] read_data
);
    reg [31:0] mem [0:255]; // 256 words memory space

    always @(*) begin
        if (MemRead)
            read_data = mem[address[31:2]]; // Word-aligned
        else
            read_data = 32'b0;
    end

    always @(posedge clk) begin
        if (MemWrite)
            mem[address[31:2]] <= write_data;
    end
endmodule

// System Top Module
module mips_top (
    input clk,
    input reset
);
    wire [31:0] mem_address, mem_write_data, mem_read_data;
    wire MemRead, MemWrite;

    mips_core core (
        .clk(clk),
        .reset(reset),
        .mem_address(mem_address),
        .mem_write_data(mem_write_data),
        .mem_read_data(mem_read_data),
        .MemRead(MemRead),
        .MemWrite(MemWrite)
    );

    memory ram (
        .clk(clk),
        .MemRead(MemRead),
        .MemWrite(MemWrite),
        .address(mem_address),
        .write_data(mem_write_data),
        .read_data(mem_read_data)
    );
endmodule