`timescale 1ns/10ps
module LEDDC( DCK, DAI, DEN, GCK, Vsync, mode, rst, OUT);
input           DCK;
input           DAI;
input           DEN;
input           GCK;
input           Vsync;
input           mode;
input           rst;
output [15:0]   OUT;

//--------------------
// parameter 
//--------------------
localparam I_IDLE   = 2'b00;
localparam I_INPUT  = 2'b01;
localparam I_SRAM_W = 2'b10;
localparam I_END    = 2'b11;
reg [1:0] c_state, n_state;
genvar i;
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
reg [15:0]next_buf[15:0];
wire[15:0]sel_data;
//--------------------
// GCK domain

//--------------------
// SRAM read block

always@(posedge GCK, posedge rst) begin
	if(rst)begin
		round <= 1'b0;
	end else begin 
		if(read_eof)
			round <= ~round;
		else
			round <= round;
	end
end


always@(posedge GCK, posedge rst) begin
	if(rst)begin
		sel_RSRAM_flag <= 1'b1;
	end else begin 
		if(read_eof && (round || ~mode) )
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
		next_buf[15] <= 16'd0;
	end else begin 
		if(ci_state == CI_SRAM_READ || ci_state == CI_SRAM_WAIT)
			next_buf[15] <= sel_data;
		else
			next_buf[15] <= next_buf[15];
	end
end

generate 
for(i = 0; i < 15; i = i + 1)begin
	always@(posedge GCK, posedge rst) begin
		if(rst)begin
			next_buf[i] <= 16'd0;
		end else begin 
			if(ci_state == CI_SRAM_READ || ci_state == CI_SRAM_WAIT)
				next_buf[i] <= next_buf[i + 1];
			else
				next_buf[i] <= next_buf[i];
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
endmodule
