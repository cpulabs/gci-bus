/*******************************************************
MIST32 GCI Special Memory : For Device
*******************************************************/


`default_nettype none

module gci_device_special_memory
	#(
		parameter USEMEMSIZE = 32'h00000000,	//Byte
		parameter PRIORITY = 32'h00000000,
		parameter DEVICECAT = 32'h00000000
	)(
		//System
		input wire iCLOCK,
		input wire inRESET,
		//Special Addr Access
		input wire iSPECIAL_REQ,
		input wire iSPECIAL_RW,
		input wire [7:0] iSPECIAL_ADDR,
		input wire [31:0] iSPECIAL_DATA,
		output wire [31:0] oSPECIAL_DATA
	);


	integer	i;

	reg [31:0] b_mem[0:255];
	always@(posedge iCLOCK or negedge inRESET)begin
		if(!inRESET)begin
			for(i = 0; i < 256; i = i + 1)begin
				if(i == 0)begin
					//USEMEMSIZE
					b_mem [i] <= USEMEMSIZE;
				end
				else if(i == 1)begin
					//PRIORITY
					b_mem [i] <= PRIORITY;
				end
				else begin
					//Other
					b_mem [i] <= 32'h00000000;
				end
			end
		end
		else begin
			if(iSPECIAL_REQ && iSPECIAL_RW)begin
				b_mem [iSPECIAL_ADDR/*[10:2]*/] <= iSPECIAL_ADDR;
			end
		end
	end //always

	assign oSPECIAL_DATA = b_mem[iSPECIAL_ADDR/*[10:2]*/];


endmodule

`default_nettype wire
