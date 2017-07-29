module blackjack(SW, KEY, LEDR, LEDG, HEX0, HEX1, HEX2, HEX3, HEX4, HEX5, HEX6, HEX7, CLOCK_50);
// inputs
input [17:0] SW;
input [3:0] KEY;
input CLOCK_50;
output [7:0] LEDG;
output [17:0] LEDR;
output [7:0] HEX0, HEX1, HEX2, HEX3, HEX4, HEX5, HEX6, HEX7;


// assigns P1/P2/Load_highscore KEY, reset and enable switch
assign clock0 = ~KEY[2];
assign clock1 = ~KEY[1];
assign load_hs = ~KEY[3];
assign reset = SW[17];
assign enable = SW[16];

// stores mode, player 1/2 score
reg [0:0] mode;
reg [7:0] p1_score = 8'b00000000;
reg [7:0] p2_score = 8'b00000000;

// stores whether the player has stopped by flicking a switch
reg p1_stop_reg, p2_stop_reg;
wire p1_stop, p2_stop;

// stores highscore of current game, and all time highscore
reg [7:0] highscore;
// wire for the highscore
wire [7:0] hs_out;
reg [7:0] all_time_hs;

// wires for random number generator, and for player stopping
wire [4:0] lfsr1_out;
wire [4:0] lfsr2_out;

// wires for all the scores, we need first4/last4 for displaying properly on hex
wire [3:0] p1_first4;
wire [3:0] p1_last4;
wire [3:0] p2_first4;
wire [3:0] p2_last4;
wire [3:0] hs_first4;
wire [3:0] hs_last4;
wire [3:0] all_time_hs_first4;
wire [3:0] all_time_hs_last4;

// p1 can stop with SW[2], p2 can stop with SW[1]
assign p1_stop = SW[2];
assign p2_stop = SW[1];

// selects mode
always@(SW[0])
	begin
	// if 1, then 1P mode
	if (SW[0])
		begin
		mode <= 1'b1;
		end
	// otherwise 2P mode	
	else
		begin
		mode <= 1'b0;
		end
	end  
  
// get a random number for player1
lfsr one(.out(lfsr1_out), .clk(clock0), .rst(reset));

