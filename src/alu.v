`default_nettype none
module alu (
    input  wire [7:0] a,
    input  wire [7:0] b,
    input  wire       carry_in,
    input  wire [3:0] op,
    output reg  [7:0] result,
    output reg        carry_out,
    output wire       zero
);
localparam OP_ADD  = 4'd0;
localparam OP_SUB  = 4'd1;
localparam OP_AND  = 4'd2;
localparam OP_OR   = 4'd3;
localparam OP_XOR  = 4'd4;
localparam OP_PASS = 4'd5;
localparam OP_NOT  = 4'd6;
localparam OP_NEG  = 4'd7;
localparam OP_INC  = 4'd8;
localparam OP_DEC  = 4'd9;
localparam OP_SHL  = 4'd10;
localparam OP_SHR  = 4'd11;
localparam OP_ROL  = 4'd12;
localparam OP_ROR  = 4'd13;
localparam OP_LUI  = 4'd14;
localparam OP_PASA = 4'd15;
always @(*) begin
    carry_out = 1'b0;
    case (op)
        OP_ADD: begin {carry_out, result} = a + b; end
        OP_SUB: begin {carry_out, result} = {1'b0, a} - {1'b0, b}; carry_out = (a < b); end
        OP_AND: begin result = a & b; end
        OP_OR:  begin result = a | b; end
        OP_XOR: begin result = a ^ b; end
        OP_PASS: begin result = b; end
        OP_NOT: begin result = ~a; end
        OP_NEG: begin result = (~a) + 8'd1; carry_out = (a != 8'd0); end
        OP_INC: begin {carry_out, result} = a + 9'd1; end
        OP_DEC: begin result = a - 8'd1; carry_out = (a == 8'd0); end
        OP_SHL: begin carry_out = a[7]; result = {a[6:0], 1'b0}; end
        OP_SHR: begin carry_out = a[0]; result = {1'b0, a[7:1]}; end
        OP_ROL: begin carry_out = a[7]; result = {a[6:0], carry_in}; end
        OP_ROR: begin carry_out = a[0]; result = {carry_in, a[7:1]}; end
        OP_LUI: begin result = {a[2:0], 5'b00000}; end
        OP_PASA: begin result = a; end
        default: begin result = 8'd0; end
    endcase
end
assign zero = (result == 8'd0);
endmodule
`default_nettype wire
