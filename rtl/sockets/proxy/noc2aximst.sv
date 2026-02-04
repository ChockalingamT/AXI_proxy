// Copyright (c) 2011-2026 Columbia University, System Level Design Group
// SPDC-License-Identifier: Apache-2.0

`timescale 1ns / 1ps

import esp_global_sv::*;
import noc2aximst_pkg::*;


`define PREAMBLE_WIDTH 2
`define MSG_TYPE_WIDTH 5
`define RESERVED_WIDTH 8
`define NEXT_ROUTING_WIDTH 5

module noc2aximst 
#(
    parameter integer tech        			= 0,
    parameter integer mst_index	  			= 0,
    parameter integer axitran     			= 0,
    parameter integer little_end  			= 0,
    parameter integer eth_dma     			= 0,
    parameter integer narrow_noc  			= 0,
    parameter integer cacheline   			= 4,
	parameter integer this_coh_flit_size 	= 34
) (
    input logic       						  ARESETn,
    input logic       						  ACLK,
    input logic  [		 GLOB_YX_WIDTH-1 : 0] local_y,
    input logic  [		 GLOB_YX_WIDTH-1 : 0] local_x,

    output logic [		       		   1 : 0] AR_ID,
    output logic [ GLOB_PHYS_ADDR_BITS-1 : 0] AR_ADDR,
    output logic [                     7 : 0] AR_LEN,
    output logic [                     2 : 0] AR_SIZE,
    output logic [		       		   1 : 0] AR_BURST,
    output logic 			      			  AR_LOCK,
    output logic [                     2 : 0] AR_PROT,
    output logic                              AR_VALID,
    input  logic                              AR_READY,

    input  logic [		       		   1 : 0] R_ID,
    input  logic [               AXIDW-1 : 0] R_DATA,
    input  logic [		       		   1 : 0] R_RESP,		// not used
    input  logic                              R_LAST,
    input  logic                              R_VALID,
    output logic                              R_READY,

    output logic [		       		   1 : 0] AW_ID,
    output logic [ GLOB_PHYS_ADDR_BITS-1 : 0] AW_ADDR,
    output logic [                     7 : 0] AW_LEN,
    output logic [                     2 : 0] AW_SIZE,
    output logic [		       		   1 : 0] AW_BURST,
    output logic 			      			  AW_LOCK,
    output logic [                     2 : 0] AW_PROT,
    output logic                              AW_VALID,
    input  logic                              AW_READY,

    output logic [               AXIDW-1 : 0] W_DATA,
    output logic [                  AW-1 : 0] W_STRB,
    output logic                              W_LAST,
    output logic                              W_VALID,
    input  logic                              W_READY,

    input  logic [		       		   1 : 0] B_ID,	
    input  logic [		      		   1 : 0] B_RESP,		// not used
    input  logic                              B_VALID,		// not used
    output logic                              B_READY,		

    output logic                              coherence_req_rdreq,
    input  logic [  this_coh_flit_size-1 : 0] coherence_req_data_out,
    input  logic                              coherence_req_empty,

    output logic                              coherence_rsp_snd_wrreq,
    output logic [  this_coh_flit_size-1 : 0] coherence_rsp_snd_data_in,
    input  logic                              coherence_rsp_snd_full,

    output logic                              dma_rcv_rdreq,
    input  logic [   DMA_NOC_FLIT_SIZE-1 : 0] dma_rcv_data_out,
    input  logic                              dma_rcv_empty,

    output logic                              dma_snd_wrreq,
    output logic [   DMA_NOC_FLIT_SIZE-1 : 0] dma_snd_data_in,
    input  logic                              dma_snd_full

);

    assign AR_ID = mst_index;
    assign AW_ID = mst_index;

    assign AW_LOCK = 1'b0;
    assign AR_LOCK = 1'b0;

    assign AR_BURST = XBURST_INCR;
    assign AW_BURST = XBURST_INCR;

	logic [MAX_NOC_FLIT_SIZE-this_coh_flit_size : 0] this_noc_flit_pad;
	assign this_noc_flit_pad = 0;
	logic [MAX_NOC_FLIT_SIZE-1 : 0] pad_coherence_req_data_out;
	assign pad_coherence_req_data_out = {this_noc_flit_pad, coherence_req_data_out};


	logic [MAX_NOC_FLIT_SIZE-DMA_NOC_FLIT_SIZE: 0] dma_noc_flit_pad;
	assign dma_noc_flit_pad = 0;
	logic [MAX_NOC_FLIT_SIZE-1 : 0] pad_dma_rcv_data_out;
	assign pad_dma_rcv_data_out = {dma_noc_flit_pad, dma_rcv_data_out};


    logic [this_coh_flit_size-1  : 0] header;
	logic [this_coh_flit_size-1  : 0] header_reg;
    (* mark_debug = "true" *) logic sample_header;


    logic [DMA_NOC_FLIT_SIZE-1 : 0] dma_header;
	logic [DMA_NOC_FLIT_SIZE-1 : 0] dma_header_reg;
    logic sample_dma_header;
    
    logic [`RESERVED_WIDTH-1 : 0] reserved;
    logic [`PREAMBLE_WIDTH-1 : 0] preamble;
    logic [`PREAMBLE_WIDTH-1 : 0] dma_preamble;

	//TODO: cleanup
    (* mark_debug = "true" *) logic [this_coh_flit_size-`PREAMBLE_WIDTH-1 : 0] coh_rd_data_flit;
	(* mark_debug = "true" *) logic [ DMA_NOC_FLIT_SIZE-`PREAMBLE_WIDTH-1 : 0] dma_rd_data_flit;
	(* mark_debug = "true" *) logic [AXIDW-1 : 0] wr_data_flit;
    //logic [`PREAMBLE_WIDTH+`AXIDW-1 : 0] wr_data_flit;
    integer i, j;

    (* mark_debug = "true" *) logic [              4 : 0] current_state;
    (* mark_debug = "true" *) logic [              4 : 0] next_state;

    localparam RECEIVE_HEADER  = 5'b00000;
    localparam RECEIVE_ADDRESS = 5'b00001;
    localparam RECEIVE_LENGTH  = 5'b00010;
    localparam READ_REQUEST    = 5'b00011;
    localparam SEND_HEADER     = 5'b00100;
    localparam SEND_DATA       = 5'b00101;
    localparam WRITE_REQUEST   = 5'b00110;
    localparam WRITE_DATA_EDCL = 5'b00111;
    localparam WRITE_DATA      = 5'b01000;
    //parameter WRITE_LAST_DATA = 5'b01001;

    localparam DMA_RECEIVE_ADDRESS     = 5'b01010;
    localparam DMA_RECEIVE_READ_LENGTH = 5'b01011;
    localparam DMA_READ_REQUEST    = 5'b01100;
    localparam DMA_SEND_HEADER     = 5'b01101;
    localparam DMA_SEND_DATA       = 5'b01110;

    localparam DMA_RECEIVE_WRITE_LENGTH = 5'b01111;
    localparam DMA_WRITE_REQUEST        = 5'b10000;
    //parameter DMA_WRITE_WAIT           = 5'b10001;
    localparam DMA_WRITE_DATA           = 5'b10010;
    //parameter DMA_WRITE_LAST_DATA      = 5'b10011;
	localparam DMA_WRITE_DATA_COH       = 5'b10100;
    localparam DMA_WRITE_DATA_ETH       = 5'b10101;

    (* mark_debug = "true" *) reg_type cs, ns;

    always_comb begin
        ns = cs;
		next_state = current_state;
        preamble 	 = pad_coherence_req_data_out[this_coh_flit_size-1:this_coh_flit_size-`PREAMBLE_WIDTH];
		dma_preamble = pad_dma_rcv_data_out      [DMA_NOC_FLIT_SIZE-1:DMA_NOC_FLIT_SIZE-`PREAMBLE_WIDTH];        
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
		W_VALID = 1'b0;
		W_LAST  = 1'b0;
		W_DATA  = 0;

        case (current_state)

            RECEIVE_HEADER: begin
                if (coherence_req_empty == 1'b0) begin
                    coherence_req_rdreq = 1'b1;
                    ns.msg = pad_coherence_req_data_out[this_coh_flit_size - `PREAMBLE_WIDTH - 4*GLOB_YX_WIDTH - 1:this_coh_flit_size - `PREAMBLE_WIDTH - 4*GLOB_YX_WIDTH - `MSG_TYPE_WIDTH];
                    reserved = pad_coherence_req_data_out[this_coh_flit_size - `PREAMBLE_WIDTH - 4*GLOB_YX_WIDTH - `MSG_TYPE_WIDTH - 1:this_coh_flit_size - `PREAMBLE_WIDTH - 4*GLOB_YX_WIDTH - `MSG_TYPE_WIDTH - `RESERVED_WIDTH];
                    ns.ax_prot = reserved[2:0];
					if (axitran == 0)
						ns.hsize_msb = 0;
					else
						ns.hsize_msb = reserved[3];
                    sample_header = 1'b1;
                    next_state = RECEIVE_ADDRESS;
                end
				else if (dma_rcv_empty == 1'b0) begin
		    		dma_rcv_rdreq = 1'b1;
		    		ns.msg = pad_dma_rcv_data_out[DMA_NOC_FLIT_SIZE - `PREAMBLE_WIDTH - 4*GLOB_YX_WIDTH - 1:DMA_NOC_FLIT_SIZE - `PREAMBLE_WIDTH - 4*GLOB_YX_WIDTH - `MSG_TYPE_WIDTH];
                    reserved = pad_dma_rcv_data_out[DMA_NOC_FLIT_SIZE - `PREAMBLE_WIDTH - 4*GLOB_YX_WIDTH - `MSG_TYPE_WIDTH - 1:DMA_NOC_FLIT_SIZE - `PREAMBLE_WIDTH - 4*GLOB_YX_WIDTH - `MSG_TYPE_WIDTH - `RESERVED_WIDTH];
                    ns.ax_prot = reserved[2:0];
                    sample_dma_header = 1'b1;
                    next_state = DMA_RECEIVE_ADDRESS;
				end	
				ns.burst_flag = 0;
				ns.coh_dma_flag = 0;
				ns.sample_flag = 2'b00;
				coh_rd_data_flit = 0;    
				dma_rd_data_flit = 0; 
				ns.dma_noc_data = 0;
            end

            RECEIVE_ADDRESS: begin
                if (coherence_req_empty == 1'b0) begin
                    coherence_req_rdreq = 1'b1;

                    if (cs.msg == REQ_GETS_W || cs.msg == REQ_GETS_HW || cs.msg == REQ_GETS_B || cs.msg == AHB_RD) begin
                        ns.ar_prot = cs.ax_prot;
                        ns.ar_addr = coherence_req_data_out[GLOB_PHYS_ADDR_BITS-1:0];
                        if (axitran == 0) begin
                            ns.ar_len = cacheline - 1;
                            next_state = READ_REQUEST;
                        end else 							
                            next_state = RECEIVE_LENGTH;

						// Setting the AR_SIZE one cycle earlier since we don't need to wait for the bus
                        if 		(cs.msg == REQ_GETS_B) 						ns.ar_size = XSIZE_BYTE;
                        else if (cs.msg == REQ_GETS_HW) 					ns.ar_size = XSIZE_HWORD;
                        //else if (ARCH_BITS == 64 && cs.msg == REQ_GETS_W) 	ns.ar_size = XSIZE_DWORD;
						else if (ARCH_BITS == 64 && cs.hsize_msb == 1) 		ns.ar_size = XSIZE_DWORD;
                        else 												ns.ar_size = XSIZE_WORD;
                    end 

                    else if (cs.msg == REQ_GETM_W || cs.msg == REQ_GETM_HW || cs.msg == REQ_GETM_B || cs.msg == AHB_WR) begin
                        ns.aw_prot = cs.ax_prot;
                        ns.aw_addr = coherence_req_data_out[GLOB_PHYS_ADDR_BITS-1:0];
						ns.aw_len  = 0;
                        next_state = WRITE_REQUEST;
                        if 		(cs.msg == REQ_GETM_B) 						ns.aw_size = XSIZE_BYTE;
                        else if (cs.msg == REQ_GETM_HW) 					ns.aw_size = XSIZE_HWORD;
                      
						//else if (ARCH_BITS == 64 && cs.msg == REQ_GETM_W) 	ns.aw_size = XSIZE_DWORD;
						else if (ARCH_BITS == 64 && cs.hsize_msb == 1)		ns.aw_size = XSIZE_DWORD;
						else												ns.aw_size = XSIZE_WORD;
						
						if (ARCH_BITS  == 32) begin
							if      (ns.aw_size == XSIZE_BYTE)  ns.w_strb = 4'b1000 >> ns.aw_addr[$clog2(AW)-1:0];
							else if (ns.aw_size == XSIZE_HWORD) ns.w_strb = 4'b1100 >> ns.aw_addr[$clog2(AW)-1:0];
							else if (ns.aw_size == XSIZE_WORD)  ns.w_strb = 4'b1111 >> ns.aw_addr[$clog2(AW)-1:0];
							else if (ns.aw_size == XSIZE_DWORD) ns.w_strb = 8'b11111111 >> ns.aw_addr[$clog2(AW)-1:0];
						end else begin
						    if (cs.msg == AHB_WR) begin
							    if (ns.aw_addr[2] == 0)
									ns.w_strb = 8'b11110000;
								else
									ns.w_strb = 8'b00001111;
						    end 
							else begin
							    if      (ns.aw_size == XSIZE_BYTE)  ns.w_strb = 8'b10000000 >> ns.aw_addr[$clog2(AW)-1:0];		
							    else if (ns.aw_size == XSIZE_HWORD) ns.w_strb = 8'b11000000 >> ns.aw_addr[$clog2(AW)-1:0];
							    else if (ns.aw_size == XSIZE_WORD)  ns.w_strb = 8'b11110000 >> ns.aw_addr[$clog2(AW)-1:0];
							    else if (ns.aw_size == XSIZE_DWORD) ns.w_strb = 8'b11111111 >> ns.aw_addr[$clog2(AW)-1:0];
                            end
						end	
                    end
                    else
                        next_state = RECEIVE_HEADER;
                end
            end 

            RECEIVE_LENGTH: begin
                if (coherence_req_empty == 1'b0) begin
                    coherence_req_rdreq = 1'b1;
		    
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
						if (little_end  == 0) begin
							for (i = 0; i < (this_coh_flit_size - `PREAMBLE_WIDTH) / ARCH_BITS; i = i + 1)											
								coh_rd_data_flit[ARCH_BITS * i +: ARCH_BITS] = R_DATA;
						end
						else begin
							for (i = 0; i < (this_coh_flit_size - `PREAMBLE_WIDTH) / ARCH_BITS; i = i + 1) begin			
								for (j = 0; j < (ARCH_BITS / 8); j = j + 1) begin
									coh_rd_data_flit[ARCH_BITS * i + 8*j +: 8] = R_DATA[ARCH_BITS * (i+1) -8*(j+1) +: 8];
								end
							end
						end

                        if (R_LAST == 1'b1) begin
                            if (cs.count == 0) begin 
                                coherence_rsp_snd_data_in = {PREAMBLE_TAIL, coh_rd_data_flit};
                                next_state = RECEIVE_HEADER;
                            end else begin // If another burst is needed
                                coherence_rsp_snd_data_in = {PREAMBLE_BODY, coh_rd_data_flit};

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
                            coherence_rsp_snd_data_in = {PREAMBLE_BODY, coh_rd_data_flit};
                    end
                end
            end 

            WRITE_REQUEST: begin			// In this state AW_VALID is set and waiting for AW_READY

				if (AW_READY == 1'b1) begin		// If AW_READY = 1, the Address transaction completes and we can move to Data transactions
                    if (cs.msg == AHB_WR && ARCH_BITS == 64) 
                        next_state = WRITE_DATA_EDCL;
                    else 
                        next_state = WRITE_DATA;
		    		 ns.sample_flag = 2'b00;
                     if (coherence_req_empty == 1'b0 && cs.msg != AHB_WR) begin		// If the NoC queue is available - read the first data to be written
                        coherence_req_rdreq = 1'b1;
                        ns.coh_flit = coherence_req_data_out;	//TODO: Replace COH_NOC_WIDTH with this_coh
                        if 		(preamble == PREAMBLE_BODY) ns.sample_flag = 2'b01;	// Instead of WRITE_WAIT STATE
                        else if (preamble == PREAMBLE_TAIL) ns.sample_flag = 2'b10;
                    end 
                end
            end

            WRITE_DATA: begin

				W_VALID = 1'b0;
				W_LAST  = 1'b0;

				if (cs.sample_flag == 2'b01 || cs.sample_flag == 2'b10) begin	// If one data has already been read
					W_VALID = 1'b1;
					W_LAST  = 1'b1;

					// Fix endianess
					if (little_end  == 0) begin
						wr_data_flit = cs.coh_flit[ARCH_BITS-1 : 0];
						//if      (cs.aw_size == XSIZE_BYTE)  W_STRB[`AW-1] = 1'b1;
						//else if (cs.aw_size == XSIZE_HWORD) W_STRB[`AW-1:`AW-2] = 2'b11;
						//else if (cs.aw_size == XSIZE_WORD)  W_STRB[`AW-1:`AW-4] = 4'b1111;
						//else if (cs.aw_size == XSIZE_DWORD) W_STRB = 8'b11111111;
					end else begin
						for (i = 0; i < (ARCH_BITS / 8); i = i + 1) begin					
							wr_data_flit[8*i +: 8] = cs.coh_flit[ARCH_BITS-8*(i+1) +: 8];
						end
						//if      (cs.aw_size == XSIZE_BYTE)  W_STRB[0] = 1'b1;
						//else if (cs.aw_size == XSIZE_HWORD) W_STRB[1:0] = 2'b11;
						//else if (cs.aw_size == XSIZE_WORD)  W_STRB[3:0] = 4'b1111;
						//else if (cs.aw_size == XSIZE_DWORD) W_STRB = 8'b11111111;
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
						wr_data_flit = ns.coh_flit[ARCH_BITS-1 : 0];
						//if      (cs.aw_size == XSIZE_BYTE)  W_STRB[`AW-1] = 1'b1;
						//else if (cs.aw_size == XSIZE_HWORD) W_STRB[`AW-1:`AW-2] = 2'b11;
						//else if (cs.aw_size == XSIZE_WORD)  W_STRB[`AW-1:`AW-4] = 4'b1111;
						//else if (cs.aw_size == XSIZE_DWORD) W_STRB = 8'b11111111;
					end else begin
						for (i = 0; i < (ARCH_BITS / 8); i = i + 1) begin
							wr_data_flit[8*i +: 8] = ns.coh_flit[ARCH_BITS-8*(i+1) +: 8];
						end
						//if      (cs.aw_size == XSIZE_BYTE)  W_STRB[0] = 1'b1;
						//else if (cs.aw_size == XSIZE_HWORD) W_STRB[1:0] = 2'b11;
						//else if (cs.aw_size == XSIZE_WORD)  W_STRB[3:0] = 4'b1111;
						//else if (cs.aw_size == XSIZE_DWORD) W_STRB = 8'b11111111;
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
						if 		(preamble == PREAMBLE_BODY) ns.sample_flag = 2'b01;
	                	else if (preamble == PREAMBLE_TAIL) ns.sample_flag = 2'b10;
					end
				end
            end
           
		WRITE_DATA_EDCL: begin
				W_VALID = 1'b0;
				W_LAST  = 1'b0;
                if (coherence_req_empty == 1'b0) begin                      // Read one more
					if (W_READY == 1'b1) begin	// If the data can be read in the same cycle
                		coherence_req_rdreq = 1'b1;
                    	if (cs.aw_addr[2] == 1'b0) begin
							ns.coh_flit = {coherence_req_data_out[31:0], 32'b0};
							ns.w_strb = 8'b00001111;
						end
						else begin
							ns.coh_flit = {32'b0, coherence_req_data_out[31:0]};
							ns.w_strb = 8'b11110000;
						end
   						W_VALID = 1'b1;
				    	W_LAST  = 1'b1;
						W_DATA = ns.coh_flit;
                		ns.aw_addr = cs.aw_addr + 4'b0100;
					    if (preamble == PREAMBLE_TAIL) 
                		    next_state = RECEIVE_HEADER;
						else 
							next_state = WRITE_REQUEST;	
					end
				end
            end
 
            DMA_RECEIVE_ADDRESS: begin
                if (dma_rcv_empty == 1'b0) begin
					dma_rcv_rdreq = 1'b1;
                    ns.ar_prot = cs.ax_prot;
					if (eth_dma == 0) begin
						if (ARCH_BITS == 64) begin
							ns.ar_size = XSIZE_DWORD;
							ns.aw_size = XSIZE_DWORD;
						end
						else begin 
							ns.ar_size = XSIZE_WORD;
							ns.aw_size = XSIZE_WORD;
						end
		    		end 
					else begin
						ns.ar_size = XSIZE_WORD;
						ns.aw_size = XSIZE_WORD;
					end
                    if (cs.msg == DMA_TO_DEV || cs.msg == REQ_DMA_READ) begin
						next_state = DMA_RECEIVE_READ_LENGTH;
                    	ns.ar_addr = dma_rcv_data_out[GLOB_PHYS_ADDR_BITS-1:0];
		    		end 
					else begin
						ns.aw_len  = 0;
		    			if (cs.msg == DMA_FROM_DEV) begin
							ns.coh_dma_flag = 1'b0;
                    		ns.aw_addr = dma_rcv_data_out[GLOB_PHYS_ADDR_BITS-1:0];
							next_state = DMA_RECEIVE_WRITE_LENGTH;
						end
		    			else begin
							ns.coh_dma_flag = 1'b1;
                    		ns.aw_addr = dma_rcv_data_out[GLOB_PHYS_ADDR_BITS-1:0];
							next_state = DMA_WRITE_REQUEST;
						end
						ns.w_strb = 0;
                        if (cs.msg == REQ_DMA_WRITE) begin
                            ns.w_strb = 8'b11111111;
                        end else begin
						    if (little_end  == 0) begin
							    if 		(ns.aw_size == XSIZE_WORD)  ns.w_strb = {4'b1111, {AW-4{1'b0}}} >> ns.aw_addr[$clog2(AW)-1:0];
							    else if (ns.aw_size == XSIZE_DWORD) ns.w_strb = 8'b11111111 >> ns.aw_addr[$clog2(AW)-1:0];
						    end else begin
							    if 		(ns.aw_size == XSIZE_WORD)  ns.w_strb = {4'b1111, {AW-4{1'b0}}} >> ns.aw_addr[$clog2(AW)-1:0];
							    else if (ns.aw_size == XSIZE_DWORD) ns.w_strb = 8'b11111111 >> ns.aw_addr[$clog2(AW)-1:0];
						    end
                        end
		    		end
				end
	   		end

	   		DMA_RECEIVE_READ_LENGTH: begin
       			if (dma_rcv_empty == 1'b0) begin
                    dma_rcv_rdreq = 1'b1;
		    		ns.count = dma_rcv_data_out[31:0] - 1;
					if (ns.count > 255) begin
						ns.ar_len = 255;
						ns.count  = ns.count - 255;
					end 
					else begin
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
				           	dma_snd_data_in = dma_header_reg;
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
	                dma_snd_data_in = dma_header_reg;
	                dma_snd_wrreq   = 1'b1; 
			   	end
		  	end

          	DMA_SEND_DATA: begin

				R_READY = 1'b0;				
				if (cs.sample_flag == 2'b01) begin
					if (dma_snd_full == 1'b0) begin
						ns.sample_flag = 2'b00;
						dma_snd_wrreq = 1'b1;
						dma_snd_data_in = {PREAMBLE_BODY, cs.dma_noc_data};
						
					end
				end
				else if (cs.sample_flag == 2'b10) begin
					if (dma_snd_full == 1'b0) begin
						ns.sample_flag = 2'b00;
						dma_snd_wrreq = 1'b1;
						
                        if (cs.count == 0) begin 
                        	dma_snd_data_in = {PREAMBLE_TAIL, cs.dma_noc_data};			
							next_state = RECEIVE_HEADER;
						end else begin
							dma_snd_data_in = {PREAMBLE_BODY, cs.dma_noc_data};			
									
                           	if (cs.count > 255) begin
                            	ns.ar_len = 255;
                           		ns.count  = cs.count - 255; 
                          	end else begin 
                             	ns.ar_len = cs.count; 
                               	ns.count = 0; 
                          	end 
                                
							if 	(cs.ar_size == XSIZE_WORD)  	ns.ar_addr = cs.ar_addr + 1024;	// TODO: Verify this case with eth_dma
                    		else if (cs.ar_size == XSIZE_DWORD) ns.ar_addr = cs.ar_addr + 2048; 

                          	ns.burst_flag = 1;		// Give the new address for the new burst
                           	next_state = DMA_READ_REQUEST;		
                      	end						
					end
				end
                else if (cs.sample_flag == 2'b00) begin
                    R_READY = 1'b1;
                    if (R_VALID == 1'b1) begin
						ns.word_cnt = cs.word_cnt + 1;
						// Fix endianess
						if (little_end  == 0)
							ns.dma_noc_data[ARCH_BITS * cs.word_cnt +: ARCH_BITS] = R_DATA;
						else begin
							for (j = 0; j < (ARCH_BITS / 8); j = j + 1) begin
								ns.dma_noc_data[ARCH_BITS * cs.word_cnt + 8*j +: 8] = R_DATA[ARCH_BITS-8*(j+1) +: 8];
							end
						end					
						dma_snd_data_in[DMA_NOC_FLIT_SIZE-`PREAMBLE_WIDTH-1 : 0] = ns.dma_noc_data;

						if (R_LAST == 1'b0) begin
							if ((ns.word_cnt == DMA_NOC_WIDTH / ARCH_BITS) || (eth_dma == 1)) begin
								ns.word_cnt = 0;
								if (dma_snd_full == 1'b1)
									ns.sample_flag = 2'b01;
								else begin
									ns.sample_flag = 2'b00;
									dma_snd_wrreq = 1'b1;
									dma_snd_data_in[DMA_NOC_FLIT_SIZE-1:DMA_NOC_FLIT_SIZE-`PREAMBLE_WIDTH] = PREAMBLE_BODY;
								end
							end
						end
						else begin
							ns.word_cnt = 0;
							if (dma_snd_full == 1'b1)
								ns.sample_flag = 2'b10;
							else begin					
								ns.sample_flag = 2'b00;	
								dma_snd_wrreq = 1'b1;
							
                            	if (cs.count == 0) begin 
                                	dma_snd_data_in[DMA_NOC_FLIT_SIZE-1:DMA_NOC_FLIT_SIZE-`PREAMBLE_WIDTH] = PREAMBLE_TAIL;				
									next_state = RECEIVE_HEADER;
								end else begin
									dma_snd_data_in[DMA_NOC_FLIT_SIZE-1:DMA_NOC_FLIT_SIZE-`PREAMBLE_WIDTH] = PREAMBLE_BODY;				
									
                                	if (cs.count > 255) begin
                                    	ns.ar_len = 255;
                                      	ns.count  = cs.count - 255; 
                                	end else begin 
                                      	ns.ar_len = cs.count; 
                                      	ns.count = 0; 
                                	end 
                                
									if 	(cs.ar_size == XSIZE_WORD)  	ns.ar_addr = cs.ar_addr + 1024; // TODO: Verify this case with eth_dma
                                	else if (cs.ar_size == XSIZE_DWORD) ns.ar_addr = cs.ar_addr + 2048; 

                                	ns.burst_flag = 1;		// Give the new address for the new burst
                                	next_state = DMA_READ_REQUEST;		
                               	end
                         	end					
						end
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
					if (cs.msg == REQ_DMA_WRITE && ARCH_BITS == 64 && eth_dma == 1) // FIXME: eth_dma == 1 is not necessary
                        next_state = DMA_WRITE_DATA_ETH;
                    else begin
                        if (cs.coh_dma_flag)
						    next_state = DMA_WRITE_DATA_COH;
					    else                    
						    next_state = DMA_WRITE_DATA;
                    end
		    		ns.sample_flag = 2'b00;
                    if (dma_rcv_empty == 1'b0) begin		// If the NoC queue is available - read the first data to be written (prefetch)
                        dma_rcv_rdreq = 1'b1;
                        if (cs.msg == REQ_DMA_WRITE && ARCH_BITS == 64 && eth_dma == 1) begin
                            if (cs.word_cnt == 1'b1)
                                ns.dma_flit = {cs.dma_flit[63:32], dma_rcv_data_out[31:0]};
                            else
                                ns.dma_flit = {dma_rcv_data_out[31:0], 32'b0};
                        end else
                            ns.dma_flit = dma_rcv_data_out;

						// FIXME
                        //ns.sample_flag = 2'b01;
                        if (cs.msg == REQ_DMA_WRITE && ARCH_BITS == 64 && eth_dma == 1) begin
                            if 		(dma_preamble == PREAMBLE_BODY) ns.sample_flag = 2'b01;
                            else if (dma_preamble == PREAMBLE_TAIL) ns.sample_flag = 2'b10;	// We have a single transaction from ETH TODO: REMOVED ETH
                        end else
                            if 		(dma_preamble == PREAMBLE_BODY) ns.sample_flag = 2'b01;	// We have a burst from accelerator

                    end
                end
            end     
	
			// TODO: ADD WIDER NOC FOR WRITE + ETH_DMA IN WRITE		
			// Different operations from accelerator and ETH
		

		// WORKING
/*           DMA_WRITE_DATA: begin

				W_VALID = 1'b0;
				W_LAST  = 1'b0;

				if (cs.sample_flag == 2'b01 || cs.sample_flag == 2'b10) begin
					W_VALID = 1'b1;
					if (cs.aw_len == 0 || cs.sample_flag == 2'b10) W_LAST = 1'b1;	// If end of burst or 1-beat transaction (aw_len is invalid)
			
					// Fix endianess
					if (little_end  == 0) begin
						wr_data_flit = cs.dma_flit[ARCH_BITS-1 : 0];
					end else begin
						for (i = 0; i < (ARCH_BITS / 8); i = i + 1) begin				//TODO: Verify with Ariane
							wr_data_flit[8*i +: 8] = cs.dma_flit[ARCH_BITS-8*(i+1) +: 8];
						end
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
                    			if 		(cs.aw_size == XSIZE_WORD)  ns.aw_addr = cs.aw_addr + 4'b0100; // TODO: Verify this case with eth_dma
                    			else if (cs.aw_size == XSIZE_DWORD) ns.aw_addr = cs.aw_addr + 4'b1000;
								//FIXME: case of using this
                    			//if (dma_rcv_empty == 1'b0) begin		// If the NoC queue is available - read the first data to be written
                        		//	dma_rcv_rdreq = 1'b1;
                        		//	ns.dma_flit = dma_rcv_data_out;
                        		//	ns.sample_flag = 2'b01;
                    			//end

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
					W_VALID = 1'b1;
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
						wr_data_flit = ns.dma_flit[ARCH_BITS-1 : 0];


					end else begin
						for (i = 0; i < (ARCH_BITS / 8); i = i + 1) begin
							wr_data_flit[8*i +: 8] = ns.dma_flit[ARCH_BITS-8*(i+1) +: 8];
						end

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
                    			if 	(cs.aw_size == XSIZE_WORD)  	ns.aw_addr = cs.aw_addr + 4'b0100; // TODO: Verify this case with eth_dma
                    			else if (cs.aw_size == XSIZE_DWORD) ns.aw_addr = cs.aw_addr + 4'b1000;
							end
						end					
						else		
							ns.aw_len = cs.aw_len - 1;

					end
				end

            end
*/
			//Wide NOC

            DMA_WRITE_DATA: begin

				W_VALID = 1'b0;
				W_LAST  = 1'b0;
				if (cs.sample_flag == 2'b01 || cs.sample_flag == 2'b10) begin		// If something already prefetched
					W_VALID = 1'b1;
					if (cs.aw_len == 0 || cs.sample_flag == 2'b10) W_LAST = 1'b1;	// If end of burst or 1-beat transaction (aw_len is invalid)
					// Fix endianess
					if (little_end  == 0) begin										// Use previously fetched flit with the word pointer
						wr_data_flit = cs.dma_flit[ARCH_BITS * cs.word_cnt +: ARCH_BITS];
					end 
					else begin
						for (j = 0; j < (ARCH_BITS / 8); j = j + 1) begin
							wr_data_flit[8*j +: 8] = cs.dma_flit[ARCH_BITS * (cs.word_cnt + 1) -8*(j+1) +: 8];
						end
					end  
             
               		W_DATA = wr_data_flit;
					if (W_READY == 1'b1) begin
						ns.sample_flag = 2'b00;
						ns.word_cnt = cs.word_cnt + 1;	// If we write - update the word pointer
						if (cs.aw_len == 0) begin
							if (cs.count == 0 || cs.sample_flag == 2'b10) // If end of burst or 1-beat transaction (aw_len/aw_count are invalid)
								next_state = RECEIVE_HEADER;
							else begin
								next_state = DMA_WRITE_REQUEST;
								if (cs.count > 255) begin
                                	ns.aw_len = 255;
                                  	ns.count  = cs.count - 255;
                               	end 
								else begin 
                                 	ns.aw_len = cs.count; 
                                   	ns.count = 0; 
                              	end 
                    			if (cs.aw_size == XSIZE_WORD)  
									ns.aw_addr = cs.aw_addr + 4'b0100; // TODO: Verify this case with eth_dma
                    			else if (cs.aw_size == XSIZE_DWORD) 
									ns.aw_addr = cs.aw_addr + 4'b1000;
								//FIXME: case of using this
                    			//if (dma_rcv_empty == 1'b0) begin		// If the NoC queue is available - read the first data to be written
                        		//	dma_rcv_rdreq = 1'b1;
                        		//	ns.dma_flit = dma_rcv_data_out;
                        		//	ns.sample_flag = 2'b01;
                    			//end

							end					
						end 
						else begin // If burst not finished
							if ((ns.word_cnt == DMA_NOC_WIDTH / ARCH_BITS) || (eth_dma == 1)) begin	// If end of flit
								ns.word_cnt = 0;			// Update the word pointer and request new flit from NoC

		                		if (dma_rcv_empty == 1'b0) begin		// If the NoC queue is available - read the first data to be written
		                    		dma_rcv_rdreq = 1'b1;
		                    		ns.dma_flit = dma_rcv_data_out;
		                    		ns.sample_flag = 2'b01;				// Prefetch and stay in the same state
		                		end	
							end		
							else
								ns.sample_flag = 2'b11;
							ns.aw_len = cs.aw_len - 1;
                		end
					end

				end 
				else if (cs.sample_flag == 2'b00 && dma_rcv_empty == 1'b0) begin	// If no data has been prefetched and there is something available (FIRST WRITE TO BUS)
					dma_rcv_rdreq = 1'b1;
					ns.dma_flit = dma_rcv_data_out;

					// Fix endianess
					if (little_end  == 0) begin
						wr_data_flit = ns.dma_flit[ARCH_BITS * cs.word_cnt +: ARCH_BITS];
					end 
					else begin
						for (j = 0; j < (ARCH_BITS / 8); j = j + 1) begin	//TODO: Verify Ariane
							wr_data_flit[8*j +: 8] = ns.dma_flit[ARCH_BITS * (cs.word_cnt + 1) -8*(j+1) +: 8];
						end
					end

               		W_DATA = wr_data_flit;
					W_VALID = 1'b1;
					ns.sample_flag = 2'b01;

					if (cs.aw_len == 0) begin					// End of burst
						W_LAST = 1'b1;
						ns.sample_flag = 2'b10;
					end			
					//else if (dma_preamble == PREAMBLE_TAIL) begin// 1-transaction (ETH)
					//	ns.sample_flag = 2'b10;
					//	if (ns.word_cnt == DMA_NOC_WIDTH / ARCH_BITS) 
					//		W_LAST = 1'b1;
					//end

					if (W_READY == 1'b1) begin
						ns.sample_flag = 2'b00;
						ns.word_cnt = cs.word_cnt + 1;

						//if (dma_preamble == PREAMBLE_TAIL) begin
						//	ns.word_cnt = 0;
						//	next_state = RECEIVE_HEADER;
						//end 
						if (cs.aw_len == 0) begin
							ns.word_cnt = 0;
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
                    			if 	(cs.aw_size == XSIZE_WORD)  	ns.aw_addr = cs.aw_addr + 4'b0100; // TODO: Verify this case with eth_dma
                    			else if (cs.aw_size == XSIZE_DWORD) ns.aw_addr = cs.aw_addr + 4'b1000;
							end
						end 	
						else begin
							if ((ns.word_cnt == DMA_NOC_WIDTH / ARCH_BITS) || (eth_dma == 1)) // If not last beat but flit processing is complete (reset word pointer) 
								ns.word_cnt = 0;
							else
								ns.sample_flag = 2'b11;
							ns.aw_len = cs.aw_len - 1;
						end					
					end
				end

				else if (cs.sample_flag == 2'b11) begin	// BUSY WRITE

					if (little_end  == 0) begin
						wr_data_flit = cs.dma_flit[ARCH_BITS * cs.word_cnt +: ARCH_BITS];

					end 
					else begin
						for (j = 0; j < (ARCH_BITS / 8); j = j + 1) begin	//TODO: Verify Ariane
							wr_data_flit[8*j +: 8] = cs.dma_flit[ARCH_BITS * (cs.word_cnt + 1) -8*(j+1) +: 8];
						end
					end
			
               		W_DATA = wr_data_flit;
					W_VALID = 1'b1;
					ns.sample_flag = 2'b01;

					if (cs.aw_len == 0)	begin				// End of burst
						ns.sample_flag = 2'b10;
						W_LAST = 1'b1;
					end			

					if (W_READY == 1'b1) begin
						ns.sample_flag = 2'b00;
						ns.word_cnt = cs.word_cnt + 1;

						if (cs.aw_len == 0) begin
							ns.word_cnt = 0;
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
                    			if 	(cs.aw_size == XSIZE_WORD)  	ns.aw_addr = cs.aw_addr + 4'b0100; // TODO: Verify this case with eth_dma
                    			else if (cs.aw_size == XSIZE_DWORD) ns.aw_addr = cs.aw_addr + 4'b1000;
							end
						end 	
						else begin
							if ((ns.word_cnt == DMA_NOC_WIDTH / ARCH_BITS) || (eth_dma == 1)) // If not last beat but flit processing is complete (reset word pointer) 
								ns.word_cnt = 0;
							else
								ns.sample_flag = 2'b11;
							ns.aw_len = cs.aw_len - 1;
						end					
					end
				end
            end


			// WORKING
           DMA_WRITE_DATA_COH: begin

				W_VALID = 1'b0;
				W_LAST  = 1'b0;
				if (cs.sample_flag == 2'b01 || cs.sample_flag == 2'b10) begin
					W_VALID = 1'b1;
					W_LAST = 1'b1;
					// Fix endianess
					if (little_end  == 0) begin
						wr_data_flit = cs.dma_flit[ARCH_BITS-1 : 0];
					end 
					else begin
						for (i = 0; i < (ARCH_BITS / 8); i = i + 1) begin
							wr_data_flit[8*i +: 8] = cs.dma_flit[ARCH_BITS-8*(i+1) +: 8];
						end
					end
               
               		W_DATA = wr_data_flit;

					if (W_READY == 1'b1) begin
						ns.sample_flag = 2'b00;
						if (cs.sample_flag == 2'b10) // If end of burst or 1-beat transaction (aw_len/aw_count are invalid)
							next_state = RECEIVE_HEADER;
						else begin
							next_state = DMA_WRITE_REQUEST;
                    		if 		(cs.aw_size == XSIZE_WORD)  ns.aw_addr = cs.aw_addr + 4'b0100; // TODO: Verify this case with eth_dma
                    		else if (cs.aw_size == XSIZE_DWORD) ns.aw_addr = cs.aw_addr + 4'b1000;

                    		//if (dma_rcv_empty == 1'b0) begin		// If the NoC queue is available - read the first data to be written
                        	//	dma_rcv_rdreq = 1'b1;
                        	//	ns.dma_flit = dma_rcv_data_out;
                        	//	ns.sample_flag = 2'b01;
                    		//end
						end					
					end

				end else if (cs.sample_flag == 2'b00 && dma_rcv_empty == 1'b0) begin	// If no data has been prefetched and there is something available
					W_VALID = 1'b1;
					W_LAST = 1'b1;
	
					if (dma_preamble == PREAMBLE_TAIL) begin						
						ns.sample_flag = 2'b10;
					end else
						ns.sample_flag = 2'b01;
					
					dma_rcv_rdreq = 1'b1;
					ns.dma_flit = dma_rcv_data_out;

					// Fix endianess
					if (little_end  == 0) begin
						wr_data_flit = ns.dma_flit[ARCH_BITS-1 : 0];
					end 
					else begin
						for (i = 0; i < (ARCH_BITS / 8); i = i + 1) begin
							wr_data_flit[8*i +: 8] = ns.dma_flit[ARCH_BITS-8*(i+1) +: 8];
						end
					end

               		W_DATA = wr_data_flit;
					if (W_READY == 1'b1) begin
						ns.sample_flag = 2'b00;

						if (dma_preamble == PREAMBLE_TAIL)
							next_state = RECEIVE_HEADER;

						else begin
							next_state = DMA_WRITE_REQUEST;
                    		if 	(cs.aw_size == XSIZE_WORD)  	ns.aw_addr = cs.aw_addr + 4'b0100; // TODO: Verify this case with eth_dma
                    		else if (cs.aw_size == XSIZE_DWORD) ns.aw_addr = cs.aw_addr + 4'b1000;

						end					


					end
				end
            end


           DMA_WRITE_DATA_ETH: begin

				W_VALID = 1'b0;
				W_LAST  = 1'b0;

				if (cs.sample_flag == 2'b01 || cs.sample_flag == 2'b10) begin	// If one data has already been read in WRITE_REQUEST state
                    if (cs.word_cnt != 1'b1 && dma_rcv_empty == 1'b0) begin                      // Read one more
                        dma_rcv_rdreq = 1'b1;
						if (ARCH_BITS == 64)
							ns.dma_flit = {cs.dma_flit[63:32], dma_rcv_data_out[31:0]};
						else
							ns.dma_flit = dma_rcv_data_out;
						ns.word_cnt = cs.word_cnt + 1'b1;                       // Both words are already in place
   					    W_VALID = 1'b1;
				        W_LAST  = 1'b1;
                        W_DATA = ns.dma_flit;
					    if (W_READY == 1'b1) begin	// If the data can be read in the same cycle
                            ns.word_cnt = 1'b0;
						    ns.sample_flag = 2'b00; // The write process is complete
						    if (cs.sample_flag == 2'b01 && dma_preamble != PREAMBLE_TAIL) begin	// Unless this was only a body flit
                	            ns.aw_addr = cs.aw_addr + 4'b1000;
                			    next_state = DMA_WRITE_REQUEST;
						    end else 
							    next_state = RECEIVE_HEADER;
                	    end
                    end else if (cs.word_cnt == 1'b1) begin
   					    W_VALID = 1'b1;
					    W_LAST  = 1'b1;      
                        W_DATA = cs.dma_flit;              
					    if (W_READY == 1'b1) begin	// If the data can be read in the same cycle
                            ns.word_cnt = 1'b0;
						    ns.sample_flag = 2'b00; // The write process is complete
						    if (cs.sample_flag == 2'b01) begin	// Unless this was only a body flit
                	            ns.aw_addr = cs.aw_addr + 4'b1000;
                			    next_state = DMA_WRITE_REQUEST;
						    end else 
							    next_state = RECEIVE_HEADER;
                	    end
                    end
				end else if (cs.sample_flag == 2'b00 && dma_rcv_empty == 1'b0) begin	// If no data have been received yet and there are available data

					dma_rcv_rdreq = 1'b1;			// Read this data

                    //biruk's patch
                    ns.dma_flit = {dma_rcv_data_out[31:0], 32'b0};
					if 		(dma_preamble == PREAMBLE_BODY) ns.sample_flag = 2'b01;
	                else if (dma_preamble == PREAMBLE_TAIL) ns.sample_flag = 2'b10;
				   	W_DATA = ns.dma_flit;				
				end
            end
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
    assign W_STRB   = cs.w_strb;
    assign B_READY  = 1'b1;

    always_ff @(posedge ACLK, negedge ARESETn) begin
        if (ARESETn == 1'b0) begin
            current_state <= RECEIVE_HEADER;
            //next_state 	<= RECEIVE_HEADER;
            cs.msg      <= REQ_GETS_W;
            cs.coh_flit <= 0;
			cs.dma_flit <= 0;
            cs.ax_prot  <= 0; 
	        //cs.ax_addr  <= 0;

            cs.ar_addr  <= 0;
            cs.count    <= 0;
            cs.burst_flag <= 0;
			cs.sample_flag <= 0;
			cs.coh_dma_flag <= 0;
            
            cs.ar_len   <= 0;
            cs.ar_size  <= 3'b010;
            cs.ar_prot  <= 0; 

            cs.aw_addr  <= 0;
            cs.aw_len   <= 0;
            cs.aw_size  <= 3'b010;
            cs.aw_prot  <= 0;

			cs.w_strb	<= 0;

			cs.word_cnt <= 0;
			cs.dma_noc_data <= 0;

			cs.hsize_msb <= 0;

        end else begin
            current_state <= next_state;
            cs <= ns;
        end
    end


    // Create Response Header (COH)
    logic [	   `MSG_TYPE_WIDTH-1 : 0] input_msg_type;
    logic [	   `MSG_TYPE_WIDTH-1 : 0] msg_type;
    logic [ this_coh_flit_size-1 : 0] header_v;
    logic [            		   2 : 0] origin_y;
    logic [               	   2 : 0] origin_x;
    logic [`NEXT_ROUTING_WIDTH-1 : 0] go_right;
    logic [`NEXT_ROUTING_WIDTH-1 : 0] go_left;


    always_comb begin
		input_msg_type = pad_coherence_req_data_out[this_coh_flit_size - `PREAMBLE_WIDTH - 4*GLOB_YX_WIDTH - 1:this_coh_flit_size - `PREAMBLE_WIDTH - 4*GLOB_YX_WIDTH - `MSG_TYPE_WIDTH];

		if (input_msg_type == AHB_RD) 											msg_type = RSP_AHB_RD; 
		else			      		  											msg_type = RSP_DATA;
			
		origin_y = pad_coherence_req_data_out[  this_coh_flit_size - `PREAMBLE_WIDTH - GLOB_YX_WIDTH + 2 :   this_coh_flit_size - `PREAMBLE_WIDTH - GLOB_YX_WIDTH];
		origin_x = pad_coherence_req_data_out[this_coh_flit_size - `PREAMBLE_WIDTH - 2*GLOB_YX_WIDTH + 2 : this_coh_flit_size - `PREAMBLE_WIDTH - 2*GLOB_YX_WIDTH];
		header_v = 0;
		header_v[this_coh_flit_size-1 : this_coh_flit_size - `PREAMBLE_WIDTH] = PREAMBLE_HEADER;
		header_v[this_coh_flit_size - `PREAMBLE_WIDTH - 1 : this_coh_flit_size - `PREAMBLE_WIDTH - GLOB_YX_WIDTH] = local_y;
		header_v[this_coh_flit_size - `PREAMBLE_WIDTH - GLOB_YX_WIDTH - 1 : this_coh_flit_size - `PREAMBLE_WIDTH - 2*GLOB_YX_WIDTH] = local_x;
		header_v[this_coh_flit_size - `PREAMBLE_WIDTH - 2*GLOB_YX_WIDTH - 1 : this_coh_flit_size - `PREAMBLE_WIDTH - 3*GLOB_YX_WIDTH] = origin_y;
		header_v[this_coh_flit_size - `PREAMBLE_WIDTH - 3*GLOB_YX_WIDTH - 1 : this_coh_flit_size - `PREAMBLE_WIDTH - 4*GLOB_YX_WIDTH] = origin_x;
		header_v[this_coh_flit_size - `PREAMBLE_WIDTH - 4*GLOB_YX_WIDTH - 1 : this_coh_flit_size - `PREAMBLE_WIDTH -  4*GLOB_YX_WIDTH - `MSG_TYPE_WIDTH] = msg_type;

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
    logic [  DMA_NOC_FLIT_SIZE-1 : 0] header_v_dma;
    logic [                	   2 : 0] origin_y_dma;
    logic [                	   2 : 0] origin_x_dma;
    logic [`NEXT_ROUTING_WIDTH-1 : 0] go_right_dma;
    logic [`NEXT_ROUTING_WIDTH-1 : 0] go_left_dma;


    always_comb begin

		input_msg_type_dma = pad_dma_rcv_data_out[DMA_NOC_FLIT_SIZE - `PREAMBLE_WIDTH - 4*GLOB_YX_WIDTH - 1:DMA_NOC_FLIT_SIZE - `PREAMBLE_WIDTH - 4*GLOB_YX_WIDTH - `MSG_TYPE_WIDTH];

		if (input_msg_type_dma == REQ_DMA_READ) msg_type_dma = RSP_DATA_DMA; 
		else			       	    			msg_type_dma = DMA_TO_DEV;
			
		//reserved_resp_dma = 0;
		origin_y_dma = pad_dma_rcv_data_out[DMA_NOC_FLIT_SIZE - `PREAMBLE_WIDTH - GLOB_YX_WIDTH + 2:DMA_NOC_FLIT_SIZE - `PREAMBLE_WIDTH - GLOB_YX_WIDTH];
		origin_x_dma = pad_dma_rcv_data_out[DMA_NOC_FLIT_SIZE - `PREAMBLE_WIDTH - 2*GLOB_YX_WIDTH + 2:DMA_NOC_FLIT_SIZE - `PREAMBLE_WIDTH - 2*GLOB_YX_WIDTH];
		header_v_dma = 0;
		header_v_dma[DMA_NOC_FLIT_SIZE-1 : DMA_NOC_FLIT_SIZE - `PREAMBLE_WIDTH] = PREAMBLE_HEADER;
		header_v_dma[DMA_NOC_FLIT_SIZE - `PREAMBLE_WIDTH - 1 : DMA_NOC_FLIT_SIZE - `PREAMBLE_WIDTH - GLOB_YX_WIDTH] = local_y;
		header_v_dma[DMA_NOC_FLIT_SIZE - `PREAMBLE_WIDTH - GLOB_YX_WIDTH - 1 : DMA_NOC_FLIT_SIZE - `PREAMBLE_WIDTH - 2*GLOB_YX_WIDTH] = local_x;
		header_v_dma[DMA_NOC_FLIT_SIZE - `PREAMBLE_WIDTH - 2*GLOB_YX_WIDTH - 1 : DMA_NOC_FLIT_SIZE - `PREAMBLE_WIDTH - 3*GLOB_YX_WIDTH] = origin_y_dma;
		header_v_dma[DMA_NOC_FLIT_SIZE - `PREAMBLE_WIDTH - 3*GLOB_YX_WIDTH - 1 : DMA_NOC_FLIT_SIZE - `PREAMBLE_WIDTH - 4*GLOB_YX_WIDTH] = origin_x_dma;
		header_v_dma[DMA_NOC_FLIT_SIZE - `PREAMBLE_WIDTH - 4*GLOB_YX_WIDTH - 1 : DMA_NOC_FLIT_SIZE - `PREAMBLE_WIDTH -  4*GLOB_YX_WIDTH - `MSG_TYPE_WIDTH] = msg_type_dma;
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
    always_ff @(posedge ACLK, negedge ARESETn) begin
        if (ARESETn == 1'b0) begin
			header_reg <= 0;
			dma_header_reg <= 0;
		end
		else begin
			if (sample_header == 1'b1) 
				header_reg <= header;
			if (sample_dma_header == 1'b1)
				dma_header_reg <= dma_header;
		end
    end

endmodule
