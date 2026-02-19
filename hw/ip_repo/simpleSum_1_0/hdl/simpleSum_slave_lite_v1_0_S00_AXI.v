
`timescale 1 ns / 1 ps

	module simpleSum_slave_lite_v1_0_S00_AXI #
	(
		// Users to add parameters here

		// User parameters ends
		// Do not modify the parameters beyond this line

		// Width of S_AXI data bus
		parameter integer C_S_AXI_DATA_WIDTH	= 32,
		// Width of S_AXI address bus
		parameter integer C_S_AXI_ADDR_WIDTH	= 6
	)
	(
		// Users to add ports here
// b1 ROM interface (to connect in BD)
output wire        b1_en,
output wire [4:0]  b1_addr,
input  wire [31:0] b1_dout,

output wire        w1_en,
output wire [14:0] w1_addr,
input  wire [7:0]  w1_dout,

output wire        w2_en,
output wire [8:0]  w2_addr,
input  wire [7:0]  w2_dout,

output wire        b2_en,
output wire [3:0]  b2_addr,
input  wire [31:0] b2_dout,



		// User ports ends
		// Do not modify the ports beyond this line

		// Global Clock Signal
		input wire  S_AXI_ACLK,
		// Global Reset Signal. This Signal is Active LOW
		input wire  S_AXI_ARESETN,
		// Write address (issued by master, acceped by Slave)
		input wire [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_AWADDR,
		// Write channel Protection type. This signal indicates the
    		// privilege and security level of the transaction, and whether
    		// the transaction is a data access or an instruction access.
		input wire [2 : 0] S_AXI_AWPROT,
		// Write address valid. This signal indicates that the master signaling
    		// valid write address and control information.
		input wire  S_AXI_AWVALID,
		// Write address ready. This signal indicates that the slave is ready
    		// to accept an address and associated control signals.
		output wire  S_AXI_AWREADY,
		// Write data (issued by master, acceped by Slave) 
		input wire [C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_WDATA,
		// Write strobes. This signal indicates which byte lanes hold
    		// valid data. There is one write strobe bit for each eight
    		// bits of the write data bus.    
		input wire [(C_S_AXI_DATA_WIDTH/8)-1 : 0] S_AXI_WSTRB,
		// Write valid. This signal indicates that valid write
    		// data and strobes are available.
		input wire  S_AXI_WVALID,
		// Write ready. This signal indicates that the slave
    		// can accept the write data.
		output wire  S_AXI_WREADY,
		// Write response. This signal indicates the status
    		// of the write transaction.
		output wire [1 : 0] S_AXI_BRESP,
		// Write response valid. This signal indicates that the channel
    		// is signaling a valid write response.
		output wire  S_AXI_BVALID,
		// Response ready. This signal indicates that the master
    		// can accept a write response.
		input wire  S_AXI_BREADY,
		// Read address (issued by master, acceped by Slave)
		input wire [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_ARADDR,
		// Protection type. This signal indicates the privilege
    		// and security level of the transaction, and whether the
    		// transaction is a data access or an instruction access.
		input wire [2 : 0] S_AXI_ARPROT,
		// Read address valid. This signal indicates that the channel
    		// is signaling valid read address and control information.
		input wire  S_AXI_ARVALID,
		// Read address ready. This signal indicates that the slave is
    		// ready to accept an address and associated control signals.
		output wire  S_AXI_ARREADY,
		// Read data (issued by slave)
		output wire [C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_RDATA,
		// Read response. This signal indicates the status of the
    		// read transfer.
		output wire [1 : 0] S_AXI_RRESP,
		// Read valid. This signal indicates that the channel is
    		// signaling the required read data.
		output wire  S_AXI_RVALID,
		// Read ready. This signal indicates that the master can
    		// accept the read data and response information.
		input wire  S_AXI_RREADY
	);

	// AXI4LITE signals
	reg [C_S_AXI_ADDR_WIDTH-1 : 0] 	axi_awaddr;
	reg  	axi_awready;
	reg  	axi_wready;
	reg [1 : 0] 	axi_bresp;
	reg  	axi_bvalid;
	reg [C_S_AXI_ADDR_WIDTH-1 : 0] 	axi_araddr;
	reg  	axi_arready;
	reg [1 : 0] 	axi_rresp;
	reg  	axi_rvalid;

	// Example-specific design signals
	// local parameter for addressing 32 bit / 64 bit C_S_AXI_DATA_WIDTH
	// ADDR_LSB is used for addressing 32/64 bit registers/memories
	// ADDR_LSB = 2 for 32 bits (n downto 2)
	// ADDR_LSB = 3 for 64 bits (n downto 3)
	localparam integer ADDR_LSB = (C_S_AXI_DATA_WIDTH/32) + 1;
	localparam integer OPT_MEM_ADDR_BITS = 2;
	//----------------------------------------------
	//-- Signals for user logic register space example
	//------------------------------------------------
	//-- Number of Slave Registers 6
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg0; // control: [0]=start
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg1; // pixel data: [7:0]
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg2; // pixel index: [9:0]
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg3; // status/result: [0]=done, [7:4]=pred
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg4; // unused
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg5; // unused
	reg [C_S_AXI_DATA_WIDTH-1:0]    slv_reg6;
    reg [C_S_AXI_DATA_WIDTH-1:0]    slv_reg7;
	integer	 byte_index;
    // ------------------------------------------------------------
    // Toy accelerator internal control
    // slv_reg0[0] = start
    // slv_reg1 = pixel value = bits[7:0] (0..255)
    // slv_reg2    = pixel index bits[9:0] = which pixel (0..783)
    // slv_reg3    = status/result [0]=done, [7:4]=prediction digit
    // slv_reg4    = 
    // ------------------------------------------------------------
    //reg accel_busy;
	// I/O Connections assignments

	assign S_AXI_AWREADY	= axi_awready;
	assign S_AXI_WREADY	= axi_wready;
	assign S_AXI_BRESP	= axi_bresp;
	assign S_AXI_BVALID	= axi_bvalid;
	assign S_AXI_ARREADY	= axi_arready;
	assign S_AXI_RRESP	= axi_rresp;
	assign S_AXI_RVALID	= axi_rvalid;
	 //state machine varibles 
	 reg [1:0] state_write;
	 reg [1:0] state_read;
	 //State machine local parameters
	 localparam Idle = 2'b00,Raddr = 2'b10,Rdata = 2'b11 ,Waddr = 2'b10,Wdata = 2'b11;
	// Implement Write state machine
	// Outstanding write transactions are not supported by the slave i.e., master should assert bready to receive response on or before it starts sending the new transaction
	always @(posedge S_AXI_ACLK)                                 
	  begin                                 
	     if (S_AXI_ARESETN == 1'b0)                                 
	       begin                                 
	         axi_awready <= 0;                                 
	         axi_wready <= 0;                                 
	         axi_bvalid <= 0;                                 
	         axi_bresp <= 0;                                 
	         axi_awaddr <= 0;                                 
	         state_write <= Idle;                                 
	       end                                 
	     else                                  
	       begin                                 
	         case(state_write)                                 
	           Idle:                                      
	             begin                                 
	               if(S_AXI_ARESETN == 1'b1)                                  
	                 begin                                 
	                   axi_awready <= 1'b1;                                 
	                   axi_wready <= 1'b1;                                 
	                   state_write <= Waddr;                                 
	                 end                                 
	               else state_write <= state_write;                                 
	             end                                 
	           Waddr:        //At this state, slave is ready to receive address along with corresponding control signals and first data packet. Response valid is also handled at this state                                 
	             begin                                 
	               if (S_AXI_AWVALID && S_AXI_AWREADY)                                 
	                  begin                                 
	                    axi_awaddr <= S_AXI_AWADDR;                                 
	                    if(S_AXI_WVALID)                                  
	                      begin                                   
	                        axi_awready <= 1'b1;                                 
	                        state_write <= Waddr;                                 
	                        axi_bvalid <= 1'b1;                                 
	                      end                                 
	                    else                                  
	                      begin                                 
	                        axi_awready <= 1'b0;                                 
	                        state_write <= Wdata;                                 
	                        if (S_AXI_BREADY && axi_bvalid) axi_bvalid <= 1'b0;                                 
	                      end                                 
	                  end                                 
	               else                                  
	                  begin                                 
	                    state_write <= state_write;                                 
	                    if (S_AXI_BREADY && axi_bvalid) axi_bvalid <= 1'b0;                                 
	                   end                                 
	             end                                 
	          Wdata:        //At this state, slave is ready to receive the data packets until the number of transfers is equal to burst length                                 
	             begin                                 
	               if (S_AXI_WVALID)                                 
	                 begin                                 
	                   state_write <= Waddr;                                 
	                   axi_bvalid <= 1'b1;                                 
	                   axi_awready <= 1'b1;                                 
	                 end                                 
	                else                                  
	                 begin                                 
	                   state_write <= state_write;                                 
	                   if (S_AXI_BREADY && axi_bvalid) axi_bvalid <= 1'b0;                                 
	                 end                                              
	             end                                 
	          endcase                                 
	        end                                 
	      end                                 

	// Implement memory mapped register select and write logic generation
	// The write data is accepted and written to memory mapped registers when
	// axi_awready, S_AXI_WVALID, axi_wready and S_AXI_WVALID are asserted. Write strobes are used to
	// select byte enables of slave registers while writing.
	// These registers are cleared when reset (active low) is applied.
	// Slave register write enable is asserted when valid address and data are available
	// and the slave is ready to accept the write address and write data.
	 

	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      slv_reg0 <= 0;
	      slv_reg1 <= 0;
	      slv_reg2 <= 0;
	      //slv_reg3 <= 0;
	      //slv_reg4 <= 0;
	      //slv_reg5 <= 0;
	    end 
	  else begin
	    if (S_AXI_WVALID)
	      begin
	        case ( (S_AXI_AWVALID) ? S_AXI_AWADDR[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] : axi_awaddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] )
	          3'h0:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 0
	                slv_reg0[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
	          3'h1:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 1
	                slv_reg1[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
	          3'h2:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 2
	                slv_reg2[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
	          3'h3: begin
	            //for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              //if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 3
	                //slv_reg3[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
	          3'h4:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 4
	                //slv_reg4[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
	          3'h5:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 5
	                //slv_reg5[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end 

	          default : begin
	                      slv_reg0 <= slv_reg0;
	                      //slv_reg1 <= slv_reg1;
	                      slv_reg2 <= slv_reg2;

	                      //slv_reg4 <= slv_reg4;

	                    end
	        endcase
	      end
	  end
	end    

	// Implement read state machine
	  always @(posedge S_AXI_ACLK)                                       
	    begin                                       
	      if (S_AXI_ARESETN == 1'b0)                                       
	        begin                                       
	         //asserting initial values to all 0's during reset                                       
	         axi_arready <= 1'b0;                                       
	         axi_rvalid <= 1'b0;                                       
	         axi_rresp <= 1'b0;                                       
	         state_read <= Idle;                                       
	        end                                       
	      else                                       
	        begin                                       
	          case(state_read)                                       
	            Idle:     //Initial state inidicating reset is done and ready to receive read/write transactions                                       
	              begin                                                
	                if (S_AXI_ARESETN == 1'b1)                                        
	                  begin                                       
	                    state_read <= Raddr;                                       
	                    axi_arready <= 1'b1;                                       
	                  end                                       
	                else state_read <= state_read;                                       
	              end                                       
	            Raddr:        //At this state, slave is ready to receive address along with corresponding control signals                                       
	              begin                                       
	                if (S_AXI_ARVALID && S_AXI_ARREADY)                                       
	                  begin                                       
	                    state_read <= Rdata;                                       
	                    axi_araddr <= S_AXI_ARADDR;                                       
	                    axi_rvalid <= 1'b1;                                       
	                    axi_arready <= 1'b0;                                       
	                  end                                       
	                else state_read <= state_read;                                       
	              end                                       
	            Rdata:        //At this state, slave is ready to send the data packets until the number of transfers is equal to burst length                                       
	              begin                                           
	                if (S_AXI_RVALID && S_AXI_RREADY)                                       
	                  begin                                       
	                    axi_rvalid <= 1'b0;                                       
	                    axi_arready <= 1'b1;                                       
	                    state_read <= Raddr;                                       
	                  end                                       
	                else state_read <= state_read;                                       
	              end                                       
	           endcase                                       
	          end                                       
	        end                                         
	// Implement memory mapped register select and read logic generation
assign S_AXI_RDATA = 
    (axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] == 3'h0) ? slv_reg0 :
    (axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] == 3'h1) ? slv_reg1 :
    (axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] == 3'h2) ? slv_reg2 :
    (axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] == 3'h3) ? slv_reg3 :
    (axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] == 3'h4) ? slv_reg4 :
    (axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] == 3'h5) ? slv_reg5 :
    (axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] == 3'h6) ? slv_reg6 :
    (axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] == 3'h7) ? slv_reg7 : 0;
	// Add user logic here
// -------------------------
// Register write detect (PIXEL WRITE: DATA+ADDR LOCKED TOGETHER)
// -------------------------
wire [2:0] wr_sel = (S_AXI_AWVALID) ?
    S_AXI_AWADDR[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] :
    axi_awaddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB];

wire wr_fire = S_AXI_WVALID && S_AXI_WREADY;
wire wr_reg1 = wr_fire && (wr_sel == 3'h1);

// Latch pixel byte AND pixel address on the SAME cycle we assert pix_we.
// This guarantees addr/data alignment even if REG2 write timing drifts.
reg [7:0] pix_data_lat;
reg [9:0] pix_addr_lat;
reg       pix_we_lat;
reg [9:0] pix_addr_hold;

always @(posedge S_AXI_ACLK) begin
  if (!S_AXI_ARESETN) begin
    pix_addr_hold <= 10'd0;
    pix_data_lat  <= 8'd0;
    pix_addr_lat  <= 10'd0;
    pix_we_lat    <= 1'b0;
  end else begin
    // latch address the moment REG2 is written
    if (wr_fire && (wr_sel == 3'h2))
      pix_addr_hold <= S_AXI_WDATA[9:0];

    // latch data+addr together when REG1 is written
    pix_we_lat <= wr_reg1;
    if (wr_reg1) begin
      pix_data_lat <= S_AXI_WDATA[7:0];
      pix_addr_lat <= pix_addr_hold;  // use held address, not slv_reg2
    end
  end
end

// -------------------------
// Aliases to nn_core
// -------------------------
wire        start_bit   = slv_reg0[0];
wire [7:0]  pix_data_w  = pix_data_lat;
wire [9:0]  pix_addr_w  = pix_addr_lat;
wire        pix_we      = pix_we_lat;

wire        nn_done;
wire [3:0]  nn_pred;
wire signed [31:0] nn_dbg_score0;
wire signed [31:0] nn_dbg_acc0;
wire signed [31:0] nn_dbg_b20;
wire signed [31:0] dbg_partial4_o0;
wire signed [31:0] dbg_w2_00;
// -------------------------
// NN core instance
// -------------------------
nn_core #(
  .N_IN(784),
  .N_OUT(10)
) u_nn (
  .clk(S_AXI_ACLK),
  .rst(!S_AXI_ARESETN),

  .start(start_bit),
  .done(nn_done),

  .pix_we(pix_we),
  .pix_addr(pix_addr_w),
  .pix_data(pix_data_w),

  .b1_en(b1_en),
  .b1_addr(b1_addr),
  .b1_dout(b1_dout),
  .w1_en(w1_en),
  .w1_addr(w1_addr),
  .w1_dout(w1_dout),
  .w2_en(w2_en),
  .w2_addr(w2_addr),
  .w2_dout(w2_dout),
  .b2_en(b2_en),
  .b2_addr(b2_addr),
  .b2_dout(b2_dout),

  .dbg_score0(nn_dbg_score0),
  .dbg_acc0  (nn_dbg_acc0),
  .dbg_b20   (nn_dbg_b20),
  .dbg_partial4_o0(dbg_partial4_o0),
  .dbg_w2_00(dbg_w2_00),
  .predicted(nn_pred)
);

// -------------------------
// HW drives slv_reg3 (CLEAR ON START, UPDATE ON DONE)
// -------------------------
reg start_d;
always @(posedge S_AXI_ACLK) begin
  if (!S_AXI_ARESETN) start_d <= 1'b0;
  else start_d <= start_bit;
end
wire start_pulse = start_bit & ~start_d;

always @(posedge S_AXI_ACLK) begin
  if (!S_AXI_ARESETN) begin
    slv_reg3 <= 32'd0;
  end else begin
    // clear status at the beginning of every run
    if (start_pulse) begin
      slv_reg3 <= 32'd0;
    end else if (nn_done) begin
      slv_reg3 <= {24'd0, nn_pred, 3'd0, 1'b1};
    end
  end
end
// -------------------------
// HW drives slv_reg4 (debug logit for class 0)
// -------------------------
always @(posedge S_AXI_ACLK) begin
  if (!S_AXI_ARESETN) begin
    slv_reg4 <= 32'd0;
  end else begin
    // optional: clear at start so you know it's "fresh"
    if (start_pulse) begin
      slv_reg4 <= 32'd0;
    end else if (nn_done) begin
      slv_reg4 <= nn_dbg_score0;   // capture when inference finishes
    end
  end
end
// -------------------------
// HW drives slv_reg5 (debug acc0 before bias)
// -------------------------
always @(posedge S_AXI_ACLK) begin
  if (!S_AXI_ARESETN) begin
    slv_reg5 <= 32'd0;
  end else begin
    if (start_pulse) begin
      slv_reg5 <= 32'd0;
    end else if (nn_done) begin
      slv_reg5 <= nn_dbg_acc0;
    end
  end
end
//hw drives 6 and 7
always @(posedge S_AXI_ACLK) begin
  if (!S_AXI_ARESETN) begin
    slv_reg6 <= 32'd0;
    slv_reg7 <= 32'd0;
  end else begin
    if (start_pulse) begin
      slv_reg6 <= 32'd0;
      slv_reg7 <= 32'd0;
    end else if (nn_done) begin
      slv_reg6 <= dbg_partial4_o0;
      slv_reg7 <= dbg_w2_00;
    end
  end
end
	// User logic ends

	endmodule