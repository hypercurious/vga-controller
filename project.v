module kbd_protocol (reset, clk, ps2clk, ps2data, scancode, flag);
    input            reset, clk, ps2clk, ps2data;
    output reg [7:0] scancode;
    output reg       flag;
    
    //Synchronize ps2clk to local clock and check for falling edge;
    reg [7:0] ps2clksamples; //Stores last 8 ps2clk samples
    
    always @(posedge clk or posedge reset)
        if(reset) ps2clksamples <= 8'd0;
        else ps2clksamples <= {ps2clksamples[7:0],ps2clk};
    
    wire fall_edge; //indicates a falling edge at ps2clk
    assign fall_edge = (ps2clksamples[7:4]==4'hF)&(ps2clksamples[3:0]==4'h0);
    
    reg [9:0] shift; //Stores a serial package, excluding the stop bit;
    reg [3:0] cnt;  // Used to count the pswdata samples stored so far
    reg       f0;   // Used to indicate that f0 was encountered earlier
    
    always @(posedge clk or posedge reset) begin
        flag <= 1'b0;
        if (reset) begin
            cnt <= 4'd0; scancode <= 8'd0; shift <= 10'd0; f0 <= 1'b0; flag <= 1'b0;
        end
        else if (fall_edge) begin
            if (cnt==4'd10) begin // We just received what should be the stop bit
                cnt <= 0;
                if ((shift[0] == 0) && (ps2data == 1) && (^shift[9:1] == 1)) begin // A well received serial packet
                    if (f0) begin // following a scancode of f0. So a key is released!
                        scancode <= shift[8:1]; f0 <= 0; flag <= 1'b1;
                    end
                else if (shift[8:1] == 8'hF0) f0 <= 1'b1;
                end // All other packets have to do with key presses and are ignored
            end
            else begin
                shift <= {ps2data, shift[9:1]}; // Shift right since LSB first is transmitted
                cnt <= cnt + 1;
            end
        end
    end
endmodule

module pixel_clk(reset, clk, clk25);
	input 		 reset, clk;
	output 		 clk25;
	reg 	[1:0]cnt;
	
	assign clk25 = (cnt==2'd3);
	always @(posedge clk or posedge reset) begin
		if (reset) cnt <= 0;
		else cnt <= cnt + 1;
	end
endmodule

module sync(clk, h_sync, v_sync, xcnt, ycnt);
	input 	clk;
	output	h_sync, v_sync;
	output reg [9:0]xcnt;
	output reg [8:0]ycnt;
	
	reg h, v;
	wire xmax = (xcnt==799);
	wire ymax = (ycnt==448);
	
	always @(posedge clk) begin
		if (xmax) xcnt <= 9'd0;
		else xcnt <= xcnt + 1;
	end
	
	always @(posedge clk) begin
		if (xmax) begin
			if (ymax) ycnt <= 8'd0;
			else ycnt <= ycnt + 1;
		end
	end
	
	always @(posedge clk) begin
		h <= (xcnt>15 && xcnt<112);
		v <= (ycnt>11 && ycnt<14);
	end
	
	assign h_sync = ~h;
	assign v_sync = v;
	
endmodule

module VGA(reset, clk, scancode, flag, xcnt, ycnt, r, g, b);
	input		reset, clk, flag;
	input  [7:0]scancode;
	input  [9:0]xcnt;
	input  [8:0]ycnt;
	output [2:0]r, g, b;
	
	wire [3:0]region;
	
	assign region = (xcnt>10'd160 && xcnt<10'd373) && (ycnt>49 && ycnt<182)  ? 4'd1 :
					(xcnt>10'd372 && xcnt<10'd586) && (ycnt>49 && ycnt<182)  ? 4'd2 :
					(xcnt>10'd585 && xcnt<10'd799) && (ycnt>49 && ycnt<182)  ? 4'd3 :
					(xcnt>10'd160 && xcnt<10'd373) && (ycnt>181 && ycnt<315) ? 4'd4 :
					(xcnt>10'd372 && xcnt<10'd586) && (ycnt>181 && ycnt<315) ? 4'd5 :
					(xcnt>10'd585 && xcnt<10'd799) && (ycnt>181 && ycnt<315) ? 4'd6 :
					(xcnt>10'd160 && xcnt<10'd373) && (ycnt>314 && ycnt<448) ? 4'd7 :
					(xcnt>10'd372 && xcnt<10'd586) && (ycnt>314 && ycnt<448) ? 4'd8 :
					(xcnt>10'd585 && xcnt<10'd799) && (ycnt>314 && ycnt<448) ? 4'd9 : 4'd0;
	
	reg [3:0]rflag;
	reg [27:0]counter;
	reg [8:0]c1, c2, c3, c4, c5, c6, c7, c8, c9;
					
	always @(posedge clk or posedge reset) begin
		if (reset) begin
			rflag <= 4'd0;
			counter <= 28'd0;	
		end
		else if(flag) begin
			rflag <= (scancode==8'h45) ? 4'd0  :
					 (scancode==8'h16) ? 4'd1  :
					 (scancode==8'h1e) ? 4'd2  :
					 (scancode==8'h26) ? 4'd3  :
					 (scancode==8'h25) ? 4'd4  :
					 (scancode==8'h2e) ? 4'd5  :
					 (scancode==8'h36) ? 4'd6  :
					 (scancode==8'h3d) ? 4'd7  :
					 (scancode==8'h3e) ? 4'd8  :
					 (scancode==8'h46) ? 4'd9  : 
					 (scancode==8'h21) ? 4'd10 :
					 (scancode==8'h43) ? 4'd11 :
					 (scancode==8'h33) ? 4'd12 :
					 (scancode==8'h2a) ? 4'd13 : 
					 (scancode==8'h1b) ? 4'd14 : 
					 (scancode==8'h05) ? 4'd15 : rflag;
			if (rflag==4'd10) begin
				c1 <= c4;
				c2 <= c1;
				c3 <= c2;
				c6 <= c3;
				c9 <= c6;
				c8 <= c9;
				c7 <= c8;
				c4 <= c7;
			end
			if (rflag==4'd11) begin
				c1 <= ~c1;
				c2 <= ~c2;
				c3 <= ~c3;
				c4 <= ~c4;
				c5 <= ~c5;
				c6 <= ~c6;
				c7 <= ~c7;
				c8 <= ~c8;
				c9 <= ~c9;
			end
			
		end
		else begin
			counter <= counter + 1;
			if (rflag==4'd0) begin
				{c1, c2, c3, c4, c5, c6, c7, c8, c9} <= 81'd0;
			end
			if (rflag==4'd1) begin
				c1 <= (scancode==8'h2d) ? 9'b111000000 :
					  (scancode==8'h34) ? 9'b000111000 :
					  (scancode==8'h32) ? 9'b000000111 : 
					  (scancode==8'h1c) ? 9'b111111111 : 
					  (scancode==8'h3a) ? 9'b000000000 : c1;
			end
			if (rflag==4'd2) begin
				c2 <= (scancode==8'h2d) ? 9'b111000000 :
					  (scancode==8'h34) ? 9'b000111000 :
				      (scancode==8'h32) ? 9'b000000111 : 
					  (scancode==8'h1c) ? 9'b111111111 : 
					  (scancode==8'h3a) ? 9'b000000000 : c2;
			end
			if (rflag==4'd3) begin
				c3 <= (scancode==8'h2d) ? 9'b111000000 :
				      (scancode==8'h34) ? 9'b000111000 :
				      (scancode==8'h32) ? 9'b000000111 : 
					  (scancode==8'h1c) ? 9'b111111111 : 
					  (scancode==8'h3a) ? 9'b000000000 : c3;
			end
			if (rflag==4'd4) begin
				c4 <= (scancode==8'h2d) ? 9'b111000000 :
				      (scancode==8'h34) ? 9'b000111000 :
				      (scancode==8'h32) ? 9'b000000111 : 
					  (scancode==8'h1c) ? 9'b111111111 : 
					  (scancode==8'h3a) ? 9'b000000000 : c4;
			end
			if (rflag==4'd5) begin
				c5 <= (scancode==8'h2d) ? 9'b111000000 :
					  (scancode==8'h34) ? 9'b000111000 :
				      (scancode==8'h32) ? 9'b000000111 : 
					  (scancode==8'h1c) ? 9'b111111111 : 
					  (scancode==8'h3a) ? 9'b000000000 : c5;
			end
			if (rflag==4'd6) begin
				c6 <= (scancode==8'h2d) ? 9'b111000000 :
				      (scancode==8'h34) ? 9'b000111000 :
				      (scancode==8'h32) ? 9'b000000111 : 
					  (scancode==8'h1c) ? 9'b111111111 : 
					  (scancode==8'h3a) ? 9'b000000000 : c6;
			end
			if (rflag==4'd7) begin
				c7 <= (scancode==8'h2d) ? 9'b111000000 :
				      (scancode==8'h34) ? 9'b000111000 :
				      (scancode==8'h32) ? 9'b000000111 : 
					  (scancode==8'h1c) ? 9'b111111111 : 
					  (scancode==8'h3a) ? 9'b000000000 : c7;
			end
			if (rflag==4'd8) begin
				c8 <= (scancode==8'h2d) ? 9'b111000000 :
				      (scancode==8'h34) ? 9'b000111000 :
				      (scancode==8'h32) ? 9'b000000111 : 
					  (scancode==8'h1c) ? 9'b111111111 : 
					  (scancode==8'h3a) ? 9'b000000000 : c8;
			end
			if (rflag==4'd9) begin
				c9 <= (scancode==8'h2d) ? 9'b111000000 :
				      (scancode==8'h34) ? 9'b000111000 :
				      (scancode==8'h32) ? 9'b000000111 : 
					  (scancode==8'h1c) ? 9'b111111111 : 
					  (scancode==8'h3a) ? 9'b000000000 : c9;
			end
			if (rflag==4'd12) begin
				c3 <= c1 | c2;
				c6 <= c4 | c5;
				c9 <= c7 | c8;
			end
			if (rflag==4'd13) begin
				c7 <= c1 | c4;
				c8 <= c2 | c5;
				c9 <= c3 | c6;
			end
			if (rflag==4'd14) begin
				c1 <= 9'b111111000;
				c2 <= 9'b111111111;
				c3 <= 9'b111111111;
				c4 <= 9'b111111000;
				c5 <= 9'b000111111;
				c6 <= 9'b000111111;
				c7 <= 9'b111000000;
				c8 <= 9'b111000000;
				c9 <= 9'b111000000;
			end
			if (rflag==4'd15) begin
				if(counter[25]==1'b1) begin
					c1 <= {counter[27:25],counter[25:23],counter[23:21]};
					c2 <= {counter[27:25],counter[25:23],counter[25:23]};
					c3 <= {counter[27:25],counter[25:23],counter[27:25]};
					c4 <= {counter[27:25],counter[25:23],counter[25:23]};
					c5 <= {counter[27:25],counter[25:23],counter[26:24]};
					c6 <= {counter[27:25],counter[25:23],counter[26:24]};
					c7 <= {counter[27:25],counter[25:23],counter[27:25]};
					c8 <= {counter[27:25],counter[25:23],counter[26:24]};
					c9 <= {counter[27:25],counter[25:23],counter[27:25]};
				end
			end
		end
	end
	assign {r, g, b} = (region==4'd1) ? c1 :
					   (region==4'd2) ? c2 :
					   (region==4'd3) ? c3 :
					   (region==4'd4) ? c4 :
					   (region==4'd5) ? c5 :
					   (region==4'd6) ? c6 :
					   (region==4'd7) ? c7 :
					   (region==4'd8) ? c8 :
					   (region==4'd9) ? c9 : 9'b000000000;			 
endmodule

module project(reset, clk, ps2data, ps2clk, h_sync, v_sync, r, g, b);
	input 		reset, clk, ps2data, ps2clk;
	output 		h_sync, v_sync;
	output [2:0]r, g, b;
	
	wire	  clk25;
	wire 	  flag;
	wire [7:0]scancode;
	wire [9:0]xcnt;
	wire [8:0]ycnt;
	
	pixel_clk pxl(reset, clk, clk25);
	sync snc(clk25, h_sync, v_sync, xcnt, ycnt);
	kbd_protocol keyboard(reset, clk25, ps2clk, ps2data, scancode, flag);
	VGA vga(reset, clk25, scancode, flag, xcnt, ycnt, r, g, b);
	
endmodule
