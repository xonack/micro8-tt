`default_nettype none
module micro8_core (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       ena,
    output wire [7:0] prog_addr,
    input  wire [7:0] prog_data,
    input  wire [7:0] io_in,
    output reg  [7:0] io_out,
    output reg  [7:0] io_dir
);
reg        state;
reg [7:0]  acc;
reg [7:0]  pc;
reg [7:0]  ir;
reg        flag_z;
reg        flag_c;
reg        halted;
localparam S_FETCH   = 1'b0;
localparam S_EXECUTE = 1'b1;
assign prog_addr = pc;
reg        rf_we;
reg  [2:0] rf_raddr;
reg  [2:0] rf_waddr;
reg  [7:0] rf_wdata;
wire [7:0] rf_rdata;
regfile u_regfile (
    .clk(clk), .we(rf_we),
    .raddr(rf_raddr), .waddr(rf_waddr),
    .wdata(rf_wdata), .rdata(rf_rdata)
);
reg  [7:0] alu_a, alu_b;
reg  [3:0] alu_op;
wire [7:0] alu_result;
wire       alu_carry, alu_zero;
alu u_alu (
    .a(alu_a), .b(alu_b), .carry_in(flag_c),
    .op(alu_op), .result(alu_result),
    .carry_out(alu_carry), .zero(alu_zero)
);
localparam A_ADD=0, A_SUB=1, A_AND=2, A_OR=3, A_XOR=4, A_PASS=5;
localparam A_NOT=6, A_NEG=7, A_INC=8, A_DEC=9;
localparam A_SHL=10, A_SHR=11, A_ROL=12, A_ROR=13, A_LUI=14;
wire [1:0] group      = ir[7:6];
wire [2:0] grp_a_op   = ir[5:3];
wire [2:0] grp_a_reg  = ir[2:0];
wire       is_addi    = ir[5];
wire [4:0] imm5       = ir[4:0];
wire [2:0] br_type    = ir[7:5];
wire [4:0] br_off_raw = ir[4:0];
wire [4:0] ext_code   = ir[4:0];
wire is_grp_a = (group == 2'b00);
wire is_grp_b = (group == 2'b01);
wire is_grp_c = (br_type == 3'b100 || br_type == 3'b101 || br_type == 3'b110);
wire is_grp_d = (br_type == 3'b111);
wire [7:0] br_offset = br_off_raw[4] ? {3'b111, br_off_raw} : {3'b000, br_off_raw};
wire [7:0] br_target = pc + 8'd1 + br_offset;
always @(*) begin
    alu_a = acc;
    alu_b = 8'd0;
    alu_op = A_PASS;
    rf_raddr = 3'd0;
    if (state == S_EXECUTE) begin
        if (is_grp_a) begin
            rf_raddr = grp_a_reg;
            alu_b = rf_rdata;
            case (grp_a_op)
                3'd0: alu_op = A_ADD;
                3'd1: alu_op = A_SUB;
                3'd2: alu_op = A_AND;
                3'd3: alu_op = A_OR;
                3'd4: alu_op = A_XOR;
                3'd5: alu_op = A_PASS;
                3'd6: alu_op = A_PASS;
                3'd7: alu_op = A_SUB;
                default: alu_op = A_PASS;
            endcase
        end else if (is_grp_b) begin
            alu_b = {3'b000, imm5};
            alu_op = is_addi ? A_ADD : A_PASS;
        end else if (is_grp_d) begin
            case (ext_code)
                5'h03: alu_op = A_NOT;
                5'h04: alu_op = A_NEG;
                5'h05: alu_op = A_INC;
                5'h06: alu_op = A_DEC;
                5'h07: alu_op = A_SHL;
                5'h08: alu_op = A_SHR;
                5'h09: alu_op = A_ROL;
                5'h0A: alu_op = A_ROR;
                5'h0D: begin rf_raddr = acc[2:0]; alu_op = A_PASS; alu_b = rf_rdata; end
                5'h0E: begin rf_raddr = 3'd6; end
                5'h0F: begin rf_raddr = 3'd6; end
                5'h13: alu_op = A_LUI;
                default: alu_op = A_PASS;
            endcase
        end
    end
end
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        acc    <= 8'd0;
        pc     <= 8'd0;
        ir     <= 8'd0;
        flag_z <= 1'b1;
        flag_c <= 1'b0;
        io_out <= 8'd0;
        io_dir <= 8'd0;
        halted <= 1'b0;
        state  <= S_FETCH;
        rf_we  <= 1'b0;
    end else if (ena && !halted) begin
        rf_we <= 1'b0;
        case (state)
            S_FETCH: begin
                ir    <= prog_data;
                state <= S_EXECUTE;
            end
            S_EXECUTE: begin
                state <= S_FETCH;
                if (is_grp_a) begin
                    case (grp_a_op)
                        3'd0, 3'd1: begin
                            acc <= alu_result; flag_z <= alu_zero; flag_c <= alu_carry;
                        end
                        3'd2, 3'd3, 3'd4, 3'd5: begin
                            acc <= alu_result; flag_z <= alu_zero;
                        end
                        3'd6: begin
                            rf_we <= 1'b1; rf_waddr <= grp_a_reg; rf_wdata <= acc;
                        end
                        3'd7: begin
                            flag_z <= alu_zero; flag_c <= alu_carry;
                        end
                        default: ;
                    endcase
                    pc <= pc + 8'd1;
                end else if (is_grp_b) begin
                    acc <= alu_result;
                    flag_z <= alu_zero;
                    if (is_addi) flag_c <= alu_carry;
                    pc <= pc + 8'd1;
                end else if (is_grp_c) begin
                    case (br_type)
                        3'b100: pc <= flag_z  ? br_target : (pc + 8'd1);
                        3'b101: pc <= !flag_z ? br_target : (pc + 8'd1);
                        3'b110: pc <= br_target;
                        default: pc <= pc + 8'd1;
                    endcase
                end else if (is_grp_d) begin
                    pc <= pc + 8'd1;
                    case (ext_code)
                        5'h00: ;
                        5'h01: halted <= 1'b1;
                        5'h02: begin acc <= 8'd0; flag_z <= 1'b1; end
                        5'h03, 5'h04, 5'h05, 5'h06,
                        5'h07, 5'h08, 5'h09, 5'h0A: begin
                            acc <= alu_result; flag_z <= alu_zero; flag_c <= alu_carry;
                        end
                        5'h0B: pc <= acc;
                        5'h0C: begin
                            rf_we <= 1'b1; rf_waddr <= 3'd7;
                            rf_wdata <= pc + 8'd1;
                            pc <= acc;
                        end
                        5'h0D: begin
                            acc <= alu_result; flag_z <= alu_zero;
                        end
                        5'h0E: begin
                            rf_we <= 1'b1;
                            rf_waddr <= acc[2:0];
                            rf_wdata <= rf_rdata;
                        end
                        5'h0F: begin
                            acc <= rf_rdata;
                            rf_we <= 1'b1; rf_waddr <= 3'd6;
                            rf_wdata <= acc;
                        end
                        5'h10: begin acc <= io_in; flag_z <= (io_in == 8'd0); end
                        5'h11: io_out <= acc;
                        5'h12: io_dir <= acc;
                        5'h13: begin acc <= alu_result; end
                        default: ;
                    endcase
                end
            end
        endcase
    end
end
endmodule
`default_nettype wire
