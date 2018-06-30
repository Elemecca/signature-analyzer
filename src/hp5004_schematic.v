`default_nettype none


module sigan (
  input reset_l,
  input clock,
  input start,
  input stop,
  input data,
  output reg [15:0] signature,
  output unstable,
  output gate
);
  parameter service = 0;
  wire reset_h = !reset_l;
  wire data_latch;
  wire word_gate, clk_gate;
  wire word_reset_l, word_clk;
  wire [15:0] word;

  gate_con #(.service(service)) gate_con (
    .reset_l(reset_l),
    .clk(clock),
    .start(start),
    .stop(stop),
    .hold(1'b0),
    .dis(1'b0),
    .word_gate(word_gate),
    .clk_gate(clk_gate)
  );

  // synchronize input data to input clock - replaces U9
  // The original board uses a JK flip-flop here because it has
  // separate inputs for low and high data values. We have a single
  // input, so we use a D flip-flop instead.
  flop_d #(.reset_val(1)) u9 (
    .reset_l(reset_l),
    .clk(clock),
    .d(data),
    .q(data_latch)
  );

  nor u7b (word_reset_l, word_gate, reset_h);
  nand u11c (word_clk, clk_gate, !clock);

  word_gen #(.service(service)) word_gen (
    .reset_l(word_reset_l),
    .clk(word_clk),
    .in(data_latch),
    .out(word)
  );

  assign unstable = 0;
  assign gate = clk_gate;

  // latch the output word - replaces U13, U14, U15, U16
  // The original board uses 4x 4-bit latches with 3-state outputs
  // driving a shared bus into the 7-segment character decoder.
  initial signature = 0;
  always @(posedge word_gate, posedge reset_h) begin
    if (reset_h) signature <= 0;
    else signature <= word;
  end
endmodule


module gate_con (
  input reset_l,
  input clk,
  input start,
  input stop,
  input hold,
  input dis,
  input test1,
  input test2,
  output word_gate,
  output clk_gate
);
  parameter service = 0;
  wire stop_buf, stop_buf_l;
  wire start_buf, start_buf_l;
  wire y1, y2, y4, y4_l, y5, y6, y7;
  wire loopback;

  flop_d u1a (
    .d(stop),
    .q(stop_buf),
    .q_l(stop_buf_l),
    .clk(clk),
    .reset_l(reset_l)
  );

  flop_d u1b (
    .d(start),
    .q(start_buf),
    .q_l(start_buf_l),
    .clk(clk),
    .reset_l(reset_l)
  );

  // S7A - normal/service switch
  generate
    if (service) assign y1 = test1;
    else begin :u1
      wire c1, c2, c3, c4;
      and (c1, start_buf_l, y2);
      and (c2, start_buf_l, stop_buf);
      and (c3, stop_buf, y4);
      and (c4, loopback);
      nor (y1, c1, c2, c3, c4);
    end
  endgenerate

  flop_d u1c (
    .d(y1),
    .q_l(y2),
    .clk(clk),
    .reset_l(reset_l)
  );

  // S7B - normal/service switch
  generate
    if (service) assign clk_gate = test2;
    else begin :u4
      wire c1, c2, c3, c4;
      and (c1, stop_buf_l, y2);
      and (c2, y2, y4_l);
      and (c3, start_buf, y4_l);
      and (c4, loopback);
      nor (clk_gate, c1, c2, c3, c4);
    end
  endgenerate

  flop_d u1d (
    .d(clk_gate),
    .q(y4),
    .q_l(y4_l),
    .clk(clk),
    .reset_l(reset_l)
  );

  nand u5a (y5, y2, !clk, stop_buf_l, y4);
  nand u5b (y6, y4, y2, stop_buf_l, hold);
  nand u8a (y7, hold, loopback);
  nand u8b (loopback, y6, y7);
  nor  u7c (word_gate, y5, dis);
endmodule


module word_gen (
  output [15:0] out,
  input in,
  input clk,
  input reset_l
);
  parameter service = 0;
  wire feedback;

  // U21
  shift_reg sreg_low (
    .clk(clk),
    .reset_l(reset_l),
    .a(feedback),
    .b(feedback),
    .q(out[7:0])
  );

  // U24
  shift_reg sreg_high (
    .clk(clk),
    .reset_l(reset_l),
    .a(out[7]),
    .b(out[7]),
    .q(out[15:8])
  );

  // S7C - normal/service switch
  generate
    if (service) assign feedback = in;
    else begin
      // U6
      parity_gen feedback_gen (
        .p({in, out[6], out[8], out[11], out[15], 4'b1111}),
        .inhibit(1'b0),
        .odd(feedback)
      );
    end
  endgenerate
endmodule




/** TI SN74LS175N D flip-flop, positive edge trigger. */
module flop_d (
  output reg q,
  output q_l,
  input d,
  input clk,
  input reset_l
);
  parameter reset_val = 0;
  initial q = reset_val;
  always @(posedge clk, negedge reset_l) begin
    if (!reset_l) q <= reset_val;
    else q <= d;
  end
  assign q_l = !q;
endmodule


/** TI SN74LS164N 8-bit shift register, serial in, parallel out. */
module shift_reg (
  output reg [7:0] q,
  input a,
  input b,
  input clk,
  input reset_l
);
  initial q = 0;
  always @(posedge clk, negedge reset_l) begin
    if (!reset_l) q <= 0;
    else q <= {q[6:0], a & b};
  end
endmodule


/** Signetics N82S62A 8-bit even/odd parity generator. */
module parity_gen (
  output odd,
  output even,
  input [9:1] p,
  input inhibit
);
  wire [9:1] pn = ~p;
  wire y0, y1, y2, y3, y4, y5, y6, y7;


  xnor (y0, pn[1], pn[2]);
  xnor (y1, pn[3], pn[4]);
  xnor (y2, pn[5], pn[6]);
  xnor (y3, pn[7], pn[8]);
  xnor (y4, y0, y1);
  xnor (y5, y2, y3);
  xnor (y6, y4, y5);
  xnor (y7, y6, pn[9]);

  nor (odd, y7, inhibit);
  nor (even, odd, inhibit);
endmodule
