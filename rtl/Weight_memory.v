`include "include.v"

module Weight_Memory #(parameter numWeight = 3, neuronNo=5,layerNo=1,addressWidth=10,dataWidth=16,weightFile="w_1_15.mif") 
    ( 
	 input wire clk,
	 input wire wen,
	 input wire ren,
	 input wire [addressWidth-1:0] wadd,
	 input wire [addressWidth-1:0] radd,
	 input wire [dataWidth-1:0] win,
	 output reg [dataWidth-1:0] wout
	 );
	 reg [dataWidth-1:0] mem [numWeight-1:0];
	  `ifdef pretrained
        initial
		begin
	        $readmemb(weightFile, mem);
	    end
		`else
		always @(posedge clk) begin
		if(wen) begin
		mem[wadd] <= win;
		end
		end
		`endif
		always @(posedge clk) begin
		if(ren) begin
		wout <= mem[radd];
		end
		end
		endmodule
	 