`default_nettype none


module gci_node
	#(
		parameter NODE_ID = 8'h01,
		parameter RESET_CYCLE = 8'h0F
	)(
		//System
		input iCLOCK,
		input inRESET,
		//Node Valid
		output oNODE_VALID,
		//Node Info
		output oNODEINFO_VALID,
		output [7:0] oNODEINFO_PRIORITY,
		output [31:0] oNODEINFO_MEMSIZE,
		//MASTER-DATA
		input iMASTER_REQ,	//Inpuit
		output oMASTER_BUSY,
		input iMASTER_RW,
		input [31:0] iMASTER_ADDR,
		input [31:0] iMASTER_DATA,
		output oMASTER_REQ,	//Output
		input iMASTER_BUSY,
		output [31:0] oMASTER_DATA,
		//MASTER-IRQ
		output oMASTER_IRQ_REQ,
		input iMASTER_IRQ_ACK,
		input iMASTER_IRQ_BUSY,
		//DEV-DATA
		input iDEV_VALID,
		input iDEV_REQ,		//Inpuit
		output oDEV_BUSY,	
		input [31:0] iDEV_DATA,
		output oDEV_REQ,		//Output
		input iDEV_BUSY,
		output oDEV_RW,
		output [31:0] oDEV_ADDR,
		output [31:0] oDEV_DATA,
		//DEV-IRQ
		input iDEV_IRQ_REQ,
		output oDEV_IRQ_BUSY,
		input [23:0] iDEV_IRQ_DATA,
		output oDEV_IRQ_ACK
	);
						
							
	localparam L_PARAM_INI0_WAIRT = 3'h0;
	localparam L_PARAM_INI1_GET_MEMSIZE = 3'h1;	
	localparam L_PARAM_INI2_GET_PRIORITY = 3'h2;
	localparam L_PARAM_IDLE = 3'h3;
	localparam L_PARAM_WRITE = 3'h4;
	localparam L_PARAM_READ = 3'h5;
	localparam L_PARAM_DATAOUT = 3'h6;

	localparam L_PARAM_MEMSIZE_ADDR = 32'h00000000;
	localparam L_PARAM_PRIORITY_ADDR = 32'h00000004;
	localparam L_PARAM_INTFLAG_ADDR = 32'h00000008;
		
	
	/************************************************************
	Device Valid Check
	************************************************************/
	/*
	reg		device_valid;
	always@(posedge ICLOCK or negedge inRESET)begin
		if(!inRESET)begin
			device_valid		<=		1'b0;
		end
		else begin
			if(iRESETAFTER_1CYCLE)begin
				device_valid		<=		iDEV_VALID
			end
		end
	end // Degice
	*/
	
	
	
	/************************************************************
	State(IRQ)
	************************************************************/
	localparam L_PARAM_IRQ_STT_IDLE = 2'h0;
	localparam L_PARAM_IRQ_STT_ACK_WAIT = 2'h1;
	localparam L_PARAM_IRQ_STT_FLAGGET_WAIT = 2'h2;

	
	reg b_irq_valid;
	reg [1:0] b_irq_state;
	always@(posedge iCLOCK or negedge inRESET)begin
		if(!inRESET)begin
			b_irq_valid <= 1'b0;
			b_irq_state <= L_PARAM_IRQ_STT_IDLE;
		end
		else begin	
			if(iDEV_VALID && !iMASTER_IRQ_BUSY)begin		
				//Device Valid
				case(b_irq_state)
					L_PARAM_IRQ_STT_IDLE:
						begin
							if(iDEV_IRQ_REQ)begin
								b_irq_valid <= 1'b1;	
								b_irq_state <= L_PARAM_IRQ_STT_ACK_WAIT;
							end
						end
					L_PARAM_IRQ_STT_ACK_WAIT:
						begin
							if(iMASTER_IRQ_ACK)begin
								b_irq_valid <= 1'b0;	
								b_irq_state <= L_PARAM_IRQ_STT_FLAGGET_WAIT;
							end
						end
					L_PARAM_IRQ_STT_FLAGGET_WAIT:
						begin
							if(iMASTER_ADDR == L_PARAM_INTFLAG_ADDR && iMASTER_REQ && !iMASTER_RW)begin
								b_irq_state <= L_PARAM_IRQ_STT_IDLE;
							end
						end
				endcase
			end
		end
	end //IRQ State
	
	
	
	/************************************************************
	State(Data)
	************************************************************/
	
	reg [2:0] b_state;
	reg b_rw;			//Write=1 : Read = 0
	reg [31:0] b_waddr;
	reg [31:0] b_wdata;
	reg b_rwait;
	reg [31:0] b_rdata;
	//Initial
	reg bn_initialmode;
	reg [7:0] b_resetcounter;
	reg [7:0] b_priority;
	reg [31:0] b_memsize;
	

	
	always@(posedge iCLOCK or negedge inRESET)begin
		if(!inRESET)begin
			b_state <= 3'h0;
			b_rw <= 1'b0;
			b_waddr <= {32{1'b0}};
			b_wdata <= {32{1'b0}};
			b_rwait <= 1'b0;
			b_rdata <= {32{1'b0}};
			bn_initialmode <= 1'b0;
			b_resetcounter <= 8'h00;
			b_priority <= 8'h00;
			b_memsize <= {32{1'b0}};
		end
		else begin
			if(iDEV_VALID)begin		
				//Device Valid		
				//Read & Write Wait
				if(b_rwait)begin
					if(iDEV_REQ)begin
						if(bn_initialmode)begin
							//Write
							if(b_state == L_PARAM_WRITE)begin
								b_state <= L_PARAM_DATAOUT;
								b_rwait <= 1'b0;
								b_rdata <= 32'h00000000;
							end
							//Read
							else begin
								b_state <= L_PARAM_DATAOUT;
								b_rwait <= 1'b0;
								b_rdata <= iDEV_DATA;
							end
						end
						else begin
							//Init Mode
							if(b_state == L_PARAM_INI1_GET_MEMSIZE)begin
								b_state <= L_PARAM_INI2_GET_PRIORITY;
								b_rwait <= 1'b0;
								b_memsize <= iDEV_DATA;//[7:0];
							end
							else begin
								b_state <= L_PARAM_IDLE;
								bn_initialmode <= 1'b1;
								b_rwait <= 1'b0;
								b_priority <= iDEV_DATA[7:0];
							end
						end
					end
				end
				//State
				else begin 
					case(b_state)
						L_PARAM_INI0_WAIRT:
							begin
								if(b_resetcounter > RESET_CYCLE)begin
									b_state <= L_PARAM_INI1_GET_MEMSIZE;	
									b_waddr <= L_PARAM_MEMSIZE_ADDR;
									b_resetcounter <= 8'h00;
								end
								else begin
									b_resetcounter <= b_resetcounter + 8'h01;
								end
							end
						L_PARAM_INI1_GET_MEMSIZE:
							begin
								if(!iDEV_BUSY)begin
									b_waddr <= L_PARAM_PRIORITY_ADDR;
									b_rwait <= 1'b1;
								end
							end
						L_PARAM_INI2_GET_PRIORITY:
							begin
								if(!iDEV_BUSY)begin
									b_rwait <= 1'b1;
								end
							end
						L_PARAM_IDLE:
							begin
								if(!iDEV_BUSY)begin
									if(iMASTER_REQ)begin
										if(iMASTER_RW)begin
											b_state <= L_PARAM_WRITE;		
											b_rw <= 1'b1;
											b_waddr <= iMASTER_ADDR;
											b_wdata <= iMASTER_DATA;
										end
										else begin
											b_state <= L_PARAM_READ;
											b_rw <= 1'b0;
											b_waddr <= iMASTER_ADDR;
										end
									end
								end
							end
						L_PARAM_WRITE:
							begin
								b_rwait <= 1'b1;
							end
						L_PARAM_READ:	
							begin
								b_rwait <= 1'b1;
							end
						L_PARAM_DATAOUT:
							begin
								if(iMASTER_REQ && !iDEV_BUSY)begin
									if(iMASTER_RW)begin
										b_state <= L_PARAM_WRITE;
										b_rw <= 1'b1;
										b_waddr <= iMASTER_ADDR;
										b_wdata <= iMASTER_DATA;
									end
									else begin
										b_state <= L_PARAM_READ;
										b_rw <= 1'b0;
										b_waddr <= iMASTER_ADDR;
									end
								end
								else begin
									b_state <= L_PARAM_IDLE;
								end
							end
					endcase
				end
			end
		end 
		
	end //End State Control always
	
	
	
	/************************************************************
	Assign
	************************************************************/
	//Device Valid
	assign oNODE_VALID = iDEV_VALID;
	//Node Info
	assign oNODEINFO_VALID = bn_initialmode;
	assign oNODEINFO_PRIORITY = b_priority;
	assign oNODEINFO_MEMSIZE = b_memsize;
	//MASTER-DATA Input
	assign oMASTER_BUSY = !(b_state == L_PARAM_IDLE || b_state == L_PARAM_DATAOUT) || iDEV_BUSY;
	//MASTER-DATA Output
	assign oMASTER_REQ = b_state == L_PARAM_DATAOUT;
	assign oMASTER_DATA = b_rdata;
	//MASTER-IRQ
	assign oMASTER_IRQ_REQ = b_irq_valid;
	//DEVICE-DATA Input
	assign oDEV_BUSY = 1'b0;
	//DEVICE-DATA Output
	assign oDEV_REQ = (b_state == L_PARAM_WRITE || b_state == L_PARAM_READ || b_state == L_PARAM_INI1_GET_MEMSIZE || b_state == L_PARAM_INI2_GET_PRIORITY) && !b_rwait;
	assign oDEV_RW = b_rw;
	assign oDEV_ADDR = b_waddr;
	assign oDEV_DATA = (b_state == L_PARAM_READ)? {32{1'b0}} : b_wdata;
	//DEVICE-IRQ
	assign oDEV_IRQ_BUSY = iMASTER_IRQ_BUSY;
	assign oDEV_IRQ_ACK = (iMASTER_ADDR == L_PARAM_INTFLAG_ADDR && iMASTER_REQ && !iMASTER_RW)? 1'b1 : 1'b0;
	
	
endmodule



`default_nettype wire
