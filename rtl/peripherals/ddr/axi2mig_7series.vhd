------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2016, Cobham Gaisler
--
--  This program is free software; you can redistribute it and/or modify
--  it under the terms of the GNU General Public License as published by
--  the Free Software Foundation; either version 2 of the License, or
--  (at your option) any later version.
--
--  This program is distributed in the hope that it will be useful,
--  but WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--  GNU General Public License for more details.
--
--  You should have received a copy of the GNU General Public License
--  along with this program; if not, write to the Free Software
--  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA 
-------------------------------------------------------------------------------
-- Entity:      ahb2mig
-- File:        ahb2mig.vhd
-- Author:      Fredrik Ringhage - Aeroflex Gaisler AB
--
--  This is a AHB-2.0 interface for the Xilinx Virtex-7 MIG.
--
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.all;
use work.amba.all;
use work.stdlib.all;
use work.devices.all;
use work.config_types.all;
use work.config.all;
library std;
use std.textio.all;

entity axi2mig_7series is
  generic(
	AXIDW					: integer := 64
    );
  port(
    ddr3_dq         : inout std_logic_vector(63 downto 0);
    ddr3_dqs_p      : inout std_logic_vector(7 downto 0);
    ddr3_dqs_n      : inout std_logic_vector(7 downto 0);
    ddr3_addr       : out   std_logic_vector(13 downto 0);
    ddr3_ba         : out   std_logic_vector(2 downto 0);
    ddr3_ras_n      : out   std_logic;
    ddr3_cas_n      : out   std_logic;
    ddr3_we_n       : out   std_logic;
    ddr3_reset_n    : out   std_logic;
    ddr3_ck_p       : out   std_logic_vector(0 downto 0);
    ddr3_ck_n       : out   std_logic_vector(0 downto 0);
    ddr3_cke        : out   std_logic_vector(0 downto 0);
    ddr3_cs_n       : out   std_logic_vector(0 downto 0);
    ddr3_dm         : out   std_logic_vector(7 downto 0);
    ddr3_odt        : out   std_logic_vector(0 downto 0);

	calib_done      : out   std_logic;
	rst_n_syn       : in    std_logic;
	rst_n_async     : in    std_logic;
	
    sys_clk_p       : in    std_logic;
    sys_clk_n       : in    std_logic;
    clk_ref_i       : in    std_logic;
    ui_clk          : out   std_logic;
    ui_clk_sync_rst : out   std_logic;
    
    s_axi_awid0     : in    std_logic_vector(7 downto 0);
    s_axi_awaddr0   : in    std_logic_vector(31 downto 0);
    s_axi_awlen     : in    std_logic_vector(7 downto 0);
    s_axi_awsize    : in    std_logic_vector(2 downto 0);
    s_axi_awburst   : in    std_logic_vector(1 downto 0);
    s_axi_awlock    : in    std_logic;
    s_axi_awcache   : in    std_logic_vector(3 downto 0);
    s_axi_awprot    : in    std_logic_vector(2 downto 0);
    s_axi_awqos     : in    std_logic_vector(3 downto 0);
    s_axi_awvalid   : in    std_logic;  
    s_axi_awready   : out   std_logic;
    s_axi_wdata0    : in    std_logic_vector(AXIDW-1 downto 0);
    s_axi_wstrb0    : in    std_logic_vector((AXIDW/8)-1 downto 0);
    s_axi_wlast     : in    std_logic;
    s_axi_wvalid    : in    std_logic;
    s_axi_wready    : out   std_logic;
    s_axi_bready    : in    std_logic;
    s_axi_bid0      : out   std_logic_vector(7 downto 0);
    s_axi_bresp     : out   std_logic_vector(1 downto 0);
    s_axi_bvalid    : out   std_logic;
    s_axi_arid0     : in    std_logic_vector(7 downto 0);
    s_axi_araddr0   : in    std_logic_vector(31 downto 0);
    s_axi_arlen     : in    std_logic_vector(7 downto 0);
    s_axi_arsize    : in    std_logic_vector(2 downto 0);
    s_axi_arburst   : in    std_logic_vector(1 downto 0);
    s_axi_arlock    : in    std_logic;
    s_axi_arcache   : in    std_logic_vector(3 downto 0);
    s_axi_arprot    : in    std_logic_vector(2 downto 0);
    s_axi_arqos     : in    std_logic_vector(3 downto 0);
    s_axi_arvalid   : in    std_logic;
    s_axi_arready   : out   std_logic;
    s_axi_rready    : in    std_logic;
    s_axi_rid0      : out   std_logic_vector(7 downto 0);
    s_axi_rdata0    : out   std_logic_vector(AXIDW-1 downto 0);
    s_axi_rresp     : out   std_logic_vector(1 downto 0);
    s_axi_rlast     : out   std_logic;
    s_axi_rvalid    : out   std_logic
    );
