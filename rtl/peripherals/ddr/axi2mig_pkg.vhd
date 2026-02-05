-- Copyright (c) 2011-2026 Columbia University, System Level Design Group
-- SPDX-License-Identifier: Apache-2.0

library ieee;
use ieee.std_logic_1164.all;

use work.esp_global.all;
use work.amba.all;
use work.gencomp.all;

package axi2mig_pkg is 

component axi2mig_7series is
  generic(
    AXIDW                   : integer := 64
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
    ddr_axi_si      : in    axi_mosi_type;
    ddr_axi_so      : out   axi_somi_type 
	);
end component; 

  component axi2mig_up is
    generic(
      AXIDW                   : integer := 64;
	  clamshell               : integer range 0 to 1
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
      ui_clk_slow      : out   std_logic;
      ui_clk_sync_rst  : out   std_logic
    );
end component;

end axi2mig_pkg;
