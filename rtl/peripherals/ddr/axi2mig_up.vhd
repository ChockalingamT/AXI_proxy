-- Copyright (c) 2011-2026 Columbia University, System Level Design Group
-- SPDX-License-Identifier: Apache-2.0

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

entity axi2mig_up is
  generic(
    AXIDW                   : integer := 64;
    clamshell				: integer range 0 to 1
  );
  port(
    c0_sys_clk_p     : in    std_logic;
    c0_sys_clk_n     : in    std_logic;
    c0_ddr4_act_n    : out   std_logic;
    c0_ddr4_adr      : out   std_logic_vector(16 downto 0);
    c0_ddr4_ba       : out   std_logic_vector(1 downto 0);
    c0_ddr4_bg       : out   std_logic_vector(0 downto 0);
    c0_ddr4_cke      : out   std_logic_vector(0 downto 0);
    c0_ddr4_odt      : out   std_logic_vector(0 downto 0);
    c0_ddr4_cs_n     : out   std_logic_vector(1 downto 0);
    c0_ddr4_ck_t     : out   std_logic_vector(0 downto 0);
    c0_ddr4_ck_c     : out   std_logic_vector(0 downto 0);
    c0_ddr4_reset_n  : out   std_logic;
    c0_ddr4_dm_dbi_n : inout std_logic_vector(7 downto 0);
    c0_ddr4_dq       : inout std_logic_vector(63 downto 0);
    c0_ddr4_dqs_c    : inout std_logic_vector(7 downto 0);
    c0_ddr4_dqs_t    : inout std_logic_vector(7 downto 0); 
    -- Slave Interface Write Address Ports
    s_axi_awid           : in std_logic_vector(7 downto 0);
    s_axi_awaddr         : in std_logic_vector(31 downto 0);
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
    s_axi_bid            : out std_logic_vector(7 downto 0);
    s_axi_bresp          : out std_logic_vector(1 downto 0);
    s_axi_bvalid         : out std_logic;
    -- Slave Interface Read Address Ports
    s_axi_arid           : in std_logic_vector(7 downto 0);
    s_axi_araddr         : in std_logic_vector(31 downto 0);
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
    s_axi_rid            : out std_logic_vector(7 downto 0);
    s_axi_rdata          : out std_logic_vector(AXIDW-1 downto 0);
    s_axi_rresp          : out std_logic_vector(1 downto 0);
    s_axi_rlast          : out std_logic;
    s_axi_rvalid         : out std_logic;
 
    calib_done       : out   std_logic;
    rst_n_syn        : in    std_logic;
    rst_n_async      : in    std_logic;
    ui_clk           : out   std_logic;
	ui_clk_slow		 : out   std_logic;
    ui_clk_sync_rst  : out   std_logic
    );
end;