end;

architecture rtl of axi2mig_7series is

signal mmcm_locked : std_logic;


component mig is
   port (
    ddr3_dq              : inout std_logic_vector(63 downto 0);--
    ddr3_addr            : out   std_logic_vector(13 downto 0);--
    ddr3_ba              : out   std_logic_vector(2 downto 0);--
    ddr3_ras_n           : out   std_logic;--
    ddr3_cas_n           : out   std_logic;--
    ddr3_we_n            : out   std_logic;--
    ddr3_reset_n         : out   std_logic;--
    ddr3_dqs_n           : inout std_logic_vector(7 downto 0);--
    ddr3_dqs_p           : inout std_logic_vector(7 downto 0);--
    ddr3_ck_p            : out   std_logic_vector(0 downto 0);--
    ddr3_ck_n            : out   std_logic_vector(0 downto 0);--
    ddr3_cke             : out   std_logic_vector(0 downto 0);--
    ddr3_cs_n            : out   std_logic_vector(0 downto 0);--
    ddr3_dm              : out   std_logic_vector(7 downto 0);--
    ddr3_odt             : out   std_logic_vector(0 downto 0);--
    sys_clk_p            : in    std_logic;--
    sys_clk_n            : in    std_logic;--
    clk_ref_i            : in    std_logic;--
    -- Slave Interface Write Address Ports
    aresetn              : in std_logic;
    s_axi_awid           : in std_logic_vector(3 downto 0);
    s_axi_awaddr         : in std_logic_vector(29 downto 0);
    s_axi_awlen          : in std_logic_vector(7 downto 0);
    s_axi_awsize         : in std_logic_vector(2 downto 0);
    s_axi_awburst        : in std_logic_vector(1 downto 0);
    s_axi_awlock         : in std_logic;  
    s_axi_awcache        : in std_logic_vector(3 downto 0);
    s_axi_awprot         : in std_logic_vector(2 downto 0);
    s_axi_awqos          : in std_logic_vector(3 downto 0);
    s_axi_awvalid        : in    std_logic;
    s_axi_awready        : out   std_logic;
    --Slave Interface Write Data Ports
    s_axi_wdata          : in std_logic_vector(AXIDW-1 downto 0);
    s_axi_wstrb          : in std_logic_vector((AXIDW/8)-1 downto 0);
    s_axi_wlast          : in std_logic;
    s_axi_wvalid         : in std_logic;
    s_axi_wready         : out std_logic;
    -- Slave Interface Write Response Ports
    s_axi_bready         : in std_logic;
    s_axi_bid            : out std_logic_vector(3 downto 0);
    s_axi_bresp          : out std_logic_vector(1 downto 0);
    s_axi_bvalid         : out std_logic;
    -- Slave Interface Read Address Ports
    s_axi_arid           : in std_logic_vector(3 downto 0);
    s_axi_araddr         : in std_logic_vector(29 downto 0);
    s_axi_arlen          : in std_logic_vector(7 downto 0);
    s_axi_arsize         : in std_logic_vector(2 downto 0);
    s_axi_arburst        : in std_logic_vector(1 downto 0);
    s_axi_arlock         : in std_logic;  
    s_axi_arcache        : in std_logic_vector(3 downto 0);
    s_axi_arprot         : in std_logic_vector(2 downto 0);
    s_axi_arqos          : in std_logic_vector(3 downto 0);
    s_axi_arvalid        : in std_logic;
    s_axi_arready        : out std_logic;
    -- Slave Interface Read Data Ports
    s_axi_rready         : in std_logic;
    s_axi_rid            : out std_logic_vector(3 downto 0);
    s_axi_rdata          : out std_logic_vector(AXIDW-1 downto 0);
    s_axi_rresp          : out std_logic_vector(1 downto 0);
    s_axi_rlast          : out std_logic;
    s_axi_rvalid         : out std_logic;
    app_sr_req           : in    std_logic;--
    app_ref_req          : in    std_logic;--
    app_zq_req           : in    std_logic;--
    app_sr_active        : out   std_logic;--
    app_ref_ack          : out   std_logic;--
    app_zq_ack           : out   std_logic;--
    ui_clk               : out   std_logic;--
    ui_clk_sync_rst      : out   std_logic;--
    mmcm_locked          : out   std_logic;  
    init_calib_complete  : out   std_logic;--
    sys_rst              : in    std_logic--
    );
 end component mig;
  
  begin
  
  MCB_inst : mig
    port map (
		ddr3_dq             => ddr3_dq,--
		ddr3_dqs_p          => ddr3_dqs_p,--
		ddr3_dqs_n          => ddr3_dqs_n,--
		ddr3_addr           => ddr3_addr,--
		ddr3_ba             => ddr3_ba,--
		ddr3_ras_n          => ddr3_ras_n,--
		ddr3_cas_n          => ddr3_cas_n,--
		ddr3_we_n           => ddr3_we_n,--
		ddr3_reset_n        => ddr3_reset_n,--
		ddr3_ck_p           => ddr3_ck_p,--
		ddr3_ck_n           => ddr3_ck_n,--
		ddr3_cke            => ddr3_cke,--
		ddr3_cs_n           => ddr3_cs_n,--
		ddr3_dm             => ddr3_dm,--
		ddr3_odt            => ddr3_odt,--
		ui_clk              => ui_clk,--
		ui_clk_sync_rst     => ui_clk_sync_rst,--
		aresetn             => rst_n_syn,--
		mmcm_locked         => mmcm_locked,--
		app_sr_req          => '0',--
		app_ref_req         => '0',--
		app_zq_req          => '0',--
		app_sr_active       => open,--
		app_ref_ack         => open,--
		app_zq_ack          => open,--

		s_axi_awid          => s_axi_awid0(3 downto 0),--
		s_axi_awaddr        => s_axi_awaddr0(29 downto 0),--
		s_axi_awlen         => s_axi_awlen,--
		s_axi_awsize        => s_axi_awsize,--
		s_axi_awburst       => s_axi_awburst,--
		s_axi_awlock        => s_axi_awlock,--
		s_axi_awcache       => s_axi_awcache,--
		s_axi_awprot        => s_axi_awprot,--
		s_axi_awqos         => s_axi_awqos,--
		s_axi_awvalid       => s_axi_awvalid,--
		s_axi_awready       => s_axi_awready,--
		s_axi_wdata         => s_axi_wdata0,--
		s_axi_wstrb         => s_axi_wstrb0,--
		s_axi_wlast         => s_axi_wlast,--
		s_axi_wvalid        => s_axi_wvalid,--
		s_axi_wready        => s_axi_wready,--
		s_axi_bid           => s_axi_bid0(3 downto 0),--
		s_axi_bresp         => s_axi_bresp,--
		s_axi_bvalid        => s_axi_bvalid,--
		s_axi_bready        => s_axi_bready,--
		s_axi_arid          => s_axi_arid0(3 downto 0),--
		s_axi_araddr        => s_axi_araddr0(29 downto 0),--
		s_axi_arlen         => s_axi_arlen,--
		s_axi_arsize        => s_axi_arsize,--
		s_axi_arburst       => s_axi_arburst,--
		s_axi_arlock        => s_axi_arlock,--
		s_axi_arcache       => s_axi_arcache,--
		s_axi_arprot        => s_axi_arprot,--
		s_axi_arqos         => s_axi_arqos,--
		s_axi_arvalid       => s_axi_arvalid,--
		s_axi_arready       => s_axi_arready,--
		s_axi_rid           => s_axi_rid0(3 downto 0),--
		s_axi_rdata         => s_axi_rdata0,--
		s_axi_rresp         => s_axi_rresp,--
		s_axi_rlast         => s_axi_rlast,--
		s_axi_rvalid        => s_axi_rvalid,--
		s_axi_rready        => s_axi_rready,--

		sys_clk_p           => sys_clk_p,--
		sys_clk_n           => sys_clk_n,--
		clk_ref_i           => clk_ref_i,--
		init_calib_complete => calib_done,--
		sys_rst             => rst_n_async--
      );

end;

