`default_nettype none
module regfile (
    input  wire       clk,
    input  wire       we,
    input  wire [2:0] raddr,
    input  wire [2:0] waddr,
    input  wire [7:0] wdata,
    output wire [7:0] rdata
);
reg [7:0] regs [0:7];
assign rdata = regs[raddr];
always @(posedge clk) begin
    if (we) begin
        regs[waddr] <= wdata;
    end
end
endmodule
`default_nettype wire
