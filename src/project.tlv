\m5_TLV_version 1d: tl-x.org
\m5
   /**
   This template is for developing Tiny Tapeout designs using Makerchip.
   Verilog, SystemVerilog, and/or TL-Verilog can be used.
   Use of Tiny Tapeout Demo Boards (as virtualized in the VIZ tab) is supported.
   See the corresponding Git repository for build instructions.
   **/

   use(m5-1.0)  // See M5 docs in Makerchip IDE Learn menu.
   //define_hier(XREG, 16)
   ///define_hier(XREG, 16)

   // ---SETTINGS---
   var(my_design, tt_um_example)  /// Change tt_um_example to tt_um_<your-github-username>_<name-of-your-project>. (See README.md.)
   var(debounce_inputs, 0)
                     /// Legal values:
                     ///   1: Provide synchronization and debouncing on all input signals.
                     ///   0: Don't provide synchronization and debouncing.
                     ///   m5_if_defined_as(MAKERCHIP, 1, 0, 1): Debounce unless in Makerchip.
   // --------------

   // If debouncing, your top module is wrapped within a debouncing module, so it has a different name.
   var(user_module_name, m5_if(m5_debounce_inputs, my_design, m5_my_design))
   var(debounce_cnt, m5_if_defined_as(MAKERCHIP, 1, 8'h03, 8'hff))
\SV
   // Include Tiny Tapeout Lab.
   m4_include_lib(['https:/']['/raw.githubusercontent.com/os-fpga/Virtual-FPGA-Lab/5744600215af09224b7235479be84c30c6e50cb7/tlv_lib/tiny_tapeout_lib.tlv'])
   ///m5_define_hier(IMEM, 11)
\TLV imem(@_stage)
   // Instruction Memory containing program.
   @_stage
      \SV_plus
         logic [7:0] instrs [10:0];
         initial begin
             instrs[0] = 8'hC7; // Custom 8-bit data for instruction 0
             instrs[1] = 8'h12; // Custom 8-bit data for instruction 1
             instrs[2] = 8'hC0; // Custom 8-bit data for instruction 2
             instrs[3] = 8'h34;
             instrs[4] = 8'hC1;
             instrs[5] = 8'h12;
             instrs[6] = 8'hC4;
             instrs[7] = 8'hf0;
             instrs[8] = 8'hC5;
             instrs[9] = 8'hC6;
             instrs[10] = 8'hFF;
             instrs[10] = 8'h82;
             instrs[10] = 8'hFF;// Custom data for instruction 10
         end
      $imem_rd_data[7:0] = *instrs\[$imem_rd_addr\];
