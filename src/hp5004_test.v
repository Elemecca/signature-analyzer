`timescale 10ns / 1ns

`define assert_eq(expect, actual, desc) \
  if (actual == expect) $display("ok %s", desc);\
  else $display("not ok %s - expected %X got %X", desc, expect, actual);\

/* HP 3478A address bus.
 * input is an 8-bit binary counter
 * counts 00-FF (1024 cycles) once with start/stop high
 * then again with start/stop low, then repeat
 */
module test ();
  reg reset = 1'b1;
  reg clock = 1'b0;
  reg start = 1'b1;

  reg [7:0] addr = 0;
  reg [7:0] addr_bus = 8'hFF;

  wire [15:0] signature[7:0];

  genvar i;
  generate
    for (i = 0; i < 8; i = i + 1) begin
      sigan sigan (
        .reset(reset),
        .clock(!clock),
        .start(!start),
        .stop(!start),
        .data(addr_bus[i]),
        .signature(signature[i])
      );
    end
  endgenerate

  initial begin
    #100 reset = 0;
    #100 clock = 1;
    fork
      // generate clock
      forever begin // period 256
        #64 clock = 0;
        #192 clock = 1'b1;
      end

      // generate start/stop
      forever begin
        // 1024 cycles of effective 1 (always high), period 256
        #(1024 * 256);

        // 1024 cycles of effective 0 (low on clock falling edge)
        repeat (1024) begin // period 256
          #14 start = 0;
          #176 start = 1'b1;
          #66;
        end
      end

      // generate address bus
      forever begin // period 256
        #14 addr_bus = addr;
        #72 addr_bus = 8'hFF;
        #170 addr = addr + 1;
      end

      begin
        // four complete cycles
        #(4 * 2048 * 256);

        $display("1..8");
        `assert_eq(16'hD62F, signature[0], "1 A0");
        `assert_eq(16'hB21A, signature[1], "2 A1");
        `assert_eq(16'hDA07, signature[2], "3 A2");
        `assert_eq(16'hD0AA, signature[3], "4 A3");
        `assert_eq(16'hE030, signature[4], "5 A4");
        `assert_eq(16'h4442, signature[5], "6 A5");
        `assert_eq(16'h4F2A, signature[6], "7 A6");
        `assert_eq(16'h0772, signature[7], "8 A7");

        $finish;
      end
    join
  end
endmodule
