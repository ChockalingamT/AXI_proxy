`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/26/2024 08:14:58 PM
// Design Name: 
// Module Name: noc2aximst
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


`define GLOB_PHYS_ADDR_BITS 32
`define GLOB_ADDR_INCR 4
`define AXIDW 32
`define AW 4

`define NOC_FLIT_SIZE 34
//`define this_coh_flit_size 34
`define ARCH_NOC_FLIT_SIZE 34
`define DMA_NOC_FLIT_SIZE 34

`define PREAMBLE_WIDTH 2
`define RESERVED_WIDTH 8
`define MSG_TYPE_WIDTH 5
`define NEXT_ROUTING_WIDTH 5
`define ARCH_BITS 32

`define cacheline 8

//`define RSP_AHB_RD 30
//`define RSP_DATA 24
//`define RSP_DATA_DMA
`define XRESP_OKAY 0
`define XRESP_EXOKAY 1
`define XRESP_SLVERR 2
`define XRESP_DECERR 3
`define XBURST_FIXED 0
`define XBURST_INCR  1
`define XBURST_WRAP  2

`define local_yx 3	

/*typedef enum logic [1:0] {

    XBURST_FIXED = 2'b00,
    XBURST_INCR  = 2'b01,
    XBURST_WRAP  = 2'b10

} burst_type;*/

typedef enum logic [4:0] {

    RSP_DATA     = 5'b11000,
	RSP_EDATA    = 5'b11001,
    RSP_DATA_DMA = 5'b11011,
	RSP_AHB_RD   = 5'b11110//,
    //XRESP_SLVERR = 2'b10,
    //XRESP_DECERR = 2'b11

} resp_type;

typedef enum logic [4:0] {

    REQ_GETS_W  = 5'b11000,
    REQ_GETM_W  = 5'b11001,
    REQ_GETS_B  = 5'b11100,
    REQ_GETS_HW = 5'b11101,
    REQ_GETM_B  = 5'b11110,
    REQ_GETM_HW = 5'b11111,

    AHB_RD      = 5'b11010,
    AHB_WR      = 5'b11011

} req_type;

typedef enum logic [4:0] {


    DMA_TO_DEV   = 5'b11001,
    DMA_FROM_DEV  = 5'b11010,

    REQ_DMA_READ = 5'b11110,
    REQ_DMA_WRITE = 5'b11111

} dma_req_type;

typedef enum logic [2:0] {

    XSIZE_BYTE  = 3'b000,
    XSIZE_HWORD = 3'b001,
    XSIZE_WORD  = 3'b010,
    XSIZE_DWORD = 3'b011

} transfer_size;

typedef enum logic [1:0] {

    PREAMBLE_HEADER = 2'b10,
    PREAMBLE_TAIL   = 2'b01,
    PREAMBLE_BODY   = 2'b00,
    PREAMBLE_1FLIT  = 2'b11

} preamble_type;

typedef struct {

    logic [     `MSG_TYPE_WIDTH-1 : 0] msg;
    logic [ `ARCH_NOC_FLIT_SIZE-1 : 0] coh_flit;
	logic [  `DMA_NOC_FLIT_SIZE-1 : 0] dma_flit;
    logic [                     2 : 0] ax_prot;
    logic [`GLOB_PHYS_ADDR_BITS-1 : 0] ax_addr;
    //logic [			7 : 0] count;

    logic [`GLOB_PHYS_ADDR_BITS-1 : 0] ar_addr;
    logic [                    31 : 0] count;
    logic                              burst_flag;
    //logic [			            3 : 0] batch;
    logic [                     7 : 0] ar_len;
    logic [                     2 : 0] ar_size;
    logic [                     2 : 0] ar_prot;
    //logic                             ar_VALID,
    //logic                             ar_READY,

    //logic [              `AXIDW-1 : 0] r_data;
    //resp_type                          r_resp;
    //logic                              r_last;
    //logic                             r_VALID,
    //logic                             r_READY,

    logic [`GLOB_PHYS_ADDR_BITS-1 : 0] aw_addr;
    logic [                     7 : 0] aw_len;
    logic [                     2 : 0] aw_size;
    logic [                     2 : 0] aw_prot;

    logic [						1 : 0] sample_flag;

    //logic                             aw_VALID,
    //logic                             aw_READY,

    //logic [              `AXIDW-1 : 0] w_data;
    //logic [                 `AW-1 : 0] w_strb;
    //logic                              w_last;
    //logic                             W_VALID,
    //logic                             W_READY,

    //resp_type                          b_resp;
    //logic                             B_VALID,
    //logic                             B_READY,

} reg_type;


module noc2aximst 