// A 2-rd 1-wr register file in |cpu that reads and writes in the given stages. If read/write stages are equal, the read values reflect previous writes.
// Reads earlier than writes will require bypass.
\TLV rf(@_rd, @_wr)
   // Reg File
   @_wr
      /xreg[15:0]
         $wr = (|cpu$rf_wr_index == #xreg);
         $value[7:0] = |cpu$reset ?   #xreg           :
                        $wr        ?   |cpu$rf_wr_data :
                                       $RETAIN;
   @_rd
      $rf_rd_data1[7:0] = /xreg[$rf_rd_index1[3:0]]>>m4_stage_eval(@_wr - @_rd + 1)$value;
      $rf_rd_data2[7:0] = /xreg[$rf_rd_index2[3:0]]>>m4_stage_eval(@_wr - @_rd + 1)$value;
      //`BOGUS_USE($rf_rd_data1 $rf_rd_data2)
\TLV dmem(@_stage)
   // Data Memory
   @_stage
      /dmem[15:0]
         $wr = (|cpu$dmem_addr[3:0] == #dmem);
         $value[7:0] = |cpu$reset ?   #dmem :
                        $wr        ?   |cpu$dmem_wr_data :
                                       $RETAIN;
                                  
      $dmem_rd_data[7:0] = /dmem[$dmem_addr[3:0]]>>1$value;
      `BOGUS_USE($dmem_rd_data)
\TLV my_design()
   |cpu
      @1 
         $reset = *reset;
         $start = >>1$reset && !$reset;
         $pc[3:0] =
               >>1$reset
                   ? 4'd0 :
                   >>1$pc_inc[3:0];
         $imem_rd_addr[3:0] = $pc[3:0];
         $instr[7:0] = $imem_rd_data;
         //decoder
         $is_alu =  $instr_vaid && ($instr[7] == 1'b0);//operations involve ALU logic                 //done
         $is_store = $instr_vaid && ($instr[7:4] == 4'b1000);//store A into register m[r] = A         //done
         $is_br_link = $instr_vaid && ($instr[7:4] == 4'b1001);//branch and link m[r] = PC, PC = A    //done
         $is_load_lm = $instr_vaid && ($instr[7:4] == 4'b1010);//load indirect A = m[m[r]]            //done
         $is_store_lm = $instr_vaid && ($instr[7:4] == 4'b1011);     //store indirect m[m[r]] = A          //done
         $is_alu_lm = $instr_vaid && ($instr[7:4] == 4'b1100);//ALU immediate A = A f n               //done
         $is_branch = $instr_vaid && ($instr[7:4] == 4'b1101);//branch                                //done
         $en_shift = $instr_vaid && ($instr[7:4] == 4'b1110);// ALU shift A = shift(A)                //
         $is_exit = $instr_vaid && ($instr[7:4] == 4'b1111);//exit for the tester PC = PC             //done
         //finding whether is a valid instruction or not
         $instr_vaid = $start || !(>>1$instr[7:5] == 3'b110);
         $rd[3:0] = $instr[3:0];
         //ALU operators
         $rf_rd_index1[3:0] = 4'b0000;
         $rf_rd_index2[3:0] = $rd;
         $acc[7:0] = $rf_rd_data1;
         $op[7:0] = $rf_rd_data2;
         
         $imm[7:0] = $instr_vaid ? $op[7:0]:$instr[7:0];
         
         $branch_true = !$is_branch
                               ? 1'b0 :
                        ($instr[1:0] == 2'b00
                               ? 1'b1 :
                        $instr[1:0] == 2'b10
                               ? $acc == $imm[7:0] :
                        $instr[1:0] == 2'b11
                               ? $acc != $imm[7:0] : 1'b0);
         
      @2
         $pc_inc[3:0] = $is_exit
                            ? $pc :
                        $is_br_link
                            ? $acc[3:0] :
                        ($instr_vaid || >>1$is_alu_lm)
                            ? $pc + 4'd1 :
                        $branch_true
                            ? $imm[3:0] :
                              $pc ;
         $dmem_addr[3:0] = $imm[3:0];
         /* verilator lint_off WIDTHEXPAND */
         {$c,$result[7:0]} = $reset
                                     ? {1'b0,8'b0} :
                             $is_load_lm
                                     ?  $dmem_rd_data[7:0] :
                             ($is_store)
                                     ? $acc :
                             $en_shift
                                     ? ($instr[1:0] == 2'b00 ? {$acc[7:0],$c} : $instr[1:0] == 2'b01 ? {$acc[0],$c,$acc[7:1]} : $instr[1:0] == 2'b10 ? {$c,$acc[6:0],$acc[7]} : {$c,$acc[0],$acc[7:1]}) :
                             !($is_alu || $is_alu_lm)
                                     ? {$c,$acc[7:0]} :
                                    (($instr[6:4] | $instr[2:0]) == 3'b000 ? $acc + <<1$imm[7:0] :
                                    ($instr[6:4] | $instr[2:0]) == 3'b001 ? $acc - <<1$imm[7:0] :
                                    ($instr[6:4] | $instr[2:0]) == 3'b010 ? $acc + <<1$imm[7:0] + $c :
                                    ($instr[6:4] | $instr[2:0]) == 3'b011 ? $acc - <<1$imm[7:0] - $c :
                                    ($instr[6:4] | $instr[2:0]) == 3'b100 ? $acc & <<1$imm[7:0] :
                                    ($instr[6:4] | $instr[2:0]) == 3'b101 ? $acc | <<1$imm[7:0]:
                                    ($instr[6:4] | $instr[2:0]) == 3'b110 ? $acc ^ <<1$imm[7:0] : 
                                    ($instr[6:4] | $instr[2:0]) == 3'b111 ? <<1$imm[7:0] : <<1$imm[7:0]);
         /* verilator lint_on WIDTHEXPAND */
         //$dmem_wr_data[7:0] = $acc[7:0];
         $rf_wr_index[3:0] = ($is_store || $is_br_link) ? $rf_rd_index2 : 4'b0000;
         $rf_wr_data[7:0] =  !$is_br_link
                                ? $pc :
                              !$branch_true
                                ? $result[7:0] :
                                      $result[7:0];
         
         
      //$accumulator = $
      m5+imem(@1)
      m5+rf(@1,@2)
      m5+dmem(@2)

\SV


// ================================================
// A simple Makerchip Verilog test bench driving random stimulus.
// Modify the module contents to your needs.
// ================================================

module top(input logic clk, input logic reset, input logic [31:0] cyc_cnt, output logic passed, output logic failed);
   // Tiny tapeout I/O signals.
   logic [7:0] ui_in, uio_in, uo_out, uio_out, uio_oe;
   logic [31:0] r;
   always @(posedge clk) r = m5_if_defined_as(MAKERCHIP, 1, ['$urandom()'], ['0']);
   assign ui_in = r[7:0];
   assign uio_in = r[15:8];
   logic ena = 1'b0;
   logic rst_n = ! reset;

   /*
   // Or, to provide specific inputs at specific times...
   // BE SURE TO COMMENT THE ASSIGNMENT OF INPUTS ABOVE.
   // BE SURE TO DRIVE THESE ON THE B-PHASE OF THE CLOCK (ODD STEPS).
   // Driving on the rising clock edge creates a race with the clock that has unpredictable simulation behavior.
   initial begin
      #1  // Drive inputs on the B-phase.
         ui_in = 8'h0;
      #10 // Step past reset.
         ui_in = 8'hFF;
      // ...etc.
   end
   */

   // Instantiate the Tiny Tapeout module.
   m5_user_module_name tt(.*);

   assign passed = cyc_cnt > 100;
   assign failed = 1'b0;
endmodule

// Provide a wrapper module to debounce input signals if requested.
m5_if(m5_debounce_inputs, ['m5_tt_top(m5_my_design)'])
// The above macro expands to multiple lines. We enter a new \SV block to reset line tracking.
\SV


// The Tiny Tapeout module.
module m5_user_module_name (
    input  wire [7:0] ui_in,    // Dedicated inputs - connected to the input switches
    output wire [7:0] uo_out,   // Dedicated outputs - connected to the 7 segment display
    input  wire [7:0] uio_in,   // IOs: Bidirectional Input path
    output wire [7:0] uio_out,  // IOs: Bidirectional Output path
    output wire [7:0] uio_oe,   // IOs: Bidirectional Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // will go high when the design is enabled
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

   wire reset = ! rst_n;

\TLV
   /* verilator lint_off UNOPTFLAT */
   // Connect Tiny Tapeout I/Os to Virtual FPGA Lab.
   m5+tt_connections()
   // Instantiate the Virtual FPGA Lab.
   m5+board(/top, /fpga, 7, $, , my_design)
   // Label the switch inputs [0..7] (1..8 on the physical switch panel) (bottom-to-top).
   m5+tt_input_labels_viz(['"UNUSED", "UNUSED", "UNUSED", "UNUSED", "UNUSED", "UNUSED", "UNUSED", "UNUSED"'])

\SV_plus

   // =========================================
   // If you are using (System)Verilog for your design,
   // your Verilog logic goes here.
   // =========================================

   // ...


   // Connect Tiny Tapeout outputs.
   // Note that my_design will be under /fpga_pins/fpga.
   // Example *uo_out = /fpga_pins/fpga|my_pipe>>3$uo_out;
   //assign *uo_out = 8'b0;
   //assign *uio_out = 8'b0;
   assign *uio_oe = 8'b0;

endmodule

