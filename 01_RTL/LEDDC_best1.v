`timescale 1ns/10ps
module LEDDC( DCK, DAI, DEN, GCK, Vsync, mode, rst, OUT);
input           DCK;
input           DAI;
input           DEN;
input           GCK;
input           Vsync;
input           mode;
input           rst;
output reg [15:0]OUT;
// ------------------------------------------------------------
// parameter & genvar
// ------------------------------------------------------------
parameter IDLE     = 5'd17;
parameter CNT_15   = 5'd15;
parameter CNT_14   = 5'd14;
parameter CNT_13   = 5'd13;
parameter CNT_12   = 5'd12;
parameter CNT_11   = 5'd11;
parameter CNT_10   = 5'd10;
parameter CNT_9    = 5'd9;
parameter CNT_8    = 5'd8;
parameter CNT_7    = 5'd7;
parameter CNT_6    = 5'd6;
parameter CNT_5    = 5'd5;
parameter CNT_4    = 5'd4;
parameter CNT_3    = 5'd3;   
parameter CNT_2    = 5'd2;
parameter CNT_1    = 5'd1;
parameter CNT_0    = 5'd0;
parameter CNT_LAST = 5'd16;
parameter CNT_WAIT = 5'd18;

genvar i, j;



// ------------------------------------------------------------
// regs & wire
// ------------------------------------------------------------
reg  [15:0] cnt_pwm;
wire [16:0] cnt_pwm_w;
reg  [15:0] pxl_current[15:0];
reg  [15:0] pxl_nxt[15:0];
reg  pwm_sel;

reg [4:0]  cs;
reg cnt_round;

//----------------------------
//cnt

//--------------------
// parameter 
//--------------------
localparam I_IDLE   = 2'b00;
localparam I_INPUT  = 2'b01;
localparam I_SRAM_W = 2'b10;
localparam I_END    = 2'b11;
reg [1:0] c_state, n_state;

//--------------------
// wire & reg cao 
//--------------------
reg [15:0] in_data;
wire[15:0] in_data_w;

//--------------------
// SRAM write 
wire[1:0]sram_wflag;
reg  sel_SRAM_flag;
reg [8:0]scan_cnt;
wire[9:0]scan_cnt_w;
wire scan_eof;
//--------------------
// SRAM read 
localparam CI_IDLE      = 2'b00;
localparam CI_SRAM_READ = 2'b01;
localparam CI_SRAM_WAIT = 2'b10;
localparam CI_WAIT      = 2'b11;
reg [1:0]ci_state, ni_state;

reg round;
reg  sel_RSRAM_flag;
wire[1:0]sram_rflag;
wire[15:0]sram_data0, sram_data1;
reg [8:0]read_cnt;
wire[9:0]read_cnt_w;
wire read_eof;
//reg [15:0]next_buf[15:0];
wire[15:0]sel_data;
//--------------------
// GCK domain

//--------------------
// SRAM read block

always@(posedge GCK, posedge rst) begin
	if(rst)begin
		round <= 1'b0;
	end else begin 
		if(read_cnt ==9'd0 && ci_state == CI_SRAM_WAIT)
			round <= ~round;
		else
			round <= round;
	end
end


always@(posedge GCK, posedge rst) begin
	if(rst)begin
		sel_RSRAM_flag <= 1'b1;
	end else begin 
		if(read_cnt ==9'd0 && (round || ~mode) && ci_state == CI_SRAM_WAIT)
			sel_RSRAM_flag <= ~sel_RSRAM_flag;
		else
			sel_RSRAM_flag <= sel_RSRAM_flag;
	end
end

always@(posedge GCK, posedge rst) begin
	if(rst)begin
		ci_state <= CI_IDLE;
	end else begin 
		ci_state <= ni_state;
	end
end

always@(*) begin
     case(ci_state)
	 CI_IDLE:  if(Vsync) ni_state = CI_SRAM_READ;
			   else 	 ni_state = CI_IDLE;
	 CI_SRAM_READ: if(read_cnt[3:0] == 4'hf) ni_state = CI_SRAM_WAIT;
			       else	  					 ni_state = CI_SRAM_READ;
	 CI_SRAM_WAIT: ni_state = CI_WAIT;
	 CI_WAIT: if(!Vsync) ni_state = CI_IDLE;
			  else		 ni_state = CI_WAIT;
     default: ni_state = CI_IDLE;
     endcase
end

assign read_eof = read_cnt_w[9];
assign read_cnt_w = read_cnt + 1;
always@(posedge GCK, posedge rst) begin
	if(rst)begin
		read_cnt <= 16'd16;
	end else begin 
		if(ci_state == CI_SRAM_READ)
			read_cnt <= read_cnt_w[8:0];		
		else
			read_cnt <= read_cnt;
	end
end

always@(posedge GCK, posedge rst) begin
	if(rst)begin
		pxl_nxt[15] <= 16'd0;
	end else begin 
		if(ci_state == CI_SRAM_READ || ci_state == CI_SRAM_WAIT)
			pxl_nxt[15] <= sel_data;
		else
			pxl_nxt[15] <= pxl_nxt[15];
	end
end

generate 
for(i = 0; i < 15; i = i + 1)begin
	always@(posedge GCK, posedge rst) begin
		if(rst)begin
			pxl_nxt[i] <= 16'd0;
		end else begin 
			if(ci_state == CI_SRAM_READ || ci_state == CI_SRAM_WAIT)
				pxl_nxt[i] <= pxl_nxt[i + 1];
			else
				pxl_nxt[i] <= pxl_nxt[i];
		end
	end
end
endgenerate

assign sram_wflag = (c_state == I_SRAM_W)? ((sel_SRAM_flag)? 2'b01 : 2'b10) : 2'b11;

assign sel_data = (sel_RSRAM_flag)?sram_data1 : sram_data0;
assign sram_rflag = 2'b0;
sram_512x16 u0(.QA(sram_data0), .AA(read_cnt), .CLKA(GCK), .CENA(sram_rflag[0]), .AB(scan_cnt), .DB(in_data), .CLKB(DCK), .CENB(sram_wflag[0]));
sram_512x16 u1(.QA(sram_data1), .AA(read_cnt), .CLKA(GCK), .CENA(sram_rflag[1]), .AB(scan_cnt), .DB(in_data), .CLKB(DCK), .CENB(sram_wflag[1]));

//--------------------
// DCK domain
always@(posedge DCK, posedge rst) begin
	if(rst)begin
		c_state <= I_IDLE;
	end else begin 
		c_state <= n_state;
	end
end

always@(*) begin
     case(c_state)
	 I_IDLE:  if(DEN) n_state = I_INPUT;
			  else 	  n_state = I_IDLE;
	 I_INPUT: if(!DEN)n_state = I_SRAM_W;
			  else	  n_state = I_INPUT;
	 I_SRAM_W:n_state = I_IDLE;
     default: n_state = I_IDLE;
     endcase
end
//------------------
//in data
assign in_data_w = {DAI, in_data[15:1]};

always@(posedge DCK, posedge rst) begin
	if(rst)begin
		sel_SRAM_flag <= 6'd0;
	end else begin 
		if(c_state == I_SRAM_W && scan_eof)
			sel_SRAM_flag <= ~sel_SRAM_flag;
		else
			sel_SRAM_flag <= sel_SRAM_flag;
	end
end

assign scan_eof = scan_cnt_w[9];
assign scan_cnt_w = scan_cnt + 1;
always@(posedge DCK, posedge rst) begin
	if(rst)begin
		scan_cnt <= 6'd0;
	end else begin 
		if(c_state == I_SRAM_W)
			scan_cnt <= scan_cnt_w[8:0];
		else
			scan_cnt <= scan_cnt;
	end
end

always@(posedge DCK, posedge rst) begin
	if(rst)begin
		in_data <= 16'd0;
	end else begin 
		if(DEN)
			in_data <= in_data_w;
		else if(c_state == I_SRAM_W)
			in_data <= 16'd0;
		else 
			in_data <= in_data;
	end
end

// ------------------------------------------------------------
// henry
// ------------------------------------------------------------
// ------------------------------------------------------------
// design
// ------------------------------------------------------------

always @(posedge GCK or posedge rst) begin
	if (rst) cs <= IDLE;
	else begin
		case (cs)
			IDLE :  cs <= (Vsync) ? ((mode) ? CNT_14 : CNT_15) : IDLE;
			CNT_15: cs <= (pwm_sel) ? CNT_14   : CNT_15;
			CNT_14: cs <= (pwm_sel) ? CNT_13   : CNT_14; 
			CNT_13: cs <= (pwm_sel) ? CNT_12   : CNT_13;
			CNT_12: cs <= (pwm_sel) ? CNT_11   : CNT_12;
			CNT_11: cs <= (pwm_sel) ? CNT_10   : CNT_11;
			CNT_10: cs <= (pwm_sel) ? CNT_9    : CNT_10;
			CNT_9:  cs <= (pwm_sel) ? CNT_8    : CNT_9;
			CNT_8:  cs <= (pwm_sel) ? CNT_7    : CNT_8;
			CNT_7:  cs <= (pwm_sel) ? CNT_6    : CNT_7;
			CNT_6:  cs <= (pwm_sel) ? CNT_5    : CNT_6;
			CNT_5:  cs <= (pwm_sel) ? CNT_4    : CNT_5;
			CNT_4:  cs <= (pwm_sel) ? CNT_3    : CNT_4;
			CNT_3:  cs <= (pwm_sel) ? CNT_2    : CNT_3;
			CNT_2:  cs <= (pwm_sel) ? CNT_1    : CNT_2;
			CNT_1:  cs <= (pwm_sel) ? CNT_0    : CNT_1;
			CNT_0:  cs <= (pwm_sel) ? CNT_LAST : CNT_0;
			CNT_LAST: cs <= CNT_WAIT;
			CNT_WAIT: cs <= IDLE;
			default:  cs <= IDLE;
		endcase
	end
end


always @(posedge GCK or posedge rst) begin
	if (rst) cnt_pwm <= 16'd0;
	else	 
		if(Vsync)
			cnt_pwm <= (pwm_sel) ? 16'd0 : cnt_pwm_w[15:0];
		else
			cnt_pwm <= 16'd0;
end
/*
always @(posedge GCK or posedge rst) begin
	if (rst) cnt_round <= 1'b0;
	else 	 cnt_round <= (cs == CNT_LAST && round) ? !cnt_round : cnt_round;
end
*/

always @(posedge GCK or posedge rst) begin
	if (rst) cnt_round <= 1'b0;
	else 	 cnt_round <= (read_cnt == 9'h10 && cs == CNT_LAST) ? ~cnt_round : cnt_round;
end
assign cnt_pwm_w = cnt_pwm + 16'd1;
always @(*) begin
	case (cs)
		CNT_15: pwm_sel <= (cnt_pwm_w[15]);
		CNT_14: pwm_sel <= (cnt_pwm_w[14]); 
		CNT_13: pwm_sel <= (cnt_pwm_w[13]);
		CNT_12: pwm_sel <= (cnt_pwm_w[12]);
		CNT_11: pwm_sel <= (cnt_pwm_w[11]);
		CNT_10: pwm_sel <= (cnt_pwm_w[10]);
		CNT_9:  pwm_sel <= (cnt_pwm_w[9]);
		CNT_8:  pwm_sel <= (cnt_pwm_w[8]);
		CNT_7:  pwm_sel <= (cnt_pwm_w[7]);
		CNT_6:  pwm_sel <= (cnt_pwm_w[6]);
		CNT_5:  pwm_sel <= (cnt_pwm_w[5]);
		CNT_4:  pwm_sel <= (cnt_pwm_w[4]);
		CNT_3:  pwm_sel <= (cnt_pwm_w[3]);
		CNT_2:  pwm_sel <= (cnt_pwm_w[2]);
		CNT_1:  pwm_sel <= (cnt_pwm_w[1]);
		CNT_0:  pwm_sel <= (cnt_pwm_w[0]);
		default:  pwm_sel <= 1'b0;
	endcase
end

generate 
for (i = 0; i < 16; i = i + 1) begin
	for (j = 0; j < 16; j = j + 1) begin
		if (j == 0) begin
			always @(posedge GCK or posedge rst) begin
				if (rst) 	     pxl_current[i][j] <= 1'b0;
				else if (cs == CNT_WAIT) pxl_current[i][j] <= (~cnt_round && mode) ?pxl_nxt[i][0] : 1'b0 ;
				else 	 	     pxl_current[i][j] <= pxl_current[i][j];
			end
		end
		else begin
			always @(posedge GCK or posedge rst) begin
				if (rst) 			 			pxl_current[i][j] <= 1'd0;
				else if (cs == CNT_WAIT)     			pxl_current[i][j] <= pxl_nxt[i][j];
 				else if (cs != IDLE && pwm_sel) pxl_current[i][j] <= pxl_current[i][j - 1];
				else 	 			 			pxl_current[i][j] <= pxl_current[i][j];
			end
		end
	end

end
endgenerate


generate 
for (i = 0; i < 16; i = i + 1) begin
	always @(*) begin
		if (rst) OUT[i] = 1'b0;
		else  	 OUT[i] = (Vsync) ? pxl_current[i][15] : 1'b0;
	end
end
endgenerate


endmodule