architecture rtl of axi2mig_up is
  component mig is
    port (
      c0_init_calib_complete    : out std_logic;
      c0_sys_clk_p              : in  std_logic;
  	  dbg_clk 					: out std_logic;
      c0_sys_clk_n              : in  std_logic;
      c0_ddr4_act_n             : out std_logic;
      c0_ddr4_adr               : out std_logic_vector(16 downto 0);
      c0_ddr4_ba                : out std_logic_vector(1 downto 0);
      c0_ddr4_bg                : out std_logic_vector(0 downto 0);
      c0_ddr4_cke               : out std_logic_vector(0 downto 0);
      c0_ddr4_odt               : out std_logic_vector(0 downto 0);
      c0_ddr4_cs_n              : out std_logic_vector(0 downto 0);
      c0_ddr4_ck_t              : out std_logic_vector(0 downto 0);
      c0_ddr4_ck_c              : out std_logic_vector(0 downto 0);
      c0_ddr4_reset_n           : out std_logic;
      c0_ddr4_dm_dbi_n          : in  std_logic_vector(7 downto 0);
      c0_ddr4_dq                : in  std_logic_vector(63 downto 0);
      c0_ddr4_dqs_c             : in  std_logic_vector(7 downto 0);
      c0_ddr4_dqs_t             : in  std_logic_vector(7 downto 0);
      c0_ddr4_ui_clk            : out std_logic;
      c0_ddr4_ui_clk_sync_rst   : out std_logic;
	  dbg_bus 					: out std_logic_vector(511 DOWNTO 0);
      -- Slave Interface Write Address Ports
      c0_ddr4_aresetn              : in std_logic;
      c0_ddr4_s_axi_awid           : in std_logic_vector(7 downto 0);
      c0_ddr4_s_axi_awaddr         : in std_logic_vector(31 downto 0);
      c0_ddr4_s_axi_awlen          : in std_logic_vector(7 downto 0);
      c0_ddr4_s_axi_awsize         : in std_logic_vector(2 downto 0);
      c0_ddr4_s_axi_awburst        : in std_logic_vector(1 downto 0);
      c0_ddr4_s_axi_awlock         : in std_logic;
      c0_ddr4_s_axi_awcache        : in std_logic_vector(3 downto 0);
      c0_ddr4_s_axi_awprot         : in std_logic_vector(2 downto 0);
      c0_ddr4_s_axi_awqos          : in std_logic_vector(3 downto 0);
      c0_ddr4_s_axi_awvalid        : in    std_logic;
      c0_ddr4_s_axi_awready        : out   std_logic;
      --Slave Interface Write Data Ports
      c0_ddr4_s_axi_wdata          : in std_logic_vector(AXIDW-1 downto 0);
      c0_ddr4_s_axi_wstrb          : in std_logic_vector((AXIDW/8)-1 downto 0);
      c0_ddr4_s_axi_wlast          : in std_logic;
      c0_ddr4_s_axi_wvalid         : in std_logic;
      c0_ddr4_s_axi_wready         : out std_logic;
      -- Slave Interface Write Response Ports
      c0_ddr4_s_axi_bready         : in std_logic;
      c0_ddr4_s_axi_bid            : out std_logic_vector(7 downto 0);
      c0_ddr4_s_axi_bresp          : out std_logic_vector(1 downto 0);
      c0_ddr4_s_axi_bvalid         : out std_logic;
      -- Slave Interface Read Address Ports
      c0_ddr4_s_axi_arid           : in std_logic_vector(7 downto 0);
      c0_ddr4_s_axi_araddr         : in std_logic_vector(31 downto 0);
      c0_ddr4_s_axi_arlen          : in std_logic_vector(7 downto 0);
      c0_ddr4_s_axi_arsize         : in std_logic_vector(2 downto 0);
      c0_ddr4_s_axi_arburst        : in std_logic_vector(1 downto 0);
      c0_ddr4_s_axi_arlock         : in std_logic;
      c0_ddr4_s_axi_arcache        : in std_logic_vector(3 downto 0);
      c0_ddr4_s_axi_arprot         : in std_logic_vector(2 downto 0);
      c0_ddr4_s_axi_arqos          : in std_logic_vector(3 downto 0);
      c0_ddr4_s_axi_arvalid        : in std_logic;
      c0_ddr4_s_axi_arready        : out std_logic;
      -- Slave Interface Read Data Ports
      c0_ddr4_s_axi_rready         : in std_logic;
      c0_ddr4_s_axi_rid            : out std_logic_vector(7 downto 0);
      c0_ddr4_s_axi_rdata          : out std_logic_vector(AXIDW-1 downto 0);
      c0_ddr4_s_axi_rresp          : out std_logic_vector(1 downto 0);
      c0_ddr4_s_axi_rlast          : out std_logic;
      c0_ddr4_s_axi_rvalid         : out std_logic;
      addn_ui_clkout1 			   : out std_logic;
      sys_rst 					   : in std_logic
      );
  end component mig;


  component mig_clamshell is
    port (
      c0_init_calib_complete    : out std_logic;
      c0_sys_clk_p              : in  std_logic;
  	  dbg_clk 					: out std_logic;
      c0_sys_clk_n              : in  std_logic;
      c0_ddr4_act_n             : out std_logic;
      c0_ddr4_adr               : out std_logic_vector(16 downto 0);
      c0_ddr4_ba                : out std_logic_vector(1 downto 0);
      c0_ddr4_bg                : out std_logic_vector(0 downto 0);
      c0_ddr4_cke               : out std_logic_vector(0 downto 0);
      c0_ddr4_odt               : out std_logic_vector(0 downto 0);
      c0_ddr4_cs_n              : out std_logic_vector(1 downto 0);
      c0_ddr4_ck_t              : out std_logic_vector(0 downto 0);
      c0_ddr4_ck_c              : out std_logic_vector(0 downto 0);
      c0_ddr4_reset_n           : out std_logic;
      c0_ddr4_dm_dbi_n          : in  std_logic_vector(7 downto 0);
      c0_ddr4_dq                : in  std_logic_vector(63 downto 0);
      c0_ddr4_dqs_c             : in  std_logic_vector(7 downto 0);
      c0_ddr4_dqs_t             : in  std_logic_vector(7 downto 0);
      c0_ddr4_ui_clk            : out std_logic;
      c0_ddr4_ui_clk_sync_rst   : out std_logic;
	  dbg_bus 					: out std_logic_vector(511 DOWNTO 0);
      -- Slave Interface Write Address Ports
      c0_ddr4_aresetn              : in std_logic;
      c0_ddr4_s_axi_awid           : in std_logic_vector(7 downto 0);
      c0_ddr4_s_axi_awaddr         : in std_logic_vector(31 downto 0);
      c0_ddr4_s_axi_awlen          : in std_logic_vector(7 downto 0);
      c0_ddr4_s_axi_awsize         : in std_logic_vector(2 downto 0);
      c0_ddr4_s_axi_awburst        : in std_logic_vector(1 downto 0);
      c0_ddr4_s_axi_awlock         : in std_logic;
      c0_ddr4_s_axi_awcache        : in std_logic_vector(3 downto 0);
      c0_ddr4_s_axi_awprot         : in std_logic_vector(2 downto 0);
      c0_ddr4_s_axi_awqos          : in std_logic_vector(3 downto 0);
      c0_ddr4_s_axi_awvalid        : in    std_logic;
      c0_ddr4_s_axi_awready        : out   std_logic;
      --Slave Interface Write Data Ports
      c0_ddr4_s_axi_wdata          : in std_logic_vector(AXIDW-1 downto 0);
      c0_ddr4_s_axi_wstrb          : in std_logic_vector((AXIDW/8)-1 downto 0);
      c0_ddr4_s_axi_wlast          : in std_logic;
      c0_ddr4_s_axi_wvalid         : in std_logic;
      c0_ddr4_s_axi_wready         : out std_logic;
      -- Slave Interface Write Response Ports
      c0_ddr4_s_axi_bready         : in std_logic;
      c0_ddr4_s_axi_bid            : out std_logic_vector(7 downto 0);
      c0_ddr4_s_axi_bresp          : out std_logic_vector(1 downto 0);
      c0_ddr4_s_axi_bvalid         : out std_logic;
      -- Slave Interface Read Address Ports
      c0_ddr4_s_axi_arid           : in std_logic_vector(7 downto 0);
      c0_ddr4_s_axi_araddr         : in std_logic_vector(31 downto 0);
      c0_ddr4_s_axi_arlen          : in std_logic_vector(7 downto 0);
      c0_ddr4_s_axi_arsize         : in std_logic_vector(2 downto 0);
      c0_ddr4_s_axi_arburst        : in std_logic_vector(1 downto 0);
      c0_ddr4_s_axi_arlock         : in std_logic;
      c0_ddr4_s_axi_arcache        : in std_logic_vector(3 downto 0);
      c0_ddr4_s_axi_arprot         : in std_logic_vector(2 downto 0);
      c0_ddr4_s_axi_arqos          : in std_logic_vector(3 downto 0);
      c0_ddr4_s_axi_arvalid        : in std_logic;
      c0_ddr4_s_axi_arready        : out std_logic;
      -- Slave Interface Read Data Ports
      c0_ddr4_s_axi_rready         : in std_logic;
      c0_ddr4_s_axi_rid            : out std_logic_vector(7 downto 0);
      c0_ddr4_s_axi_rdata          : out std_logic_vector(AXIDW-1 downto 0);
      c0_ddr4_s_axi_rresp          : out std_logic_vector(1 downto 0);
      c0_ddr4_s_axi_rlast          : out std_logic;
      c0_ddr4_s_axi_rvalid         : out std_logic;
      addn_ui_clkout1 			   : out std_logic;
      sys_rst 					   : in std_logic
      );
  end component mig_clamshell;
  
  signal sys_rst : std_logic;

  begin
  
  sys_rst <= not rst_n_async;
  no_clamshell_gen: if clamshell = 0 generate
    mig_inst : mig
      PORT MAP (
        c0_init_calib_complete 		=> calib_done,
        dbg_clk 					=> open,
        c0_sys_clk_p 				=> c0_sys_clk_p,
        c0_sys_clk_n 				=> c0_sys_clk_n,
        dbg_bus 					=> open,
        c0_ddr4_adr 				=> c0_ddr4_adr,
        c0_ddr4_ba 					=> c0_ddr4_ba,
        c0_ddr4_cke 				=> c0_ddr4_cke,
        c0_ddr4_cs_n 				=> c0_ddr4_cs_n(0 downto 0),
        c0_ddr4_dm_dbi_n 			=> c0_ddr4_dm_dbi_n,
        c0_ddr4_dq 					=> c0_ddr4_dq,
        c0_ddr4_dqs_c 				=> c0_ddr4_dqs_c,
        c0_ddr4_dqs_t 				=> c0_ddr4_dqs_t,
        c0_ddr4_odt 				=> c0_ddr4_odt,
        c0_ddr4_bg 					=> c0_ddr4_bg,
        c0_ddr4_reset_n 			=> c0_ddr4_reset_n,
        c0_ddr4_act_n 				=> c0_ddr4_act_n,
        c0_ddr4_ck_c 				=> c0_ddr4_ck_c,
        c0_ddr4_ck_t 				=> c0_ddr4_ck_t,
        c0_ddr4_ui_clk 				=> ui_clk,
        c0_ddr4_ui_clk_sync_rst 	=> ui_clk_sync_rst,
        c0_ddr4_aresetn 			=> rst_n_syn,
        c0_ddr4_s_axi_awid 			=> s_axi_awid,
        c0_ddr4_s_axi_awaddr 		=> s_axi_awaddr,
        c0_ddr4_s_axi_awlen 		=> s_axi_awlen,
        c0_ddr4_s_axi_awsize 		=> s_axi_awsize,
        c0_ddr4_s_axi_awburst 		=> s_axi_awburst,
        c0_ddr4_s_axi_awlock 		=> s_axi_awlock,
        c0_ddr4_s_axi_awcache 		=> s_axi_awcache,
        c0_ddr4_s_axi_awprot 		=> s_axi_awprot,
        c0_ddr4_s_axi_awqos 		=> s_axi_awqos,
        c0_ddr4_s_axi_awvalid 		=> s_axi_awvalid,
        c0_ddr4_s_axi_awready 		=> s_axi_awready,
        c0_ddr4_s_axi_wdata 		=> s_axi_wdata,
        c0_ddr4_s_axi_wstrb 		=> s_axi_wstrb,
        c0_ddr4_s_axi_wlast 		=> s_axi_wlast,
        c0_ddr4_s_axi_wvalid 		=> s_axi_wvalid,
        c0_ddr4_s_axi_wready 		=> s_axi_wready,
        c0_ddr4_s_axi_bready 		=> s_axi_bready,
        c0_ddr4_s_axi_bid 			=> s_axi_bid,
        c0_ddr4_s_axi_bresp 		=> s_axi_bresp,
        c0_ddr4_s_axi_bvalid 		=> s_axi_bvalid,
        c0_ddr4_s_axi_arid 			=> s_axi_arid,
        c0_ddr4_s_axi_araddr 		=> s_axi_araddr,
        c0_ddr4_s_axi_arlen 		=> s_axi_arlen,
        c0_ddr4_s_axi_arsize 		=> s_axi_arsize,
        c0_ddr4_s_axi_arburst 		=> s_axi_arburst,
        c0_ddr4_s_axi_arlock 		=> s_axi_arlock,
        c0_ddr4_s_axi_arcache 		=> s_axi_arcache,
        c0_ddr4_s_axi_arprot 		=> s_axi_arprot,
        c0_ddr4_s_axi_arqos 		=> s_axi_arqos,
        c0_ddr4_s_axi_arvalid 		=> s_axi_arvalid,
        c0_ddr4_s_axi_arready 		=> s_axi_arready,
        c0_ddr4_s_axi_rready 		=> s_axi_rready,
        c0_ddr4_s_axi_rlast 		=> s_axi_rlast,
        c0_ddr4_s_axi_rvalid 		=> s_axi_rvalid,
        c0_ddr4_s_axi_rresp 		=> s_axi_rresp,
        c0_ddr4_s_axi_rid 			=> s_axi_rid,
        c0_ddr4_s_axi_rdata 		=> s_axi_rdata,
        addn_ui_clkout1 			=> ui_clk_slow,
        sys_rst 					=> sys_rst
      );
  c0_ddr4_cs_n(1) <= '1';
  end generate no_clamshell_gen;


  clamshell_gen: if clamshell /= 0 generate
    mig_inst : mig_clamshell
      PORT MAP (
        c0_init_calib_complete 		=> calib_done,
        dbg_clk 					=> open,
        c0_sys_clk_p 				=> c0_sys_clk_p,
        c0_sys_clk_n 				=> c0_sys_clk_n,
        dbg_bus 					=> open,
        c0_ddr4_adr 				=> c0_ddr4_adr,
        c0_ddr4_ba 					=> c0_ddr4_ba,
        c0_ddr4_cke 				=> c0_ddr4_cke,
        c0_ddr4_cs_n 				=> c0_ddr4_cs_n,
        c0_ddr4_dm_dbi_n 			=> c0_ddr4_dm_dbi_n,
        c0_ddr4_dq 					=> c0_ddr4_dq,
        c0_ddr4_dqs_c 				=> c0_ddr4_dqs_c,
        c0_ddr4_dqs_t 				=> c0_ddr4_dqs_t,
        c0_ddr4_odt 				=> c0_ddr4_odt,
        c0_ddr4_bg 					=> c0_ddr4_bg,
        c0_ddr4_reset_n 			=> c0_ddr4_reset_n,
        c0_ddr4_act_n 				=> c0_ddr4_act_n,
        c0_ddr4_ck_c 				=> c0_ddr4_ck_c,
        c0_ddr4_ck_t 				=> c0_ddr4_ck_t,
        c0_ddr4_ui_clk 				=> ui_clk,
        c0_ddr4_ui_clk_sync_rst 	=> ui_clk_sync_rst,
        c0_ddr4_aresetn 			=> rst_n_syn,
        c0_ddr4_s_axi_awid 			=> s_axi_awid,
        c0_ddr4_s_axi_awaddr 		=> s_axi_awaddr,
        c0_ddr4_s_axi_awlen 		=> s_axi_awlen,
        c0_ddr4_s_axi_awsize 		=> s_axi_awsize,
        c0_ddr4_s_axi_awburst 		=> s_axi_awburst,
        c0_ddr4_s_axi_awlock 		=> s_axi_awlock,
        c0_ddr4_s_axi_awcache 		=> s_axi_awcache,
        c0_ddr4_s_axi_awprot 		=> s_axi_awprot,
        c0_ddr4_s_axi_awqos 		=> s_axi_awqos,
        c0_ddr4_s_axi_awvalid 		=> s_axi_awvalid,
        c0_ddr4_s_axi_awready 		=> s_axi_awready,
        c0_ddr4_s_axi_wdata 		=> s_axi_wdata,
        c0_ddr4_s_axi_wstrb 		=> s_axi_wstrb,
        c0_ddr4_s_axi_wlast 		=> s_axi_wlast,
        c0_ddr4_s_axi_wvalid 		=> s_axi_wvalid,
        c0_ddr4_s_axi_wready 		=> s_axi_wready,
        c0_ddr4_s_axi_bready 		=> s_axi_bready,
        c0_ddr4_s_axi_bid 			=> s_axi_bid,
        c0_ddr4_s_axi_bresp 		=> s_axi_bresp,
        c0_ddr4_s_axi_bvalid 		=> s_axi_bvalid,
        c0_ddr4_s_axi_arid 			=> s_axi_arid,
        c0_ddr4_s_axi_araddr 		=> s_axi_araddr,
        c0_ddr4_s_axi_arlen 		=> s_axi_arlen,
        c0_ddr4_s_axi_arsize 		=> s_axi_arsize,
        c0_ddr4_s_axi_arburst 		=> s_axi_arburst,
        c0_ddr4_s_axi_arlock 		=> s_axi_arlock,
        c0_ddr4_s_axi_arcache 		=> s_axi_arcache,
        c0_ddr4_s_axi_arprot 		=> s_axi_arprot,
        c0_ddr4_s_axi_arqos 		=> s_axi_arqos,
        c0_ddr4_s_axi_arvalid 		=> s_axi_arvalid,
        c0_ddr4_s_axi_arready 		=> s_axi_arready,
        c0_ddr4_s_axi_rready 		=> s_axi_rready,
        c0_ddr4_s_axi_rlast 		=> s_axi_rlast,
        c0_ddr4_s_axi_rvalid 		=> s_axi_rvalid,
        c0_ddr4_s_axi_rresp 		=> s_axi_rresp,
        c0_ddr4_s_axi_rid 			=> s_axi_rid,
        c0_ddr4_s_axi_rdata 		=> s_axi_rdata,
        addn_ui_clkout1 			=> ui_clk_slow,
        sys_rst 					=> sys_rst
      );
  end generate clamshell_gen;


end;
