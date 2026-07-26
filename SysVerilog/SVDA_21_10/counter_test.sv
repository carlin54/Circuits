///////////////////////////////////////////////////////////////////////////
// (c) Copyright 2013 Cadence Design Systems, Inc. All Rights Reserved.
//
// File name   : counter_test.sv
// Title       : Counter Testbench Module
// Project     : SystemVerilog Training
// Created     : 2013-4-8
// Description : Defines the Counter testbench module
// Notes       :
//
///////////////////////////////////////////////////////////////////////////

module counter_test;

timeunit 1ns;
timeprecision 100ps;

logic          reset;
logic          load;
logic          enable;
logic  [4:0]   data;
logic  [4:0]   count ;

`define PERIOD 10
logic clk = 1'b1;

always
    #(`PERIOD/2) clk = ~clk;


// counter instance
counter  cnt1     ( .count(count), .data(data), .clk(clk), .load(load), .enable(enable), .reset(reset));

  // Monitor Results

  initial
    begin
      $timeformat ( -9, 0, "ns", 6 );
      $monitor ( "time=%t clk=%b reset=%b load=%b enable=%b data=%h count=%h",
 	         $time,   clk,   reset,   load,   enable,   data,   count );
      #(`PERIOD * 99)
      $display ( "COUNTER TEST TIMEOUT" );
      $finish;
    end


  // Verify Results

  task expect_test;
  input [4:0] expects;
    if ( count !== expects )
      begin
        $display ( "count=%b should be %b", count, expects );
        $display ( "COUNTER TEST FAILED" );
        $finish;
      end
  endtask


  initial
    begin
      @ ( negedge clk )
       // check reset
      { reset, load, enable, data } = 8'b0_X_X_XXXXX; @(negedge clk) expect_test ( 5'h00 );
       // count 4 enabled cycles
      { reset, load, enable, data } = 8'b1_0_1_XXXXX; @(negedge clk) expect_test ( 5'h01 );
      { reset, load, enable, data } = 8'b1_0_1_XXXXX; @(negedge clk) expect_test ( 5'h02 );
      { reset, load, enable, data } = 8'b1_0_1_XXXXX; @(negedge clk) expect_test ( 5'h03 );
      { reset, load, enable, data } = 8'b1_0_1_XXXXX; @(negedge clk) expect_test ( 5'h04 );
       // check disabled
      { reset, load, enable, data } = 8'b1_0_0_XXXXX; @(negedge clk) expect_test ( 5'h04 );
      { reset, load, enable, data } = 8'b1_0_0_XXXXX; @(negedge clk) expect_test ( 5'h04 );
       // check load
      { reset, load, enable, data } = 8'b1_1_0_10101; @(negedge clk) expect_test ( 5'h15 );
       // check load and enable (load should have precedence)
      { reset, load, enable, data } = 8'b1_1_1_11101; @(negedge clk) expect_test ( 5'h1D );
       // count from load
      { reset, load, enable, data } = 8'b1_0_1_XXXXX; @(negedge clk) expect_test ( 5'h1E );
      { reset, load, enable, data } = 8'b1_0_1_XXXXX; @(negedge clk) expect_test ( 5'h1F );
       // check roll-over count
      { reset, load, enable, data } = 8'b1_0_1_XXXXX; @(negedge clk) expect_test ( 5'h00 );
      { reset, load, enable, data } = 8'b1_0_1_XXXXX; @(negedge clk) expect_test ( 5'h01 );
      $display ( "COUNTER TEST PASSED" );
      $finish;
    end
endmodule