#(
    parameter tech        = 0,
    parameter mst_index	  = 0,
    parameter axitran     = 0,
    parameter little_end  = 0,
    parameter eth_dma     = 0,
    parameter narrow_noc  = 0,
    parameter cacheline   = 8
	//parameter this_coh_flit_size = 34
) (
    input logic       ARESETn,
    input logic       ACLK,
    input logic  [`local_yx-1:0] 			  local_y,
    input logic  [`local_yx-1:0]			  local_x,

    output logic                              AR_ID,
    output logic [`GLOB_PHYS_ADDR_BITS-1 : 0] AR_ADDR,
    output logic [                     7 : 0] AR_LEN,
    output logic [                     2 : 0] AR_SIZE,
    output logic [		       		   1 : 0] AR_BURST,
    output logic 			      			  AR_LOCK,
    output logic [                     2 : 0] AR_PROT,
    output logic                              AR_VALID,
    input  logic                              AR_READY,

    input  logic                              R_ID,
    input  logic [              `AXIDW-1 : 0] R_DATA,
    input  logic [		       		   1 : 0] R_RESP,		// not used
    input  logic                              R_LAST,
    input  logic                              R_VALID,
    output logic                              R_READY,

    output logic                              AW_ID,
    output logic [`GLOB_PHYS_ADDR_BITS-1 : 0] AW_ADDR,
    output logic [                     7 : 0] AW_LEN,
    output logic [                     2 : 0] AW_SIZE,
    output logic [		       		   1 : 0] AW_BURST,
    output logic 			      			  AW_LOCK,
    output logic [                     2 : 0] AW_PROT,
    output logic                              AW_VALID,
    input  logic                              AW_READY,

    output logic [              `AXIDW-1 : 0] W_DATA,
    output logic [                 `AW-1 : 0] W_STRB,
    output logic                              W_LAST,
    output logic                              W_VALID,
    input  logic                              W_READY,

    input logic                               B_ID,	
    input  logic [		      		   1 : 0] B_RESP,		// not used
    input  logic                              B_VALID,		// not used
    output logic                              B_READY,		

    output logic                              coherence_req_rdreq,
    input  logic [ `ARCH_NOC_FLIT_SIZE-1 : 0] coherence_req_data_out,
    input  logic                              coherence_req_empty,

    output logic                              coherence_rsp_snd_wrreq,
    output logic [ `ARCH_NOC_FLIT_SIZE-1 : 0] coherence_rsp_snd_data_in,
    input  logic                              coherence_rsp_snd_full,

    output logic                              dma_rcv_rdreq,
    input  logic [  `DMA_NOC_FLIT_SIZE-1 : 0] dma_rcv_data_out,
    input  logic                              dma_rcv_empty,

    output logic                              dma_snd_wrreq,
    output logic [  `DMA_NOC_FLIT_SIZE-1 : 0] dma_snd_data_in,
    input  logic                              dma_snd_full

);


    assign AR_ID = mst_index;
    assign AW_ID = mst_index;

    assign AW_LOCK = 1'b0;
    assign AR_LOCK = 1'b0;

    assign AR_BURST = `XBURST_INCR;
    assign AW_BURST = `XBURST_INCR;

    logic [`ARCH_NOC_FLIT_SIZE-1  : 0] header;
	logic [`ARCH_NOC_FLIT_SIZE-1  : 0] header_reg;
    logic                              sample_header;


    logic [ `DMA_NOC_FLIT_SIZE-1  : 0] dma_header;
	logic [ `DMA_NOC_FLIT_SIZE-1  : 0] dma_header_reg;
    logic                         	   sample_dma_header;
    

    logic [`RESERVED_WIDTH-1 : 0] reserved;
    logic [`PREAMBLE_WIDTH-1 : 0] preamble;
    logic [`PREAMBLE_WIDTH-1 : 0] dma_preamble;

    logic [`AXIDW-1 : 0] rd_data_flit;
	logic [`AXIDW-1 : 0] wr_data_flit;
    //logic [`PREAMBLE_WIDTH+`AXIDW-1 : 0] wr_data_flit;
    integer i;

    logic [              4 : 0] current_state;
    logic [              4 : 0] next_state;

    parameter RECEIVE_HEADER  = 5'b00000;
    parameter RECEIVE_ADDRESS = 5'b00001;
    parameter RECEIVE_LENGTH  = 5'b00010;
    parameter READ_REQUEST    = 5'b00011;
    parameter SEND_HEADER     = 5'b00100;
    parameter SEND_DATA       = 5'b00101;
    parameter WRITE_REQUEST   = 5'b00110;
    //parameter WRITE_WAIT      = 5'b00111;
    parameter WRITE_DATA      = 5'b01000;
    //parameter WRITE_LAST_DATA = 5'b01001;

    parameter DMA_RECEIVE_ADDRESS     = 5'b01010;
    parameter DMA_RECEIVE_READ_LENGTH = 5'b01011;
    parameter DMA_READ_REQUEST    = 5'b01100;
    parameter DMA_SEND_HEADER     = 5'b01101;
    parameter DMA_SEND_DATA       = 5'b01110;

    parameter DMA_RECEIVE_WRITE_LENGTH = 5'b01111;
    parameter DMA_WRITE_REQUEST        = 5'b10000;
    //parameter DMA_WRITE_WAIT           = 5'b10001;
    parameter DMA_WRITE_DATA           = 5'b10010;
    //parameter DMA_WRITE_LAST_DATA      = 5'b10011;

    reg_type cs, ns;

    always @(*) begin

        ns = cs;

        preamble 	 = coherence_req_data_out[`ARCH_NOC_FLIT_SIZE-1:`ARCH_NOC_FLIT_SIZE-`PREAMBLE_WIDTH];
		dma_preamble = dma_rcv_data_out      [`DMA_NOC_FLIT_SIZE-1:`DMA_NOC_FLIT_SIZE-`PREAMBLE_WIDTH];        

        reserved                  = 0;
        sample_header             = 1'b0;
		sample_dma_header         = 1'b0;

        coherence_req_rdreq       = 0;
        coherence_rsp_snd_data_in = 0;
        coherence_rsp_snd_wrreq   = 1'b0;

        dma_rcv_rdreq   = 0;
        dma_snd_data_in = 0;
        dma_snd_wrreq   = 1'b0;
	
		R_READY = 1'b0;
		W_STRB  = 0;
		W_VALID = 1'b0;
		W_LAST  = 1'b0;

        case (current_state)

            RECEIVE_HEADER: begin
                if (coherence_req_empty == 1'b0) begin
                    coherence_req_rdreq = 1'b1;
                    ns.msg = coherence_req_data_out[`ARCH_NOC_FLIT_SIZE - `PREAMBLE_WIDTH - 12 - 1:`ARCH_NOC_FLIT_SIZE - `PREAMBLE_WIDTH - 12 - `MSG_TYPE_WIDTH];
                    reserved = coherence_req_data_out[`ARCH_NOC_FLIT_SIZE - `PREAMBLE_WIDTH - 12 - `MSG_TYPE_WIDTH - 1:`ARCH_NOC_FLIT_SIZE - `PREAMBLE_WIDTH - 12 - `MSG_TYPE_WIDTH - `RESERVED_WIDTH];
                    ns.ax_prot = reserved[2:0];
                    sample_header = 1'b1;
                    next_state = RECEIVE_ADDRESS;
                end
				else if (dma_rcv_empty == 1'b0) begin
		    		dma_rcv_rdreq = 1'b1;
		    		ns.msg = dma_rcv_data_out[`DMA_NOC_FLIT_SIZE - `PREAMBLE_WIDTH - 12 - 1:`DMA_NOC_FLIT_SIZE - `PREAMBLE_WIDTH - 12 - `MSG_TYPE_WIDTH];
                    reserved = dma_rcv_data_out[`DMA_NOC_FLIT_SIZE - `PREAMBLE_WIDTH - 12 - `MSG_TYPE_WIDTH - 1:`DMA_NOC_FLIT_SIZE - `PREAMBLE_WIDTH - 12 - `MSG_TYPE_WIDTH - `RESERVED_WIDTH];
                    ns.ax_prot = reserved[2:0];
                    sample_dma_header = 1'b1;
                    next_state = DMA_RECEIVE_ADDRESS;
				end	
				ns.burst_flag = 0;
				ns.sample_flag = 2'b00;    
            end

            RECEIVE_ADDRESS: begin
                if (coherence_req_empty == 1'b0) begin
                    coherence_req_rdreq = 1'b1;
                    ns.ax_addr = coherence_req_data_out[`GLOB_PHYS_ADDR_BITS-1:0];

                    if (cs.msg == REQ_GETS_W || cs.msg == REQ_GETS_HW || cs.msg == REQ_GETS_B || cs.msg == AHB_RD) begin
                        ns.ar_prot = cs.ax_prot;
                        ns.ar_addr = ns.ax_addr;
                        if (axitran == 0) begin
                            ns.ar_len = cacheline - 1;
                            next_state = READ_REQUEST;
                        end else 
                            next_state = RECEIVE_LENGTH;

                        // TODO: Check with Joseph for correctness + combinations
			// Setting the AR_SIZE one cycle earlier since we don't need to wait for the bus
                        if (cs.msg == REQ_GETS_B) 							ns.ar_size = XSIZE_BYTE;
                        else if (cs.msg == REQ_GETS_HW) 					ns.ar_size = XSIZE_HWORD;
                        else if (`ARCH_BITS == 64 && cs.msg == REQ_GETS_W) 	ns.ar_size = XSIZE_DWORD;
                        else 												ns.ar_size = XSIZE_WORD;
                    end 

                    else if (cs.msg == REQ_GETM_W || cs.msg == REQ_GETM_HW || cs.msg == REQ_GETM_B || cs.msg == AHB_WR) begin
                        ns.aw_prot = cs.ax_prot;
                        ns.aw_addr = ns.ax_addr;
						ns.aw_len  = 0;
                        next_state = WRITE_REQUEST;
                        if (cs.msg == REQ_GETM_B) 							ns.aw_size = XSIZE_BYTE;
                        else if (cs.msg == REQ_GETM_HW) 					ns.aw_size = XSIZE_HWORD;
                        else if (`ARCH_BITS == 64 && cs.msg == REQ_GETM_W) 	ns.aw_size = XSIZE_DWORD;
                        else 												ns.aw_size = XSIZE_WORD;
                    end 
                    else
                        next_state = RECEIVE_HEADER;
                end
            end 

            RECEIVE_LENGTH: begin
                if (coherence_req_empty == 1'b0) begin
                    coherence_req_rdreq = 1'b1;
		    //TODO: Ax_LEN is 8 bits wide - in AHB code the value used to calculate the count is given in the 12 LSB (how to handle)
		    
		            ns.count = coherence_req_data_out[11:0] - 1;
		            if (ns.count > 255) begin
		                  ns.ar_len = 255;
		                  ns.count  = ns.count - 255;
		            end else begin
		                  ns.ar_len = ns.count;
		                  ns.count = 0;
		            end
		    
		            next_state = READ_REQUEST;
                end
            end

            READ_REQUEST: begin							// In this state AR_VALID is set and waiting for AR_READY (Address Channel Transaction)
			// First we check the AR_READY (protocol specification)
		        if (AR_READY == 1'b1) begin				// If AR_READY = 1, the Address transaction completes and we can send move to Data transactions & we need to send header to NoC 										to notify the CPU that the request will be served now
				// In AHB: Queue is checked in one cycle and if it is not full data are given to it in the next cycle (since we wait for bus)		        
				// In AXI: We can put data on the queue (response header) combinationally in the same cycle if AR_READY is high (avoiding 1 cycle latency)
				
					if (cs.burst_flag == 0) begin
						if (coherence_rsp_snd_full == 1'b0) begin		// If the NoC queue is available - give the response header
							next_state = SEND_DATA;
				    		coherence_rsp_snd_data_in = header_reg;
				    		coherence_rsp_snd_wrreq   = 1'b1;
					// If the NoC queue is full - move to an intermediate state to wait until it gets freed in order to send the response header before starting data transactions
					  	end else					
							next_state = SEND_HEADER;			// we need to first send the header to be able to start accepting data from the memory (AXI slave)
			   		end else // In burst-mode we don't send a header (just validate the AR channel)
					   		next_state = SEND_DATA;
				end
            end

	   		SEND_HEADER: begin					// Compared to the READ_REQUEST state: here the AR_VALID is deasserted
		    	if (coherence_rsp_snd_full == 1'b0) begin
	    	    	next_state = SEND_DATA;
            		coherence_rsp_snd_data_in = header_reg;
            		coherence_rsp_snd_wrreq   = 1'b1; 
		       	end
            end

            SEND_DATA: begin

                if (coherence_rsp_snd_full == 1'b1) 
                    R_READY = 1'b0;
                else begin
                    R_READY = 1'b1;
                    if (R_VALID == 1'b1) begin
                        coherence_rsp_snd_wrreq = 1'b1;

						// Fix endianess
						if (little_end  == 0) rd_data_flit = R_DATA;
						else begin
							for (i = 0; i < (`ARCH_BITS / 8); i = i + 1) begin
								rd_data_flit[8*i +: 8] = R_DATA[`ARCH_BITS-8*(i+1) +: 8];
							end
						end

                        if (R_LAST == 1'b1) begin
                            if (cs.count == 0) begin 
                                coherence_rsp_snd_data_in = {PREAMBLE_TAIL, rd_data_flit};
                                next_state = RECEIVE_HEADER;
                            end else begin // If another burst is needed
                                coherence_rsp_snd_data_in = {PREAMBLE_BODY, rd_data_flit};

                                if (cs.count > 255) begin
                                      ns.ar_len = 255;
                                      ns.count  = cs.count - 255; 
                                end else begin 
                                      ns.ar_len = cs.count; 
                                      ns.count = 0; 
                                end 
                                
                                if      (cs.ar_size == XSIZE_BYTE)  ns.ar_addr = cs.ar_addr + 256;
                                else if (cs.ar_size == XSIZE_HWORD) ns.ar_addr = cs.ar_addr + 512;
                                else if (cs.ar_size == XSIZE_WORD)  ns.ar_addr = cs.ar_addr + 1024;
                                else if (cs.ar_size == XSIZE_DWORD) ns.ar_addr = cs.ar_addr + 2048; 
                                
                                ns.burst_flag = 1;
                                next_state = READ_REQUEST;
                            end
                                          
                        end else
                            coherence_rsp_snd_data_in = {PREAMBLE_BODY, rd_data_flit};
                    end
                end
            end 

            WRITE_REQUEST: begin			// In this state AW_VALID is set and waiting for AW_READY

				if (AW_READY == 1'b1) begin		// If AW_READY = 1, the Address transaction completes and we can move to Data transactions
                    next_state = WRITE_DATA;
		    		ns.sample_flag = 2'b00;
                    if (coherence_req_empty == 1'b0) begin		// If the NoC queue is available - read the first data to be written
                        coherence_req_rdreq = 1'b1;
                        ns.coh_flit = coherence_req_data_out;
                        if (preamble == PREAMBLE_BODY)      ns.sample_flag = 2'b01;	// Instead of WRITE_WAIT STATE
                        else if (preamble == PREAMBLE_TAIL) ns.sample_flag = 2'b10;


                    end
                end
            end     
/*
	   WRITE_WAIT: begin					    // Compared to the WRITE_REQUEST state: here the AR_VALID is deasserted
		        if (coherence_req_empty == 1'b0) begin
                        	coherence_req_rdreq = 1'b1;
                        	ns.flit = coherence_req_data_out;
                        	if (preamble == PREAMBLE_BODY)      next_state = WRITE_DATA;
                        	else if (preamble == PREAMBLE_TAIL) next_state = WRITE_LAST_DATA;
		        end
            end
*/
         	WRITE_DATA: begin

				W_VALID = 1'b0;
				W_LAST  = 1'b0;

				if (cs.sample_flag == 2'b01 || cs.sample_flag == 2'b10) begin	// If one data has already been read
					W_VALID = 1'b1;
					W_LAST  = 1'b1;

					// Fix endianess
					if (little_end  == 0) begin
						wr_data_flit = cs.coh_flit[`ARCH_BITS-1 : 0];
						if      (cs.aw_size == XSIZE_BYTE)  W_STRB[`AW-1] = 1'b1;
						else if (cs.aw_size == XSIZE_HWORD) W_STRB[`AW-1:`AW-2] = 2'b1;
						else if (cs.aw_size == XSIZE_WORD)  W_STRB[`AW-1:`AW-4] = 4'b1111;
						else if (cs.aw_size == XSIZE_DWORD) W_STRB = 8'b11111111;
					end else begin
						for (i = 0; i < (`ARCH_BITS / 8); i = i + 1) begin
							wr_data_flit[8*i +: 8] = cs.coh_flit[`ARCH_BITS-8*(i+1) +: 8];
						end
						if      (cs.aw_size == XSIZE_BYTE)  W_STRB[0] = 1'b1;
						else if (cs.aw_size == XSIZE_HWORD) W_STRB[1:0] = 2'b1;
						else if (cs.aw_size == XSIZE_WORD)  W_STRB[3:0] = 4'b1111;
						else if (cs.aw_size == XSIZE_DWORD) W_STRB = 8'b11111111;
					end
                
               		W_DATA = wr_data_flit;

					if (W_READY == 1'b1) begin	// If the data can be read in the same cycle
						ns.sample_flag = 2'b00; // The write process is complete
						if (cs.sample_flag == 2'b01) begin	// Unless this was only a body flit
                			if (cs.aw_size == XSIZE_WORD)       ns.aw_addr = cs.aw_addr + 4'b0100;
                			else if (cs.aw_size == XSIZE_BYTE)  ns.aw_addr = cs.aw_addr + 4'b0001;
                			else if (cs.aw_size == XSIZE_HWORD) ns.aw_addr = cs.aw_addr + 4'b0010;
                			else if (cs.aw_size == XSIZE_DWORD) ns.aw_addr = cs.aw_addr + 4'b1000;
                			next_state = WRITE_REQUEST;
						end else 
							next_state = RECEIVE_HEADER;
                	end

				end else if (cs.sample_flag == 2'b00 && coherence_req_empty == 1'b0) begin	// If no data have been received yet and there are available data
					W_VALID = 1'b1;
					W_LAST  = 1'b1;
					coherence_req_rdreq = 1'b1;			// Read this data
					ns.coh_flit = coherence_req_data_out;

					// Fix endianess
					if (little_end  == 0) begin
						wr_data_flit = ns.coh_flit[`ARCH_BITS-1 : 0];
						if      (cs.aw_size == XSIZE_BYTE)  W_STRB[`AW-1] = 1'b1;
						else if (cs.aw_size == XSIZE_HWORD) W_STRB[`AW-1:`AW-2] = 2'b1;
						else if (cs.aw_size == XSIZE_WORD)  W_STRB[`AW-1:`AW-4] = 4'b1111;
						else if (cs.aw_size == XSIZE_DWORD) W_STRB = 8'b11111111;
					end else begin
						for (i = 0; i < (`ARCH_BITS / 8); i = i + 1) begin
							wr_data_flit[8*i +: 8] = ns.coh_flit[`ARCH_BITS-8*(i+1) +: 8];
						end
						if      (cs.aw_size == XSIZE_BYTE)  W_STRB[0] = 1'b1;
						else if (cs.aw_size == XSIZE_HWORD) W_STRB[1:0] = 2'b1;
						else if (cs.aw_size == XSIZE_WORD)  W_STRB[3:0] = 4'b1111;
						else if (cs.aw_size == XSIZE_DWORD) W_STRB = 8'b11111111;
					end

				   	W_DATA = wr_data_flit;				

					if (W_READY == 1'b1) begin		// If it can already be read 
						ns.sample_flag = 2'b00;		// The write process is complete
						if (preamble == PREAMBLE_BODY) begin	// Unless this was only a body flit
		        			if (cs.aw_size == XSIZE_WORD)       ns.aw_addr = cs.aw_addr + 4'b0100;
		        			else if (cs.aw_size == XSIZE_BYTE)  ns.aw_addr = cs.aw_addr + 4'b0001;
		        			else if (cs.aw_size == XSIZE_HWORD) ns.aw_addr = cs.aw_addr + 4'b0010;
		        			else if (cs.aw_size == XSIZE_DWORD) ns.aw_addr = cs.aw_addr + 4'b1000;
		        			next_state = WRITE_REQUEST;
						end else if (preamble == PREAMBLE_TAIL)
							next_state = RECEIVE_HEADER;
				    end
					else begin	// If it cannot be read, wait in this state with a new flag
						if (preamble == PREAMBLE_BODY)      ns.sample_flag = 2'b01;
	                	else if (preamble == PREAMBLE_TAIL) ns.sample_flag = 2'b10;
					end
				end
            end
/*
            WRITE_LAST_DATA: begin

		if (little_end  == 0) begin
			wr_data_flit = cs.flit[`ARCH_BITS-1 : 0];
			if      (cs.aw_size == XSIZE_BYTE)  W_STRB[`AW-1] = 1'b1;
			else if (cs.aw_size == XSIZE_HWORD) W_STRB[`AW-1:`AW-2] = 2'b1;
			else if (cs.aw_size == XSIZE_WORD)  W_STRB[`AW-1:`AW-4] = 4'b1111;
			else if (cs.aw_size == XSIZE_DWORD) W_STRB = 8'b11111111;

		end else begin
			for (i = 0; i < (`ARCH_BITS / 8); i = i + 1) begin
				wr_data_flit[8*i +: 8] = cs.flit[`ARCH_BITS-8*(i+1) +: 8];
			end
			if      (cs.aw_size == XSIZE_BYTE)  W_STRB[0] = 1'b1;
			else if (cs.aw_size == XSIZE_HWORD) W_STRB[1:0] = 2'b1;
			else if (cs.aw_size == XSIZE_WORD)  W_STRB[3:0] = 4'b1111;
			else if (cs.aw_size == XSIZE_DWORD) W_STRB = 8'b11111111;
		end
            
                W_DATA = wr_data_flit;
                
                if (W_READY == 1'b1) begin
                    next_state = RECEIVE_HEADER;
                end
            end
*/
///// DMA PATH ///////
	   
            DMA_RECEIVE_ADDRESS: begin
                if (dma_rcv_empty == 1'b0) begin
                    dma_rcv_rdreq = 1'b1;
                    ns.ax_addr = dma_rcv_data_out[`GLOB_PHYS_ADDR_BITS-1:0];

                    if (cs.msg == DMA_TO_DEV || cs.msg == REQ_DMA_READ) begin
                        ns.ar_prot = cs.ax_prot;
                        ns.ar_addr = ns.ax_addr;
						next_state = DMA_RECEIVE_READ_LENGTH;
		    			if (eth_dma == 0) begin
							if (`ARCH_BITS == 64) ns.ar_size = XSIZE_DWORD;
							else		      	  ns.ar_size = XSIZE_WORD;
		    			end else
							ns.ar_size = XSIZE_WORD;

		    		end else begin
                        ns.aw_prot = cs.ax_prot;
                        ns.aw_addr = ns.ax_addr;			
		    			if (cs.msg == DMA_FROM_DEV)
							next_state = DMA_RECEIVE_WRITE_LENGTH;
		    			else
							next_state = DMA_WRITE_REQUEST;
		    		end
						if (eth_dma == 0) begin
							if (`ARCH_BITS == 64) ns.aw_size = XSIZE_DWORD;
							else		      	  ns.aw_size = XSIZE_WORD;
						end else
							ns.aw_size = XSIZE_WORD;

		    		end
	    		end
	   //end


	   		DMA_RECEIVE_READ_LENGTH: begin
       			if (dma_rcv_empty == 1'b0) begin
                    dma_rcv_rdreq = 1'b1;	

		    		ns.count = dma_rcv_data_out[31:0] - 1;
					if (ns.count > 255) begin
						ns.ar_len = 255;
						ns.count  = ns.count - 255;
					end else begin
						ns.ar_len = ns.count;
						ns.count = 0;
					end
		    		next_state = DMA_READ_REQUEST;
				end
	   		end

		 	DMA_READ_REQUEST: begin

			   	if (AR_READY == 1'b1) begin				
					if (cs.burst_flag == 0) begin
						if (dma_snd_full == 1'b0) begin
							next_state = DMA_SEND_DATA;		// If the NoC queue is available - give the response header
				           	dma_snd_data_in = header_reg;
				           	dma_snd_wrreq   = 1'b1;
						// If the NoC queue is full - move to an intermediate state to wait until it gets freed in order to send the response header before starting data transactions
						end else					
							next_state = DMA_SEND_HEADER;			
					end else	// In burst-mode we don't send a header (just validate the AR channel)
						next_state = DMA_SEND_DATA;
				end
		  	end

		  	DMA_SEND_HEADER: begin					// Compared to the READ_REQUEST state: here the AR_VALID is deasserted
				if (dma_snd_full == 1'b0) begin
					next_state = DMA_SEND_DATA;
	                dma_snd_data_in = header_reg;
	                dma_snd_wrreq   = 1'b1; 
			   	end
		  	end


          	DMA_SEND_DATA: begin

           		if (dma_snd_full == 1'b1) 
                    R_READY = 1'b0;
                else begin
                    R_READY = 1'b1;
                    if (R_VALID == 1'b1) begin
                        dma_snd_wrreq = 1'b1;

						// Fix endianess
						if (little_end  == 0) rd_data_flit = R_DATA;
						else begin
							for (i = 0; i < (`ARCH_BITS / 8); i = i + 1) begin
								rd_data_flit[8*i +: 8] = R_DATA[`ARCH_BITS-8*(i+1) +: 8];
							end
						end

                        if (R_LAST == 1'b1) begin
                            if (cs.count == 0) begin 
                                dma_snd_data_in = {PREAMBLE_TAIL, rd_data_flit};
                                next_state = RECEIVE_HEADER;
                            end else begin
                                dma_snd_data_in = {PREAMBLE_BODY, rd_data_flit};

                                if (cs.count > 255) begin
                                      ns.ar_len = 255;
                                      ns.count  = cs.count - 255; 
                                end else begin 
                                      ns.ar_len = cs.count; 
                                      ns.count = 0; 
                                end 
                                
								if 	(cs.ar_size == XSIZE_WORD)  	ns.ar_addr = cs.ar_addr + 1024;
                                else if (cs.ar_size == XSIZE_DWORD) ns.ar_addr = cs.ar_addr + 2048; 

                                ns.burst_flag = 1;		// Give the new address for the new burst
                                next_state = DMA_READ_REQUEST;
                            end  
                         end else
                            dma_snd_data_in = {PREAMBLE_BODY, rd_data_flit};
                    end
                end
            end 

		   	DMA_RECEIVE_WRITE_LENGTH: begin

		    	if (dma_rcv_empty == 1'b0) begin
		        	dma_rcv_rdreq = 1'b1;	
				
					// FIXME: Verify reading the queue for length
					
					ns.count = dma_rcv_data_out[31:0] - 1;
					if (ns.count > 255) begin
						ns.aw_len = 255;
						ns.count  = ns.count - 255;

					end else begin
						ns.aw_len = ns.count;
						ns.count = 0;
					end
					
					next_state = DMA_WRITE_REQUEST;

				end
		 	end

           	DMA_WRITE_REQUEST: begin			// In this state AW_VALID is set and waiting for AW_READY

				if (AW_READY == 1'b1) begin		// If AW_READY = 1, the Address transaction completes and we can move to Data transactions
                    next_state = DMA_WRITE_DATA;
		    		ns.sample_flag = 2'b00;
                    if (dma_rcv_empty == 1'b0) begin		// If the NoC queue is available - read the first data to be written (prefetch)
                        dma_rcv_rdreq = 1'b1;
                        ns.dma_flit = dma_rcv_data_out;

						// FIXME
                        //ns.sample_flag = 2'b01;
                        if 		(dma_preamble == PREAMBLE_BODY) ns.sample_flag = 2'b01;	// We have a burst from accelerator
                        else if (dma_preamble == PREAMBLE_TAIL) ns.sample_flag = 2'b10;	// We have a single transaction from ETH

                    end
                end
            end     

			
			// Different operations from accelerator and ETH
            DMA_WRITE_DATA: begin

				W_VALID = 1'b1;
				W_LAST  = 1'b0;

				if (cs.sample_flag == 2'b01 || cs.sample_flag == 2'b10) begin
					if (cs.aw_len == 0 || cs.sample_flag == 2'b10) W_LAST = 1'b1;	// If end of burst or 1-beat transaction (aw_len is invalid)
			
					// Fix endianess
					if (little_end  == 0) begin
						wr_data_flit = cs.dma_flit[`ARCH_BITS-1 : 0];
						if 		(cs.aw_size == XSIZE_WORD)  W_STRB[`AW-1:`AW-4] = 4'b1111;
						else if (cs.aw_size == XSIZE_DWORD) W_STRB = 8'b11111111;

					end else begin
						for (i = 0; i < (`ARCH_BITS / 8); i = i + 1) begin
							wr_data_flit[8*i +: 8] = cs.dma_flit[`ARCH_BITS-8*(i+1) +: 8];
						end
						if      (cs.aw_size == XSIZE_WORD)  W_STRB[3:0] = 4'b1111;
						else if (cs.aw_size == XSIZE_DWORD) W_STRB = 8'b11111111;
					end
               
               		W_DATA = wr_data_flit;

					if (W_READY == 1'b1) begin
						ns.sample_flag = 2'b00;

						if (cs.aw_len == 0) begin
							if (cs.count == 0 || cs.sample_flag == 2'b10) // If end of burst or 1-beat transaction (aw_len/aw_count are invalid)
								next_state = RECEIVE_HEADER;
							else begin
								next_state = DMA_WRITE_REQUEST;
								if (cs.count > 255) begin
                                	ns.aw_len = 255;
                                  	ns.count  = cs.count - 255; 
                               	end else begin 
                                 	ns.aw_len = cs.count; 
                                   	ns.count = 0; 
                              	end 
                    			if 		(cs.aw_size == XSIZE_WORD)  ns.aw_addr = cs.aw_addr + 4'b0100;
                    			else if (cs.aw_size == XSIZE_DWORD) ns.aw_addr = cs.aw_addr + 4'b1000;

                    			if (dma_rcv_empty == 1'b0) begin		// If the NoC queue is available - read the first data to be written
                        			dma_rcv_rdreq = 1'b1;
                        			ns.dma_flit = dma_rcv_data_out;
                        			ns.sample_flag = 2'b01;
                    			end

							end					
						end else begin
                    		if (dma_rcv_empty == 1'b0) begin		// If the NoC queue is available - read the first data to be written
                        		dma_rcv_rdreq = 1'b1;
                        		ns.dma_flit = dma_rcv_data_out;
                        		ns.sample_flag = 2'b01;
                    		end				
							ns.aw_len = cs.aw_len - 1;
                		end
					end


				end else if (cs.sample_flag == 2'b00 && dma_rcv_empty == 1'b0) begin	// If no data has been prefetched and there is something available

					if (cs.aw_len == 0) begin
						W_LAST = 1'b1;
						ns.sample_flag = 2'b01;
					end
					else if (dma_preamble == PREAMBLE_TAIL) begin
						W_LAST = 1'b1;
						ns.sample_flag = 2'b10;
					end
					
					dma_rcv_rdreq = 1'b1;
					ns.dma_flit = dma_rcv_data_out;

					// Fix endianess
					if (little_end  == 0) begin
						wr_data_flit = ns.dma_flit[`ARCH_BITS-1 : 0];
						if 	(cs.aw_size == XSIZE_WORD)  W_STRB[`AW-1:`AW-4] = 4'b1111;
						else if (cs.aw_size == XSIZE_DWORD) W_STRB = 8'b11111111;

					end else begin
						for (i = 0; i < (`ARCH_BITS / 8); i = i + 1) begin
							wr_data_flit[8*i +: 8] = ns.dma_flit[`ARCH_BITS-8*(i+1) +: 8];
						end
						if      (cs.aw_size == XSIZE_WORD)  W_STRB[3:0] = 4'b1111;
						else if (cs.aw_size == XSIZE_DWORD) W_STRB = 8'b11111111;
					end

               		W_DATA = wr_data_flit;
					

					if (W_READY == 1'b1) begin
						ns.sample_flag = 2'b00;

						if (dma_preamble == PREAMBLE_TAIL)
							next_state = RECEIVE_HEADER;

						else if (cs.aw_len == 0) begin
							if (cs.count == 0) begin
								next_state = RECEIVE_HEADER;
							end else begin
								next_state = DMA_WRITE_REQUEST;
								if (cs.count > 255) begin
                                	ns.aw_len = 255;
                                	ns.count  = cs.count - 255; 
                             	end else begin 
                                	ns.aw_len = cs.count; 
                                  	ns.count = 0; 
                               	end 
                    			if 	(cs.aw_size == XSIZE_WORD)  	ns.aw_addr = cs.aw_addr + 4'b0100;
                    			else if (cs.aw_size == XSIZE_DWORD) ns.aw_addr = cs.aw_addr + 4'b1000;
							end
						end					
						else		
							ns.aw_len = cs.aw_len - 1;

					end
				end

            end

/*
            DMA_WRITE_DATA: begin

				W_VALID = 1'b1;
				W_LAST  = 1'b0;

				if (cs.sample_flag == 2'b01) begin		
					if (cs.aw_len == 0) W_LAST = 1'b1;
			
					// Fix endianess
					if (little_end  == 0) begin
						wr_data_flit = cs.dma_flit[`ARCH_BITS-1 : 0];
						if 		(cs.aw_size == XSIZE_WORD)  W_STRB[`AW-1:`AW-4] = 4'b1111;
						else if (cs.aw_size == XSIZE_DWORD) W_STRB = 8'b11111111;

					end else begin
						for (i = 0; i < (`ARCH_BITS / 8); i = i + 1) begin
							wr_data_flit[8*i +: 8] = cs.dma_flit[`ARCH_BITS-8*(i+1) +: 8];
						end
						if      (cs.aw_size == XSIZE_WORD)  W_STRB[3:0] = 4'b1111;
						else if (cs.aw_size == XSIZE_DWORD) W_STRB = 8'b11111111;
					end
               
               		W_DATA = wr_data_flit;

					if (W_READY == 1'b1) begin
						ns.sample_flag = 2'b00;

						if (cs.aw_len == 0) begin
							if (cs.count == 0) 
								next_state = RECEIVE_HEADER;
							else begin
								next_state = DMA_WRITE_REQUEST;
								if (cs.count > 255) begin
                                	ns.aw_len = 255;
                                  	ns.count  = cs.count - 255; 
                               	end else begin 
                                 	ns.aw_len = cs.count; 
                                   	ns.count = 0; 
                              	end 
                    			if 		(cs.aw_size == XSIZE_WORD)  ns.aw_addr = cs.aw_addr + 4'b0100;
                    			else if (cs.aw_size == XSIZE_DWORD) ns.aw_addr = cs.aw_addr + 4'b1000;

                    			if (dma_rcv_empty == 1'b0) begin		// If the NoC queue is available - read the first data to be written
                        			dma_rcv_rdreq = 1'b1;
                        			ns.flit = dma_rcv_data_out;
                        			ns.sample_flag = 2'b01;
                    			end

							end					
						end else begin
                    		if (dma_rcv_empty == 1'b0) begin		// If the NoC queue is available - read the first data to be written
                        		dma_rcv_rdreq = 1'b1;
                        		ns.dma_flit = dma_rcv_data_out;
                        		ns.sample_flag = 2'b01;
                    		end				
							ns.aw_len = cs.aw_len - 1;
                		end
					end


		end else if (cs.sample_flag == 2'b00 && dma_rcv_empty == 1'b0) begin

			if (cs.aw_len == 0) W_LAST = 1'b1;
			dma_rcv_rdreq = 1'b1;
			ns.flit = dma_rcv_data_out;


			if (little_end  == 0) begin
				wr_data_flit = ns.flit[`ARCH_BITS-1 : 0];
				if 	(cs.aw_size == XSIZE_WORD)  W_STRB[`AW-1:`AW-4] = 4'b1111;
				else if (cs.aw_size == XSIZE_DWORD) W_STRB = 8'b11111111;

			end else begin
				for (i = 0; i < (`ARCH_BITS / 8); i = i + 1) begin
					wr_data_flit[8*i +: 8] = ns.flit[`ARCH_BITS-8*(i+1) +: 8];
				end
				if      (cs.aw_size == XSIZE_WORD)  W_STRB[3:0] = 4'b1111;
				else if (cs.aw_size == XSIZE_DWORD) W_STRB = 8'b11111111;
			end

               		W_DATA = wr_data_flit;

			if (W_READY == 1'b1) begin
				ns.sample_flag = 2'b00;

				if (cs.aw_len == 0) begin
					if (cs.count == 0) begin
						next_state = RECEIVE_HEADER;
					end else begin
						next_state = DMA_WRITE_REQUEST;
						if (cs.count > 255) begin
                                      			ns.aw_len = 255;
                                      			ns.count  = cs.count - 255; 
                                		end else begin 
                                      			ns.aw_len = cs.count; 
                                      			ns.count = 0; 
                               			end 
                    				if 	(cs.aw_size == XSIZE_WORD)  ns.aw_addr = cs.aw_addr + 4'b0100;
                    				else if (cs.aw_size == XSIZE_DWORD) ns.aw_addr = cs.aw_addr + 4'b1000;

                    				if (dma_rcv_empty == 1'b0) begin		// If the NoC queue is available - read the first data to be written
                        				dma_rcv_rdreq = 1'b1;
                        				ns.flit = dma_rcv_data_out;
                        				ns.sample_flag = 2'b01;
                    				end
					end					
					
				end else begin
                    			if (dma_rcv_empty == 1'b0) begin		// If the NoC queue is available - read the first data to be written
                        			dma_rcv_rdreq = 1'b1;
                        			ns.flit = dma_rcv_data_out;
                        			ns.sample_flag = 2'b01;
                    			end				
					ns.aw_len = cs.aw_len - 1;
                		end
			end
		end

            end*/

/*
            DMA_WRITE_DATA2: begin

		W_VALID = 1'b0;
		W_LAST  = 1'b0;

		if (cs.sample_flag == 2'b01 || cs.sample_flag == 2'b10) begin
			W_VALID = 1'b1;
			W_LAST  = 1'b1;

			// Fix endianess
			if (little_end  == 0) begin
				wr_data_flit = cs.flit[`ARCH_BITS-1 : 0];
				if 	(cs.aw_size == XSIZE_WORD)  W_STRB[`AW-1:`AW-4] = 4'b1111;
				else if (cs.aw_size == XSIZE_DWORD) W_STRB = 8'b11111111;

			end else begin
				for (i = 0; i < (`ARCH_BITS / 8); i = i + 1) begin
					wr_data_flit[8*i +: 8] = cs.flit[`ARCH_BITS-8*(i+1) +: 8];
				end
				if      (cs.aw_size == XSIZE_WORD)  W_STRB[3:0] = 4'b1111;
				else if (cs.aw_size == XSIZE_DWORD) W_STRB = 8'b11111111;
			end
                
               		W_DATA = wr_data_flit;




			if (W_READY == 1'b1) begin
				ns.sample_flag == 2'b00;
				if (cs.sample_flag == 2'b01) begin
                    			if 	(cs.aw_size == XSIZE_WORD)  ns.aw_addr = cs.aw_addr + 4'b0100;
                    			else if (cs.aw_size == XSIZE_DWORD) ns.aw_addr = cs.aw_addr + 4'b1000;
                    			next_state = DMA_WRITE_REQUEST;
				else 
					next_state = RECEIVE_HEADER;
                	end
		end 


		end else if (cs.sample_flag == 2'b00 && dma_rcv_empty == 1'b0) begin
			W_VALID = 1'b1;
			W_LAST  = 1'b1;
			dma_rcv_rdreq = 1'b1;
			ns.flit = dma_rcv_data_out;

			// Fix endianess
			if (little_end  == 0) begin
				wr_data_flit = ns.flit[`ARCH_BITS-1 : 0];
				if 	(cs.aw_size == XSIZE_WORD)  W_STRB[`AW-1:`AW-4] = 4'b1111;
				else if (cs.aw_size == XSIZE_DWORD) W_STRB = 8'b11111111;

			end else begin
				for (i = 0; i < (`ARCH_BITS / 8); i = i + 1) begin
					wr_data_flit[8*i +: 8] = ns.flit[`ARCH_BITS-8*(i+1) +: 8];
				end
				if      (cs.aw_size == XSIZE_WORD)  W_STRB[3:0] = 4'b1111;
				else if (cs.aw_size == XSIZE_DWORD) W_STRB = 8'b11111111;
			end

               		W_DATA = wr_data_flit;

			if (W_READY == 1'b1) begin
				ns.sample_flag == 2'b00;
				if (dma_preamble == PREAMBLE_BODY) begin
                    			if 	(cs.aw_size == XSIZE_WORD)  ns.aw_addr = cs.aw_addr + 4'b0100;
                    			else if (cs.aw_size == XSIZE_DWORD) ns.aw_addr = cs.aw_addr + 4'b1000;
                    			next_state = DMA_WRITE_REQUEST;

				else if (dma_preamble == PREAMBLE_TAIL)
					next_state = RECEIVE_HEADER;
                	end
			else begin
				if 	(dma_preamble == PREAMBLE_BODY) ns.sample_flag = 2'b01;
                        	else if (dma_preamble == PREAMBLE_TAIL) ns.sample_flag = 2'b10;
			end
		end

            end
*/
        endcase
    end 

    assign AR_VALID = (current_state == READ_REQUEST || current_state == DMA_READ_REQUEST);
    assign AR_ADDR  = cs.ar_addr;
    assign AR_LEN   = cs.ar_len;
    assign AR_SIZE  = cs.ar_size;
    assign AR_PROT  = cs.ar_prot;

    assign AW_VALID = (current_state == WRITE_REQUEST || current_state == DMA_WRITE_REQUEST);
    assign AW_ADDR  = cs.aw_addr;
    assign AW_LEN   = cs.aw_len;	
    assign AW_SIZE  = cs.aw_size;
    assign AW_PROT  = cs.aw_prot;

    //assign W_VALID  = (current_state == WRITE_DATA || current_state == WRITE_LAST_DATA || current_state == DMA_WRITE_DATA);
    //assign W_LAST   = (current_state == WRITE_DATA || current_state == WRITE_LAST_DATA || current_state == DMA_WRITE_DATA);	
    //assign W_STRB   = '1;
    assign B_READY  = 1'b1;

    always @(posedge ACLK, negedge ARESETn) begin
        if (ARESETn == 1'b0) begin
            current_state <= RECEIVE_HEADER;
            next_state 	<= RECEIVE_HEADER;
            cs.msg      <= REQ_GETS_W;
            cs.coh_flit <= 0;
			cs.dma_flit <= 0;
            cs.ax_prot  <= 0; 
	        cs.ax_addr  <= 0;

            cs.ar_addr  <= 0;
            cs.count    <= 0;
            cs.burst_flag <= 0;
			cs.sample_flag <= 0;
            
            cs.ar_len   <= 0;
            cs.ar_size  <= 3'b010;
            cs.ar_prot  <= 0; 

            cs.aw_addr  <= 0;
            cs.aw_len   <= 0;
            cs.aw_size  <= 3'b010;
            cs.aw_prot  <= 0;

        end else begin
            current_state <= next_state;
            cs <= ns;
        end
    end


    // Create Response Header (COH)
    logic [	   `MSG_TYPE_WIDTH-1 : 0] input_msg_type;
    logic [	   `MSG_TYPE_WIDTH-1 : 0] msg_type;
    logic [`ARCH_NOC_FLIT_SIZE-1 : 0] header_v;
    //logic [	   `RESERVED_WIDTH-1 : 0] reserved_resp;
    logic [            		   2 : 0] origin_y;
    logic [               	   2 : 0] origin_x;
    logic [`NEXT_ROUTING_WIDTH-1 : 0] go_right;
    logic [`NEXT_ROUTING_WIDTH-1 : 0] go_left;

    always @(*) begin

		input_msg_type = coherence_req_data_out[`ARCH_NOC_FLIT_SIZE - `PREAMBLE_WIDTH - 12 - 1:`ARCH_NOC_FLIT_SIZE - `PREAMBLE_WIDTH - 12 - `MSG_TYPE_WIDTH];

		if (input_msg_type == AHB_RD) msg_type = RSP_AHB_RD; 
		else			      msg_type = RSP_DATA;
			
		//reserved_resp = 0;
		origin_y = coherence_req_data_out[`ARCH_NOC_FLIT_SIZE - `PREAMBLE_WIDTH - 3 + 2:`ARCH_NOC_FLIT_SIZE - `PREAMBLE_WIDTH - 3];
		origin_x = coherence_req_data_out[`ARCH_NOC_FLIT_SIZE - `PREAMBLE_WIDTH - 6 + 2:`ARCH_NOC_FLIT_SIZE - `PREAMBLE_WIDTH - 6];
		header_v = 0;
		header_v[`ARCH_NOC_FLIT_SIZE-1 : `ARCH_NOC_FLIT_SIZE - `PREAMBLE_WIDTH] = PREAMBLE_HEADER;
		header_v[`ARCH_NOC_FLIT_SIZE - `PREAMBLE_WIDTH - 1 : `ARCH_NOC_FLIT_SIZE - `PREAMBLE_WIDTH - 3] = local_y;
		header_v[`ARCH_NOC_FLIT_SIZE - `PREAMBLE_WIDTH - 3 - 1 : `ARCH_NOC_FLIT_SIZE - `PREAMBLE_WIDTH - 6] = local_x;
		header_v[`ARCH_NOC_FLIT_SIZE - `PREAMBLE_WIDTH - 6 - 1 : `ARCH_NOC_FLIT_SIZE - `PREAMBLE_WIDTH - 9] = origin_y;
		header_v[`ARCH_NOC_FLIT_SIZE - `PREAMBLE_WIDTH - 9 - 1 : `ARCH_NOC_FLIT_SIZE - `PREAMBLE_WIDTH - 12] = origin_x;
		header_v[`ARCH_NOC_FLIT_SIZE - `PREAMBLE_WIDTH - 12 - 1 : `ARCH_NOC_FLIT_SIZE - `PREAMBLE_WIDTH -  12 - `MSG_TYPE_WIDTH] = msg_type;
		//header_v[`ARCH_NOC_FLIT_SIZE - `PREAMBLE_WIDTH - `MSG_TYPE_WIDTH - `RESERVED_WIDTH : `ARCH_NOC_FLIT_SIZE - `PREAMBLE_WIDTH - 12 - `MSG_TYPE_WIDTH] = reserved_resp;
		
		if (local_x < origin_x)
			go_right = 5'b01000;
		else
			go_right = 5'b10111;
		
		if (local_x > origin_x)
			go_left = 5'b00100;
		else
			go_left = 5'b11011;

		if (local_y < origin_y)
			header_v[`NEXT_ROUTING_WIDTH - 1 : 0] = (5'b01110) & go_left & go_right;
		else
			header_v[`NEXT_ROUTING_WIDTH - 1 : 0] = (5'b01101) & go_left & go_right;

		if (local_y == origin_y && local_x == origin_x)
			header_v[`NEXT_ROUTING_WIDTH - 1 : 0] = 5'b10000;

		header = header_v;

    end


    // Create Response Header (DMA)
    logic [	   `MSG_TYPE_WIDTH-1 : 0] input_msg_type_dma;
    logic [	   `MSG_TYPE_WIDTH-1 : 0] msg_type_dma;
    logic [ `DMA_NOC_FLIT_SIZE-1 : 0] header_v_dma;
    //logic [`RESERVED_WIDTH-1 : 0] reserved_resp_dma;
    logic [                	   2 : 0] origin_y_dma;
    logic [                	   2 : 0] origin_x_dma;
    logic [`NEXT_ROUTING_WIDTH-1 : 0] go_right_dma;
    logic [`NEXT_ROUTING_WIDTH-1 : 0] go_left_dma;


    always @(*) begin

		input_msg_type_dma = dma_rcv_data_out[`DMA_NOC_FLIT_SIZE - `PREAMBLE_WIDTH - 12 - 1:`DMA_NOC_FLIT_SIZE - `PREAMBLE_WIDTH - 12 - `MSG_TYPE_WIDTH];

		if (input_msg_type_dma == REQ_DMA_READ) msg_type_dma = RSP_DATA_DMA; 
		else			       	    			msg_type_dma = DMA_TO_DEV;
			
		//reserved_resp_dma = 0;
		origin_y_dma = dma_rcv_data_out[`DMA_NOC_FLIT_SIZE - `PREAMBLE_WIDTH - 3 + 2:`DMA_NOC_FLIT_SIZE - `PREAMBLE_WIDTH - 3];
		origin_x_dma = dma_rcv_data_out[`DMA_NOC_FLIT_SIZE - `PREAMBLE_WIDTH - 6 + 2:`DMA_NOC_FLIT_SIZE - `PREAMBLE_WIDTH - 6];
		header_v_dma = 0;
		header_v_dma[`DMA_NOC_FLIT_SIZE-1 : `DMA_NOC_FLIT_SIZE - `PREAMBLE_WIDTH] = PREAMBLE_HEADER;
		header_v_dma[`DMA_NOC_FLIT_SIZE - `PREAMBLE_WIDTH - 1 : `DMA_NOC_FLIT_SIZE - `PREAMBLE_WIDTH - 3] = local_y;
		header_v_dma[`DMA_NOC_FLIT_SIZE - `PREAMBLE_WIDTH - 3 - 1 : `DMA_NOC_FLIT_SIZE - `PREAMBLE_WIDTH - 6] = local_x;
		header_v_dma[`DMA_NOC_FLIT_SIZE - `PREAMBLE_WIDTH - 6 - 1 : `DMA_NOC_FLIT_SIZE - `PREAMBLE_WIDTH - 9] = origin_y_dma;
		header_v_dma[`DMA_NOC_FLIT_SIZE - `PREAMBLE_WIDTH - 9 - 1 : `DMA_NOC_FLIT_SIZE - `PREAMBLE_WIDTH - 12] = origin_x_dma;
		header_v_dma[`DMA_NOC_FLIT_SIZE - `PREAMBLE_WIDTH - 12 - 1 : `DMA_NOC_FLIT_SIZE - `PREAMBLE_WIDTH -  12 - `MSG_TYPE_WIDTH] = msg_type_dma;
		//header_v_dma[`NOC_FLIT_SIZE - `PREAMBLE_WIDTH - `MSG_TYPE_WIDTH - `RESERVED_WIDTH : `NOC_FLIT_SIZE - `PREAMBLE_WIDTH - 12 - `MSG_TYPE_WIDTH] = reserved_resp_dma;
		
		if (local_x < origin_x_dma)
			go_right_dma = 5'b01000;
		else
			go_right_dma = 5'b10111;
		
		if (local_x > origin_x_dma)
			go_left_dma = 5'b00100;
		else
			go_left_dma = 5'b11011;

		if (local_y < origin_y_dma)
			header_v_dma[`NEXT_ROUTING_WIDTH - 1 : 0] = (5'b01110) & go_left_dma & go_right_dma;
		else
			header_v_dma[`NEXT_ROUTING_WIDTH - 1 : 0] = (5'b01101) & go_left_dma & go_right_dma;

		if (local_y == origin_y_dma && local_x == origin_x_dma)
			header_v_dma[`NEXT_ROUTING_WIDTH - 1 : 0] = 5'b10000;

		dma_header = header_v_dma;

    end    

    // Register Response Header
    always @(posedge ACLK, negedge ARESETn) begin
        if (ARESETn == 1'b0) begin
			header_reg <= 0;
			dma_header_reg <= 0;
		end
		else begin
			if (sample_header == 1'b1) 
				header_reg <= header;
			else if (sample_dma_header == 1'b1)
				dma_header_reg <= dma_header;
		end
    end

endmodule
