/***************************************************************************************
* Copyright (c) 2020-2021 Institute of Computing Technology, Chinese Academy of Sciences
* Copyright (c) 2020-2021 Peng Cheng Laboratory
*
* XiangShan is licensed under Mulan PSL v2.
* You can use this software according to the terms and conditions of the Mulan PSL v2.
* You may obtain a copy of Mulan PSL v2 at:
*          http://license.coscl.org.cn/MulanPSL2
*
* THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
* EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
* MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
*
* See the Mulan PSL v2 for more details.
***************************************************************************************/

import "DPI-C" function void ram_write_helper
(
  input  longint    wIdx,
  input  longint    wdata,
  input  longint    wmask,
  input  bit        wen
);

import "DPI-C" function longint ram_read_helper
(
  input  bit        en,
  input  longint    rIdx
);

import "DPI-C" function longint ram_inst_helper
(
  input  bit        en,
  input  longint    rIdx
);


module RAMHelper(
  input         clk,
  input         ren,
  input  [63:0] rIdx,
  output [63:0] rdata,
  input  [63:0] wIdx,
  input  [63:0] wdata,
  input  [63:0] wmask,
  input         wen
);
  assign rdata = ram_read_helper(ren, rIdx);
  always @(posedge clk) begin
    ram_write_helper(wIdx, wdata, wmask, wen );
  end
endmodule

module ROMHelper(
  input         clk,
  input         ren,
  input  [63:0] rIdx,
  output [63:0] rdata
);
  assign rdata = ram_inst_helper(ren, rIdx);
endmodule