// player 1/AI handling 
always @(posedge clock0 or negedge reset)
	begin
	// if we reset, set p1_score and its stop reg to 0
	if (~reset) begin
		p1_score <= 8'b00000000;
		p1_stop_reg <= 1'b0;
	end else if (enable) begin
		// otherwise enabled, if 1P mode (AI)
		if (mode == 1'b1)
			begin
			//check if p2 is over and I'm (p1) under, if so then I want to stop
			if (p2_score > 8'b00010101 && p1_score <= 8'b00010101)
				begin
				p1_stop_reg <= 1'b1;
				end
			// else if im 21 and p2_score < mine, then I want to stop
			else if (p1_score == 8'b00010101 && p2_score < p1_score)
				begin
				p1_stop_reg <= 1'b1;
				end
			//else if my score >= 17 and my score > p2_score
			else if (p1_score >= 8'b00010001 && p1_score >= p2_score)
				begin
				// then I want to stop, I don't care about p1_score
				p1_stop_reg <= 1'b1;
				end
			// else if p2 has stopped, and my score > p2_score, then I want to stop
			else if ((p2_stop_reg || p2_stop) && p1_score > p2_score)
				begin
				p1_stop_reg <= 1'b1;
				end

			// otherwise I want to just roll
			else
				begin
				// if I have stopped, then I will not incremenet my values
				if (p1_stop_reg || p1_stop)
					begin
					p1_score <= p1_score + 0;
					end
				// otherwise I will modify LFSR value to increase my score
				else
					begin
					p1_score <= p1_score + (((lfsr1_out[3:0]) * 2) % 4) + 1;
					end
				end
		end
		// otherwise 2P mode
		else
			begin
			// if p1 has stopped, then I will not incremeent
			if (p1_stop_reg || p1_stop)
				begin
				p1_score <= p1_score + 0;
				end
			// otherwise I will increment my values based on LFSR random value
			else
				begin
				p1_score <= p1_score + (((lfsr1_out[3:0]) * 2) % 4) + 1;
				end
			end
		end
	end


// player 2 handling
always @(posedge clock1 or negedge reset)
	begin
	// if we reset, set p2_score and its stop reg to 0
	if (~reset) begin
		p2_score <= 8'b00000000;
		p2_stop_reg <= 1'b0;
	end else if (enable) begin
		// if p2 has stopped, dont incremement
		if (p2_stop_reg || p2_stop)
			begin
				p2_score <= p2_score + 0;
			end
		// else increment
		else
			begin
				p2_score <=b00010101 p2_score + (((lfsr1_out[3:0]) * 2) % 4) + 1;
			end
		end
	end

// this is where we constantly update the current games highscore
always@(*)
	begin
	// if (p1 > p2) and p1_score is valid and both players have stopped, then p1 gets the highscore spot
	if ((p1_score > p2_score) && p1_score <= 8'b00010101 && ((p1_stop || p1_stop_reg) && (p2_stop || p2_stop_reg)))
		begin
			highscore <= p1_score;
			//game_ended <= 1'b1;
		end
	// else if (p2 > p1) and p2_score is valid and both players have stopped, then p2 gets get highscore spot	
	else if ((p2_score > p1_score) && p2_score <= 8'b00010101 && ((p1_stop || p1_stop_reg) && (p2_stop || p2_stop_reg)))
		begin
			highscore <= p2_score;
			//game_ended <= 1'b1;
		end
	// else if we are in 1P mode and p1 (AI) has stopped
	else if (mode==1'b1 && (p1_stop || p1_stop_reg))
		begin
			// if AI score > p2_score and AI score is still valid, then AI gets get highscore spot
			if (p1_score > p2_score && (p1_score <= 8'b00010101))
				begin
					highscore <= p1_score;
				end
			// else if above condition is not met and p2_score is valid, then P2 gets get highscore spot
			else if(p2_score <= 8'b00010101)
				begin
					highscore <= p2_score;
				end
		end

	// else
	else 
		begin
			// if p2_score > p1_score and p2_score is still valid, then P2 gets get highscore spot
			if (p2_score > p1_score && (p2_score <= 8'b00010101))
				begin
					highscore <= p2_score;
				end
			// else if p1_score is valid, then P1 gets get highscore spot
			else if(p1_score <= 8'b00010101)
				begin
					highscore <= p1_score;
				end
			// else if p1_score is NOT valid, and p2_score is valid, then 2 gets higscore spot
			else if (p1_score > 8'b00010101 && (p2_score <= 8'b00010101) && (p2_stop || p2_stop_reg))
				begin
					highscore <= p2_score;
				end
			// else if p2_score is NOT valid, and p1_score is valid,thenn2 gets higscore spot
			else if (p2_score > 8'b00010101 && (p1_score <= 8'b00010101) && (p1_stop || p1_stop_reg))
				begin
					highscore <= p1_score;
				end
		end
	end


// here are the wires that declare which player has won
wire out_p1, out_p2;
// we call the check_winner module, and whichever player wins, their wire (out_p1/p2) will be assigned a 1'b1
check_winner(.score1(p1_score), .score2(p2_score), 
.p1_stop(p1_stop || p1_stop_reg), .p2_stop(p2_stop || p2_stop_reg), .out_p1(out_p1), .out_p2(out_p2));

// the LEDR[2-1] indicates which players have stopped
assign LEDR[2] = p1_stop || p1_stop_reg;
assign LEDR[1] = p2_stop || p2_stop_reg;
// the LEDR[14-13] indicates who has won (in draw both are lit up, in no one win, none are)
assign LEDR[14] = out_p1;
assign LEDR[13] = out_p2;

// this module stores the highscore of 5 games
// to write -> SW[15] is on, to read -> SW[15] is off, SW[8:4] are the addresses, it's loaded with load_hs KEY
ram_storage ri(.data(highscore), .read_place(SW[8:4]), .write_place(SW[8:4]), .wren(SW[15]), .clk(load_hs), .q(hs_out));

// whenever we press the load_hs KEY
always@(posedge KEY[3])
	begin
	// if our game highscore > all_time_hs and our highscore is still valid, it becomes the all time highscore
	if (highscore >= all_time_hs && highscore <= 8'b00010101)
		begin
		all_time_hs <= highscore;
		end
	end

// this module converts hex numbers into binary, so that's why we have the first4/last4
// ex) 17 in binary is 00010001, which is 11 on HEX, but this module converts it so HEX shows 17
change_hex p1(p1_score, p1_first4, p1_last4);
change_hex p2(p2_score, p2_first4, p2_last4);
change_hex hs(hs_out, hs_first4, hs_last4);
change_hex all_time_hs_change(all_time_hs, all_time_hs_first4, all_time_hs_last4);

// hex_decoder for the P1/P2 scores
hex_decoder h3(.hex_digit(p1_first4), .segments(HEX3));
hex_decoder h2(.hex_digit(p1_last4), .segments(HEX2));
hex_decoder h1(.hex_digit(p2_first4), .segments(HEX1));
hex_decoder h0(.hex_digit(p2_last4), .segments(HEX0));
// hex_decoder for highscore of any game chosen by ram module
hex_decoder h5(.hex_digit(hs_first4), .segments(HEX5));
hex_decoder h4(.hex_digit(hs_last4), .segments(HEX4));
// hex_decoder for all_time_hs (always visible)
hex_decoder h7(.hex_digit(all_time_hs_first4), .segments(HEX7));
hex_decoder h6(.hex_digit(all_time_hs_last4), .segments(HEX6));

// on the LEDG[7:0], we display a winning animation for which ever player won
blinking p1_wins(.clk(CLOCK_50), .out(LEDG[7:4]), .game_ended(LEDR[14] == 1'b1));
blinking p2_wins(.clk(CLOCK_50), .out(LEDG[3:0]), .game_ended(LEDR[13] == 1'b1));

endmodule


// given both players' scores and their stop conditions, check_winner module figures out who wins and turns on the appropriate led assigned 
// to that player. In case there is a tie, check_winner turns on both leds
module check_winner(score1, score2, p1_stop, p2_stop, out_p1, out_p2);
// storage for both scores, stop switch state and winning leds
input [7:0] score1, score2;
input p1_stop, p2_stop;
output reg [0:0] out_p1; // if p1 wins
output reg [0:0] out_p2; // if p2 wins

// wires storing whether both players scores are valid or not
wire score1_valid = (score1 <= 8'b00010101); // <= 21
wire score2_valid = (score2 <= 8'b00010101);


// this is where we constantly check for a winner through winning conditions
// mentioned inside this always block
always @ (*)
begin	
	// If player 1's score is 21, then player1's led is turned on
	if (score1==8'b00010101)
	begin
		out_p1 <= 1'b1;
	end
	// if score2 = 21, p2 win and led is turned on
	else if (score2==8'b00010101)
	begin
		out_p2 <= 1'b1;
	end

	// if both stopped then we have to check whose score is within bound and greater
	if (p1_stop && p2_stop)
	begin
		// If both players' scores are valid and player1's score is greater than
		// player2 then player 1 wins and its led is turned on
		if ((score1_valid && score2_valid) && (score1 > score2)) begin
			out_p1 <= 1'b1;

		end
		
		// If both players' scores are valid and player1's score is less than
		// player2 then player 2 wins and its led is turned on
		if ((score1_valid && score2_valid) && (score2 > score1)) begin
			out_p2 <= 1'b1;

		end
		
		// If both players' scores are equal when they stop then turn on both leds
		if (score1==score2 && score1_valid && score2_valid)
			begin
				out_p1 <= 1'b1;
				out_p2 <= 1'b1;
			end

	end

	// if player1 stopped and player2's score is invalid then player 1 wins
	// and its led is turned on
	if (p1_stop) begin
		// p1 stop, p2 is still playing
		if (~score2_valid && score1_valid) begin
			out_p1 <= 1'b1;
		end
	end

	// if player2 stopped and player1's score is invalid then player 2 wins
	// and its led is turned on	
	if (p2_stop) begin
		if (~score1_valid && score2_valid) begin
			out_p2 <= 1'b1;
		end
	end

	// otherwise if both players have not stopped yet
	if (~p1_stop && ~p2_stop)
	begin
		// if score1 = 21 p1 wins and its led is turned on
		if (score1==8'b00010101)
			begin
				out_p1 <= 1'b1;
			end

		// else if score2 = 21, p2 wins and its led is turned on
		else if (score2==8'b00010101)
			begin
					out_p2 <= 1'b1;
			end

		// else, we are still playing and so keep the leds off
		else
			begin
				out_p1 <= 1'b0;
				out_p2 <= 1'b0;
			end
	end


end

endmodule

// Given a 4 bit binary number and all the segments of a HEX Display,
// module hex_decoder converts the hex digit binary number to a Hexadecimal value
// and displays it on the HEX Display whose segments are passed into the module
module hex_decoder(hex_digit, segments);

// store for a 4 bit binary number and 7 segments of HEX Display
input [3:0] hex_digit;
output reg [6:0] segments;

// This is where we do the conversion from binary to hexadecimal
always @(*)
// According to the value of the 4 bit binary number, we set each and
// every segment in the display to be on or off if the value of the
// binary number is between 0 and 15 inclusive
case (hex_digit)
	4'h0: segments = 7'b100_0000;
	4'h1: segments = 7'b111_1001;
	4'h2: segments = 7'b010_0100;
	4'h3: segments = 7'b011_0000;
	4'h4: segments = 7'b001_1001;
	4'h5: segments = 7'b001_0010;
	4'h6: segments = 7'b000_0010;
	4'h7: segments = 7'b111_1000;
	4'h8: segments = 7'b000_0000;
	4'h9: segments = 7'b001_1000;
	4'hA: segments = 7'b000_1000;
	4'hB: segments = 7'b000_0011;
	4'hC: segments = 7'b100_0110;
	4'hD: segments = 7'b010_0001;
	4'hE: segments = 7'b000_0110;
	4'hF: segments = 7'b000_1110;   
	default: segments = 7'h7f;
endcase
endmodule


// Given a 5 bit output, a clock and a reset switch,
// lfsr module generates a random number that is between
// 1 and 31 (later modified so it's only between 1 - 13)
module lfsr (out, clk, rst);
output reg[4:0] out;
input clk, rst;

wire feedback = out[4] ^ out[1];

// WHenever clk is turned on, we generate a new random number
// and when rst switch is turned off, we reset the random number to 0
always @(posedge clk or negedge rst)
begin
	if (~rst)
		out <= 4'h0;
	else begin
		out <= {out[3:0],feedback};
		if (out[3:0]>4'b1110)
		begin
			out <= 5'b01101;
		end
		
		// If the generated random number is 0 then sets it to 1
		if (out==5'b00000)
		begin
			out <= 5'b00001;
		end
	end
end

endmodule

// Given data, address, write_enable, clock and an output q,
// ram_storage module writes the data given to the address if write_enable
// is turned on and returns it and clock is on and if write_enable is off then
// ram_storage reads the value at the given address when clock is turned on
module ram_storage
(
input [7:0] data, // 8 bit data 
input [7:0] read_place, write_place, // 8 bit address
input wren, clk, // write_enable and clock
output reg [7:0] q // output
);

// Declare the RAM variable, 64 needed for 8 bit storage
reg [7:0] ram[63:0];

always @ (posedge clk)
begin
	// write if enabled
	if (wren)
		ram[write_place] <= data;

	// read at the location we got input from
	q <= ram[read_place];
end
endmodule


// Given a clock, output and game_ended boolean variable (animation)
module blinking (clk, out, game_ended);
// Clock and game_ended
input clk, game_ended;
// 4 bit output
output [3:0] out;

// out counter and state
reg [32:0] counter;
reg state;

// asign the LEDG their specific state values
assign out[0] = state;
assign out[1] = state;
assign out[2] = state;
assign out[3] = state;

// This is where we increase the counter when game_ended is false
// Since clk is Clock50, this always block is running forever
always @ (posedge clk) begin
	// if the game has ended (clock is enabled)
	if (game_ended)
	begin
		// increase the counter and change the data state
		counter <= counter + 1;
		state <= counter[24]; // 22 is slow speed which is what we want, lower = faster
	end
end
endmodule


// Given a 8 bit value and two 4 bit outputs, change_hex converts the 8 bit binary value to
// two decimal values that can be displayed on the HEX. For Eg: 8'b00001111 is turned to
// two 4 bit binary values containing 4'b0001 and 4'b0101
module change_hex(value, first_four_out, last_four_out);
	// 8 bit value in binary
	input [7:0] value;
	
	// Two 4 bit binary values denoting decimal value of original input value
	output reg [3:0] first_four_out, last_four_out;
	

	always @(*)
		// According to the value of the input value, sets the values of
		// the two 4 bit outputs (first_four_out and last_four_out) so that
		// when both outputs displayed right beside each other, they showcase the value of the
		// original input value
		case (value)
			8'b00000000: begin
			first_four_out <= 4'b0000;
			last_four_out <= 4'b0000;
			end
			8'b00000001: begin
			first_four_out <= 4'b0000;
			last_four_out <= 4'b0001;
			end
			8'b00000010: begin
			first_four_out <= 4'b0000;
			last_four_out <= 4'b0010;
			end
			8'b00000011: begin
			first_four_out <= 4'b0000;
			last_four_out <= 4'b0011;
			end
			8'b00000100: begin
			first_four_out <= 4'b0000;
			last_four_out <= 4'b0100;
			end
			8'b00000101: begin
			first_four_out <= 4'b0000;
			last_four_out <= 4'b0101;
			end
			8'b00000110: begin
			first_four_out <= 4'b0000;
			last_four_out <= 4'b0110;
			end
			8'b00000111: begin
			first_four_out <= 4'b0000;
			last_four_out <= 4'b0111;
			end
			8'b00001000: begin
			first_four_out <= 4'b0000;
			last_four_out <= 4'b1000;
			end
			8'b00001001: begin
			first_four_out <= 4'b0000;
			last_four_out <= 4'b1001;
			end
		
			8'b00001010: begin
			first_four_out <= 4'b0001;
			last_four_out <= 4'b0000;
			end
			8'b00001011: begin
			first_four_out <= 4'b0001;
			last_four_out <= 4'b0001;
			end
			8'b00001100: begin
			first_four_out <= 4'b0001;
			last_four_out <= 4'b0010;
			end
			8'b00001101: begin
			first_four_out <= 4'b0001;
			last_four_out <= 4'b0011;
			end
			8'b00001110: begin
			first_four_out <= 4'b0001;
			last_four_out <= 4'b0100;
			end
			8'b00001111: begin
			first_four_out <= 4'b0001;
			last_four_out <= 4'b0101;
			end
			8'b00010000: begin
			first_four_out <= 4'b0001;
			last_four_out <= 4'b0110;
			end
			8'b00010001: begin
			first_four_out <= 4'b0001;
			last_four_out <= 4'b0111;
			end
			8'b00010010: begin
			first_four_out <= 4'b0001;
			last_four_out <= 4'b1000;
			end
			8'b00010011: begin
			first_four_out <= 4'b0001;
			last_four_out <= 4'b1001;
			end
			8'b00010100: begin
			first_four_out <= 4'b0010;
			last_four_out <= 4'b0000;
			end
			8'b00010101: begin
			first_four_out <= 4'b0010;
			last_four_out <= 4'b0001;
			end
			default: begin
			first_four_out <= 4'b1111;
			last_four_out <= 4'b1111;
			end
		endcase
endmodule