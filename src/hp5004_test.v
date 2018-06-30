`timescale 10ns / 1ns

module main ();
  reg clock = 0;
  reg start = 1;
  reg stop  = 1;
  reg data  = 1;
  reg reset_l = 0;
  wire [15:0] signature;

  sigan sigan (
    .reset_l(reset_l),
    .clock(!clock),
    .start(!start),
    .stop(!stop),
    .data(data),
    .signature(signature)
  );

  initial begin
  end

  initial begin
    $dumpfile("test.vcd");
    $dumpvars(0, main);

    #100 reset_l = 1;
    #100 clock = 1;
    repeat (6) begin
      repeat (12) begin
        #14 {start, stop, data} = 0;
        #50 clock = 0;
        #22 data = 1'b1;
        #104 {start, stop} = 2'b11;
        #66 clock = 1'b1;
        #14 {start, stop} = 0;
        #50 clock = 0;
        #126 {start, stop} = 2'b11;
        #66 clock = 1'b1;
      end
      repeat (1012) begin
        #14 data = 0;
        #50 clock = 0;
        #22 data = 1'b1;
        #170 clock = 1'b1;
        #64 clock = 0;
        #192 clock = 1;
      end
    end

    $finish;
  end
endmodule
