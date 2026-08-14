`timescale 1ns / 1ps

module tb_mips;
    reg clk;
    reg reset;

    // Instantiate Top-Level System
    mips_top uut (
        .clk(clk),
        .reset(reset)
    );

    // Clock Generation (100MHz)
    always #5 clk = ~clk;

    initial begin
    $dumpfile("mips_waveform.vcd");
    $dumpvars(0, tb_mips);
        // Initialize Memory with Sample Machine Instructions
        uut.ram.mem[0] = 32'h20080005; // addi $t0, $zero, 5
        uut.ram.mem[1] = 32'h2009000a; // addi $t1, $zero, 10
        uut.ram.mem[2] = 32'h01095020; // add  $t2, $t0, $t1    ($t2 = 15)
        uut.ram.mem[3] = 32'hac0a0004; // sw   $t2, 16($zero)  (mem[4] = 15)
        uut.ram.mem[4] = 32'h8c0b0004; // lw   $t3, 16($zero)  ($t3 = 15)
        uut.ram.mem[5] = 32'h114b0001; // beq  $t2, $t3, 1    (Branch to 7)
        uut.ram.mem[6] = 32'h200a0063; // addi $t2, $zero, 99 (Skipped)
        uut.ram.mem[7] = 32'h08000007; // j 7                  (Infinite loop)

        // Reset Pulse
        clk = 0;
        reset = 1;
        #20;
        reset = 0;

        // Monitor Key Registers
        $monitor("Time=%0t ns | PC=%h | State=%d | $t0=%d | $t1=%d | $t2=%d | $t3=%d",
                 $time, uut.core.dp.PC, uut.core.ctrl.state,
                 uut.core.dp.rf.registers[8],  // $t0
                 uut.core.dp.rf.registers[9],  // $t1
                 uut.core.dp.rf.registers[10], // $t2
                 uut.core.dp.rf.registers[11]  // $t3
        );

        #500;
        
        // Self-Checking Verification
        if (uut.core.dp.rf.registers[10] == 15 && uut.core.dp.rf.registers[11] == 15) begin
            $display("\n==============================================");
            $display(" SUCCESS: MIPS CPU Execution Verified!");
            $display("==============================================\n");
        end else begin
            $display("\n==============================================");
            $display(" FAILURE: Incorrect Execution Output");
            $display("==============================================\n");
        end
        $finish;
    end
endmodule