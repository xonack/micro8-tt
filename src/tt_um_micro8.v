`default_nettype none
module tt_um_micro8 (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);
    wire [7:0] prog_addr;
    wire [7:0] io_out_w;
    wire [7:0] io_dir_w;

    micro8_core u_core (
        .clk       (clk),
        .rst_n     (rst_n),
        .ena       (ena),
        .prog_addr (prog_addr),
        .prog_data (ui_in),
        .io_in     (uio_in),
        .io_out    (io_out_w),
        .io_dir    (io_dir_w)
    );

    assign uo_out  = prog_addr;
    assign uio_out = io_out_w;
    assign uio_oe  = io_dir_w;
endmodule
`default_nettype wire
