`default_nettype none

module mano3_cpu_tt (
    input  wire       clk,
    input  wire       rst,     // active-high
    input  wire       en,      // run enable
    output reg [7:0]  A,
    output reg [7:0]  PC,
    output reg [7:0]  IR,
    output reg [7:0]  MAR,
    output reg [7:0]  MBR,
    output reg [2:0]  T
);

    localparam [7:0] R_CONST = 8'd99;

    wire is_MOV = (IR == 8'h01);
    wire is_LDI = (IR == 8'h02);
    wire is_LDA = (IR == 8'h03);

    wire end_MOV = is_MOV && (T == 3'd3);
    wire end_LDI = is_LDI && (T == 3'd5);
    wire end_LDA = is_LDA && (T == 3'd7);
    wire end_instr = end_MOV || end_LDI || end_LDA;

    // ROM-style memory lookup (synthesizable, tiny, passes TT easily)
    function automatic [7:0] mem_read(input [7:0] addr);
        begin
            case (addr)
                8'd0:   mem_read = 8'h01;    // MOV
                8'd1:   mem_read = 8'h02;    // LDI
                8'd2:   mem_read = 8'h55;    // imm
                8'd3:   mem_read = 8'h03;    // LDA
                8'd4:   mem_read = 8'd220;   // address
                8'd220: mem_read = 8'hFF;    // data
                default: mem_read = 8'h00;
            endcase
        end
    endfunction

    always @(posedge clk) begin
        if (rst) begin
            A   <= 8'h00;
            PC  <= 8'h00;
            IR  <= 8'h00;
            MAR <= 8'h00;
            MBR <= 8'h00;
            T   <= 3'd0;
        end else if (en) begin
            case (T)
                3'd0: MAR <= PC;                // t0
                3'd1: begin                     // t1
                    MBR <= mem_read(MAR);
                    PC  <= PC + 8'd1;
                end
                3'd2: IR <= MBR;                // t2

                3'd3: begin
                    if (is_MOV)      A   <= R_CONST; // MOV t3
                    else if (is_LDI) MAR <= PC;      // LDI t3
                    else if (is_LDA) MAR <= PC;      // LDA t3
                end

                3'd4: begin
                    if (is_LDI || is_LDA) begin
                        MBR <= mem_read(MAR);
                        PC  <= PC + 8'd1;
                    end
                end

                3'd5: begin
                    if (is_LDI)      A   <= MBR;
                    else if (is_LDA) MAR <= MBR;
                end

                3'd6: if (is_LDA) MBR <= mem_read(MAR);
                3'd7: if (is_LDA) A   <= MBR;
            endcase

            if (end_instr) T <= 3'd0;
            else           T <= T + 3'd1;
        end
    end

endmodule

`default_nettype wire
