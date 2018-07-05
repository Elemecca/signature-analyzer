`default_nettype none

module sigan (
  input reset,
  input clock,
  input start,
  input stop,
  input data,
  output reg [15:0] signature
);
  localparam INITIAL = 2'b00;
  localparam ARMED   = 2'b01;
  localparam RUN_W   = 2'b11;
  localparam RUN     = 2'b10;

  reg [1:0] gate_state;
  wire word_gate, word_reset;
  reg [15:0] word;

  always @(posedge clock, posedge reset) begin
    if (reset) gate_state = INITIAL;
    else case (gate_state)
      INITIAL: casex ({start, stop})
        2'b0x: gate_state = ARMED;
      endcase
      ARMED: casex ({start, stop})
        2'b10: gate_state = RUN;
        2'b11: gate_state = RUN_W;
      endcase
      RUN_W: casex ({start, stop})
        2'bx0: gate_state = RUN;
      endcase
      RUN: casex ({start, stop})
        2'b01: gate_state = ARMED;
        2'b11: gate_state = INITIAL;
      endcase
    endcase
  end

  assign word_gate = (gate_state == RUN || gate_state == RUN_W);
  assign word_reset = (!word_gate || reset);

  // word generator - linear feedback shift register
  initial word = 0;
  always @(posedge clock, posedge word_reset) begin
    if (word_reset) word <= 0;
    else begin
      word[15:1] <= word[14:0];
      word[0] <= ^{data, word[6], word[8], word[11], word[15]};
    end
  end

  // latch the output word
  initial signature = 0;
  always @(negedge word_gate, posedge reset) begin
    if (reset) signature <= 0;
    else signature <= word;
  end
endmodule


module gate_con (
  input reset_l,
  input clock,
  input start,
  input stop,
  output word_gate,
  output clock_gate
);

endmodule
