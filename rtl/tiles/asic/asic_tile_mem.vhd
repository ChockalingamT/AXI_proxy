-- Copyright (c) 2011-2024 Columbia University, System Level Design Group
-- SPDX-License-Identifier: Apache-2.0

-----------------------------------------------------------------------------
--  Memory interface tile
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.esp_global.all;
use work.amba.all;
use work.stdlib.all;
use work.sld_devices.all;
use work.devices.all;
use work.gencomp.all;
use work.leon3.all;
use work.misc.all;
-- pragma translate_off
use work.sim.all;
library unisim;
use unisim.all;
-- pragma translate_on
use work.monitor_pkg.all;
use work.esp_noc_csr_pkg.all;
use work.jtag_pkg.all;
use work.sldacc.all;
use work.nocpackage.all;
use work.tile.all;
use work.cachepackage.all;
use work.coretypes.all;

use work.grlib_config.all;
use work.socmap.all;
use work.tiles_pkg.all;

entity asic_tile_mem is
  generic (
    SIMULATION   : boolean   := false;
    HAS_SYNC     : integer range 0 to 1 := 1;
    ROUTER_PORTS : ports_vec := "11111";
    this_has_dco : integer range 0 to 1 := 1);
  port (
    rst                : in  std_ulogic;
    noc_clk            : in  std_ulogic;  -- NoC clock
    noc_clk_lock       : in  std_ulogic;  -- noc_clk_lock
    ext_clk            : in  std_ulogic;  -- backup tile clock
    clk_div            : out std_ulogic;  -- tile clock monitor for testing purposes
    -- FPGA proxy memory link
    fpga_data_in       : in  std_logic_vector(CFG_MEM_LINK_BITS - 1 downto 0);
    fpga_data_out      : out std_logic_vector(CFG_MEM_LINK_BITS - 1 downto 0);
    fpga_oen           : out std_ulogic;
    fpga_valid_in      : in  std_ulogic;
    fpga_valid_out     : out std_ulogic;
    fpga_clk_in        : in  std_ulogic;
    fpga_clk_out       : out std_ulogic;
    fpga_credit_in     : in  std_ulogic;
    fpga_credit_out    : out std_ulogic;
    s_axi_awid         : out   std_logic_vector(7 downto 0);    
    s_axi_awaddr       : out   std_logic_vector(31 downto 0);
    s_axi_awlen        : out   std_logic_vector(7 downto 0);
    s_axi_awsize       : out   std_logic_vector(2 downto 0);
    s_axi_awburst      : out   std_logic_vector(1 downto 0);
    s_axi_awlock       : out   std_logic;
    s_axi_awcache      : out   std_logic_vector(3 downto 0);
    s_axi_awprot       : out   std_logic_vector(2 downto 0);
    s_axi_awvalid      : out   std_logic;
    s_axi_awready      : in    std_logic;
    s_axi_wdata        : out   std_logic_vector(31 downto 0);
    s_axi_wstrb        : out   std_logic_vector(3 downto 0);
    s_axi_wlast        : out   std_logic;
    s_axi_wvalid       : out   std_logic;
    s_axi_wready       : in    std_logic;
    s_axi_bid          : in    std_logic_vector(7 downto 0);
    s_axi_bresp        : in    std_logic_vector(1 downto 0);
    s_axi_bvalid       : in    std_logic;
    s_axi_bready       : out   std_logic;
    s_axi_arid         : out   std_logic_vector(7 downto 0);
    s_axi_araddr       : out   std_logic_vector(31 downto 0);
    s_axi_arlen        : out   std_logic_vector(7 downto 0);
    s_axi_arsize       : out   std_logic_vector(2 downto 0);
    s_axi_arburst      : out   std_logic_vector(1 downto 0);
    s_axi_arlock       : out   std_logic;
    s_axi_arcache      : out   std_logic_vector(3 downto 0);
    s_axi_arprot       : out   std_logic_vector(2 downto 0);
    s_axi_arvalid      : out   std_logic;
    s_axi_arready      : in    std_logic;
    s_axi_rid          : in    std_logic_vector(7 downto 0);
    s_axi_rdata        : in    std_logic_vector(31 downto 0);   -- Test interface
    s_axi_rresp        : in    std_logic_vector(1 downto 0);    
    s_axi_rlast        : in    std_logic;     
    s_axi_rvalid       : in    std_logic;
    s_axi_rready       : out   std_logic; 
    -- Test interface
    tdi                : in  std_logic;
    tdo                : out std_logic;
    tms                : in  std_logic;
    tclk               : in  std_logic;
    -- Pad configuratio
    pad_cfg            : out std_logic_vector(ESP_CSR_PAD_CFG_MSB - ESP_CSR_PAD_CFG_LSB downto 0);
    -- NOC
    noc1_data_n_in     : in  coh_noc_flit_type;
    noc1_data_s_in     : in  coh_noc_flit_type;
    noc1_data_w_in     : in  coh_noc_flit_type;
    noc1_data_e_in     : in  coh_noc_flit_type;
    noc1_data_void_in  : in  std_logic_vector(3 downto 0);
    noc1_stop_in       : in  std_logic_vector(3 downto 0);
    noc1_data_n_out    : out coh_noc_flit_type;
    noc1_data_s_out    : out coh_noc_flit_type;
    noc1_data_w_out    : out coh_noc_flit_type;
    noc1_data_e_out    : out coh_noc_flit_type;
    noc1_data_void_out : out std_logic_vector(3 downto 0);
    noc1_stop_out      : out std_logic_vector(3 downto 0);
    noc2_data_n_in     : in  coh_noc_flit_type;
    noc2_data_s_in     : in  coh_noc_flit_type;
    noc2_data_w_in     : in  coh_noc_flit_type;
    noc2_data_e_in     : in  coh_noc_flit_type;
    noc2_data_void_in  : in  std_logic_vector(3 downto 0);
    noc2_stop_in       : in  std_logic_vector(3 downto 0);
    noc2_data_n_out    : out coh_noc_flit_type;
    noc2_data_s_out    : out coh_noc_flit_type;
    noc2_data_w_out    : out coh_noc_flit_type;
    noc2_data_e_out    : out coh_noc_flit_type;
    noc2_data_void_out : out std_logic_vector(3 downto 0);
    noc2_stop_out      : out std_logic_vector(3 downto 0);
    noc3_data_n_in     : in  coh_noc_flit_type;
    noc3_data_s_in     : in  coh_noc_flit_type;
    noc3_data_w_in     : in  coh_noc_flit_type;
    noc3_data_e_in     : in  coh_noc_flit_type;
    noc3_data_void_in  : in  std_logic_vector(3 downto 0);
    noc3_stop_in       : in  std_logic_vector(3 downto 0);
    noc3_data_n_out    : out coh_noc_flit_type;
    noc3_data_s_out    : out coh_noc_flit_type;
    noc3_data_w_out    : out coh_noc_flit_type;
    noc3_data_e_out    : out coh_noc_flit_type;
    noc3_data_void_out : out std_logic_vector(3 downto 0);
    noc3_stop_out      : out std_logic_vector(3 downto 0);
    noc4_data_n_in     : in  dma_noc_flit_type;
    noc4_data_s_in     : in  dma_noc_flit_type;
    noc4_data_w_in     : in  dma_noc_flit_type;
    noc4_data_e_in     : in  dma_noc_flit_type;
    noc4_data_void_in  : in  std_logic_vector(3 downto 0);
    noc4_stop_in       : in  std_logic_vector(3 downto 0);
    noc4_data_n_out    : out dma_noc_flit_type;
    noc4_data_s_out    : out dma_noc_flit_type;
    noc4_data_w_out    : out dma_noc_flit_type;
    noc4_data_e_out    : out dma_noc_flit_type;
    noc4_data_void_out : out std_logic_vector(3 downto 0);
    noc4_stop_out      : out std_logic_vector(3 downto 0);
    noc5_data_n_in     : in  misc_noc_flit_type;
    noc5_data_s_in     : in  misc_noc_flit_type;
    noc5_data_w_in     : in  misc_noc_flit_type;
    noc5_data_e_in     : in  misc_noc_flit_type;
    noc5_data_void_in  : in  std_logic_vector(3 downto 0);
    noc5_stop_in       : in  std_logic_vector(3 downto 0);
    noc5_data_n_out    : out misc_noc_flit_type;
    noc5_data_s_out    : out misc_noc_flit_type;
    noc5_data_w_out    : out misc_noc_flit_type;
    noc5_data_e_out    : out misc_noc_flit_type;
    noc5_data_void_out : out std_logic_vector(3 downto 0);
    noc5_stop_out      : out std_logic_vector(3 downto 0);
    noc6_data_n_in     : in  dma_noc_flit_type;
    noc6_data_s_in     : in  dma_noc_flit_type;
    noc6_data_w_in     : in  dma_noc_flit_type;
    noc6_data_e_in     : in  dma_noc_flit_type;
    noc6_data_void_in  : in  std_logic_vector(3 downto 0);
    noc6_stop_in       : in  std_logic_vector(3 downto 0);
    noc6_data_n_out    : out dma_noc_flit_type;
    noc6_data_s_out    : out dma_noc_flit_type;
    noc6_data_w_out    : out dma_noc_flit_type;
    noc6_data_e_out    : out dma_noc_flit_type;
    noc6_data_void_out : out std_logic_vector(3 downto 0);
    noc6_stop_out      : out std_logic_vector(3 downto 0));
end;


architecture rtl of asic_tile_mem is

  -- Tile clock and reset (only for I/O tile)
  signal raw_rstn     : std_ulogic;
  signal noc_rstn     : std_ulogic;
  signal tile_rstn    : std_ulogic;
  signal tile_rst     : std_ulogic;
  signal tile_clk     : std_ulogic;

  -- DCO config
  signal dco_en            : std_ulogic;
  signal dco_clk_sel       : std_ulogic;
  signal dco_cc_sel        : std_logic_vector(5 downto 0);
  signal dco_fc_sel        : std_logic_vector(5 downto 0);
  signal dco_div_sel       : std_logic_vector(2 downto 0);
  signal dco_freq_sel      : std_logic_vector(1 downto 0);
  signal dco_clk_delay_sel : std_logic_vector(11 downto 0);

  -- Tile parameters
  signal tile_config : std_logic_vector(ESP_NOC_CSR_WIDTH - 1 downto 0);

  -- Tile NoC interface
  signal test_rstn             : std_ulogic;
  signal test1_output_port_s   : coh_noc_flit_type;
  signal test1_data_void_out_s : std_ulogic;
  signal test1_stop_in_s       : std_ulogic;
  signal test2_output_port_s   : coh_noc_flit_type;
  signal test2_data_void_out_s : std_ulogic;
  signal test2_stop_in_s       : std_ulogic;
  signal test3_output_port_s   : coh_noc_flit_type;
  signal test3_data_void_out_s : std_ulogic;
  signal test3_stop_in_s       : std_ulogic;
  signal test4_output_port_s   : dma_noc_flit_type;
  signal test4_data_void_out_s : std_ulogic;
  signal test4_stop_in_s       : std_ulogic;
  signal test5_output_port_s   : misc_noc_flit_type;
  signal test5_data_void_out_s : std_ulogic;
  signal test5_stop_in_s       : std_ulogic;
  signal test6_output_port_s   : dma_noc_flit_type;
  signal test6_data_void_out_s : std_ulogic;
  signal test6_stop_in_s       : std_ulogic;
  signal test1_input_port_s    : coh_noc_flit_type;
  signal test1_data_void_in_s  : std_ulogic;
  signal test1_stop_out_s      : std_ulogic;
  signal test2_input_port_s    : coh_noc_flit_type;
  signal test2_data_void_in_s  : std_ulogic;
  signal test2_stop_out_s      : std_ulogic;
  signal test3_input_port_s    : coh_noc_flit_type;
  signal test3_data_void_in_s  : std_ulogic;
  signal test3_stop_out_s      : std_ulogic;
  signal test4_input_port_s    : dma_noc_flit_type;
  signal test4_data_void_in_s  : std_ulogic;
  signal test4_stop_out_s      : std_ulogic;
  signal test5_input_port_s    : misc_noc_flit_type;
  signal test5_data_void_in_s  : std_ulogic;
  signal test5_stop_out_s      : std_ulogic;
  signal test6_input_port_s    : dma_noc_flit_type;
  signal test6_data_void_in_s  : std_ulogic;
  signal test6_stop_out_s      : std_ulogic;

  -- Noc interface
  signal noc1_stop_in_tile       : std_ulogic;
  signal noc1_stop_out_tile      : std_ulogic;
  signal noc1_data_void_in_tile  : std_ulogic;
  signal noc1_data_void_out_tile : std_ulogic;
  signal noc2_stop_in_tile       : std_ulogic;
  signal noc2_stop_out_tile      : std_ulogic;
  signal noc2_data_void_in_tile  : std_ulogic;
  signal noc2_data_void_out_tile : std_ulogic;
  signal noc3_stop_in_tile       : std_ulogic;
  signal noc3_stop_out_tile      : std_ulogic;
  signal noc3_data_void_in_tile  : std_ulogic;
  signal noc3_data_void_out_tile : std_ulogic;
  signal noc4_stop_in_tile       : std_ulogic;
  signal noc4_stop_out_tile      : std_ulogic;
  signal noc4_data_void_in_tile  : std_ulogic;
  signal noc4_data_void_out_tile : std_ulogic;
  signal noc5_stop_in_tile       : std_ulogic;
  signal noc5_stop_out_tile      : std_ulogic;
  signal noc5_data_void_in_tile  : std_ulogic;
  signal noc5_data_void_out_tile : std_ulogic;
  signal noc6_stop_in_tile       : std_ulogic;
  signal noc6_stop_out_tile      : std_ulogic;
  signal noc6_data_void_in_tile  : std_ulogic;
  signal noc6_data_void_out_tile : std_ulogic;
  signal noc1_input_port_tile    : coh_noc_flit_type;
  signal noc2_input_port_tile    : coh_noc_flit_type;
  signal noc3_input_port_tile    : coh_noc_flit_type;
  signal noc4_input_port_tile    : dma_noc_flit_type;
  signal noc5_input_port_tile    : misc_noc_flit_type;
  signal noc6_input_port_tile    : dma_noc_flit_type;
  signal noc1_output_port_tile   : coh_noc_flit_type;
  signal noc2_output_port_tile   : coh_noc_flit_type;
  signal noc3_output_port_tile   : coh_noc_flit_type;
  signal noc4_output_port_tile   : dma_noc_flit_type;
  signal noc5_output_port_tile   : misc_noc_flit_type;
  signal noc6_output_port_tile   : dma_noc_flit_type;

  -- NoC monitors
   signal mon_noc : monitor_noc_vector(1 to 6);

begin

  rst_noc : rstgen
    generic map (acthigh => 1, syncin => 0)
    port map (rst, noc_clk, noc_clk_lock, noc_rstn, raw_rstn);

  rst_jtag : rstgen
    generic map (acthigh => 1, syncin => 0)
    port map (rst, tclk, '1', test_rstn, open);

  has_dco_rst : if this_has_dco = 1 generate
    tile_rst <= rst;
  end generate has_dco_rst;

  no_dco_rst : if this_has_dco /= 1 generate
    tile_rst <= noc_rstn;
  end generate no_dco_rst;

  -----------------------------------------------------------------------------
  -- JTAG for single tile testing / bypass when test_if_en = 0
  -----------------------------------------------------------------------------
  jtag_test_i : jtag_test
    generic map (
      test_if_en => CFG_JTAG_EN)
    port map (
      rstn                => test_rstn,
      clk                 => tile_clk,
      tile_rstn           => tile_rstn,
      tdi                 => tdi,
      tdo                 => tdo,
      tms                 => tms,
      tclk                => tclk,
      noc1_output_port    => noc1_output_port_tile,
      noc1_data_void_out  => noc1_data_void_out_tile,
      noc1_stop_in        => noc1_stop_in_tile,
      noc2_output_port    => noc2_output_port_tile,
      noc2_data_void_out  => noc2_data_void_out_tile,
      noc2_stop_in        => noc2_stop_in_tile,
      noc3_output_port    => noc3_output_port_tile,
      noc3_data_void_out  => noc3_data_void_out_tile,
      noc3_stop_in        => noc3_stop_in_tile,
      noc4_output_port    => noc4_output_port_tile,
      noc4_data_void_out  => noc4_data_void_out_tile,
      noc4_stop_in        => noc4_stop_in_tile,
      noc5_output_port    => noc5_output_port_tile,
      noc5_data_void_out  => noc5_data_void_out_tile,
      noc5_stop_in        => noc5_stop_in_tile,
      noc6_output_port    => noc6_output_port_tile,
      noc6_data_void_out  => noc6_data_void_out_tile,
      noc6_stop_in        => noc6_stop_in_tile,
      test1_output_port   => test1_output_port_s,
      test1_data_void_out => test1_data_void_out_s,
      test1_stop_in       => test1_stop_in_s,
      test2_output_port   => test2_output_port_s,
      test2_data_void_out => test2_data_void_out_s,
      test2_stop_in       => test2_stop_in_s,
      test3_output_port   => test3_output_port_s,
      test3_data_void_out => test3_data_void_out_s,
      test3_stop_in       => test3_stop_in_s,
      test4_output_port   => test4_output_port_s,
      test4_data_void_out => test4_data_void_out_s,
      test4_stop_in       => test4_stop_in_s,
      test5_output_port   => test5_output_port_s,
      test5_data_void_out => test5_data_void_out_s,
      test5_stop_in       => test5_stop_in_s,
      test6_output_port   => test6_output_port_s,
      test6_data_void_out => test6_data_void_out_s,
      test6_stop_in       => test6_stop_in_s,
      test1_input_port    => test1_input_port_s,
      test1_data_void_in  => test1_data_void_in_s,
      test1_stop_out      => test1_stop_out_s,
      test2_input_port    => test2_input_port_s,
      test2_data_void_in  => test2_data_void_in_s,
      test2_stop_out      => test2_stop_out_s,
      test3_input_port    => test3_input_port_s,
      test3_data_void_in  => test3_data_void_in_s,
      test3_stop_out      => test3_stop_out_s,
      test4_input_port    => test4_input_port_s,
      test4_data_void_in  => test4_data_void_in_s,
      test4_stop_out      => test4_stop_out_s,
      test5_input_port    => test5_input_port_s,
      test5_data_void_in  => test5_data_void_in_s,
      test5_stop_out      => test5_stop_out_s,
      test6_input_port    => test6_input_port_s,
      test6_data_void_in  => test6_data_void_in_s,
      test6_stop_out      => test6_stop_out_s,
      noc1_input_port     => noc1_input_port_tile,
      noc1_data_void_in   => noc1_data_void_in_tile,
      noc1_stop_out       => noc1_stop_out_tile,
      noc2_input_port     => noc2_input_port_tile,
      noc2_data_void_in   => noc2_data_void_in_tile,
      noc2_stop_out       => noc2_stop_out_tile,
      noc3_input_port     => noc3_input_port_tile,
      noc3_data_void_in   => noc3_data_void_in_tile,
      noc3_stop_out       => noc3_stop_out_tile,
      noc4_input_port     => noc4_input_port_tile,
      noc4_data_void_in   => noc4_data_void_in_tile,
      noc4_stop_out       => noc4_stop_out_tile,
      noc5_input_port     => noc5_input_port_tile,
      noc5_data_void_in   => noc5_data_void_in_tile,
      noc5_stop_out       => noc5_stop_out_tile,
      noc6_input_port     => noc6_input_port_tile,
      noc6_data_void_in   => noc6_data_void_in_tile,
      noc6_stop_out       => noc6_stop_out_tile);

  tile_mem_1 : tile_mem
    generic map (
      SIMULATION   => SIMULATION,
      this_has_dco => this_has_dco,
      this_has_ddr => 0)
    port map (
      raw_rstn            => raw_rstn,
      tile_rst            => tile_rst,
      ext_clk             => ext_clk,
      clk_div             => clk_div,
      tile_clk_out        => tile_clk,
      dco_clk_div2        => open,
      dco_clk_div2_90     => open,
      tile_rstn_out       => tile_rstn,
      phy_rstn            => open,
      dco_freq_sel        => dco_freq_sel,
      dco_div_sel         => dco_div_sel,
      dco_fc_sel          => dco_fc_sel,
      dco_cc_sel          => dco_cc_sel,
      dco_clk_sel         => dco_clk_sel,
      dco_en              => dco_en,
      dco_clk_delay_sel   => dco_clk_delay_sel,
      s_axi_awid 	  => s_axi_awid,
      s_axi_awaddr 	  => s_axi_awaddr,
      s_axi_awlen 	  => s_axi_awlen,
      s_axi_awsize 	  => s_axi_awsize,
      s_axi_awburst 	  => s_axi_awburst,
      s_axi_awlock 	  => s_axi_awlock,
      s_axi_awcache 	  => s_axi_awcache,
      s_axi_awprot 	  => s_axi_awprot,
      s_axi_awvalid 	  => s_axi_awvalid,
      s_axi_awready 	  => s_axi_awready,
      s_axi_wdata 	  => s_axi_wdata,
      s_axi_wstrb 	  => s_axi_wstrb,
      s_axi_wlast 	  => s_axi_wlast,
      s_axi_wvalid 	  => s_axi_wvalid,
      s_axi_wready 	  => s_axi_wready,
      s_axi_bid 	  => s_axi_bid,
      s_axi_bresp 	  => s_axi_bresp,
      s_axi_bvalid 	  => s_axi_bvalid,
      s_axi_bready 	  => s_axi_bready,
      s_axi_arid 	  => s_axi_arid,
      s_axi_araddr 	  => s_axi_araddr,
      s_axi_arlen 	  => s_axi_arlen,
      s_axi_arsize 	  => s_axi_arsize,
      s_axi_arburst 	  => s_axi_arburst,
      s_axi_arlock 	  => s_axi_arlock,
      s_axi_arcache 	  => s_axi_arcache,
      s_axi_arprot 	  => s_axi_arprot,
      s_axi_arvalid 	  => s_axi_arvalid,
      s_axi_arready 	  => s_axi_arready,
      s_axi_rid 	  => s_axi_rid,
      s_axi_rdata 	  => s_axi_rdata,
      s_axi_rresp 	  => s_axi_rresp,
      s_axi_rlast 	  => s_axi_rlast,       
      s_axi_rvalid 	  => s_axi_rvalid,     
      s_axi_rready 	  => s_axi_rready,   
      fpga_data_in        => fpga_data_in,
      fpga_data_out       => fpga_data_out,
      fpga_oen            => fpga_oen,
      fpga_valid_in       => fpga_valid_in,
      fpga_valid_out      => fpga_valid_out,
      fpga_clk_in         => fpga_clk_in,
      fpga_clk_out        => fpga_clk_out,
      fpga_credit_in      => fpga_credit_in,
      fpga_credit_out     => fpga_credit_out,
      test1_output_port   => test1_output_port_s,
      test1_data_void_out => test1_data_void_out_s,
      test1_stop_in       => test1_stop_out_s,
      test1_input_port    => test1_input_port_s,
      test1_data_void_in  => test1_data_void_in_s,
      test1_stop_out      => test1_stop_in_s,
      test2_output_port   => test2_output_port_s,
      test2_data_void_out => test2_data_void_out_s,
      test2_stop_in       => test2_stop_out_s,
      test2_input_port    => test2_input_port_s,
      test2_data_void_in  => test2_data_void_in_s,
      test2_stop_out      => test2_stop_in_s,
      test3_output_port   => test3_output_port_s,
      test3_data_void_out => test3_data_void_out_s,
      test3_stop_in       => test3_stop_out_s,
      test3_input_port    => test3_input_port_s,
      test3_data_void_in  => test3_data_void_in_s,
      test3_stop_out      => test3_stop_in_s,
      test4_output_port   => test4_output_port_s,
      test4_data_void_out => test4_data_void_out_s,
      test4_stop_in       => test4_stop_out_s,
      test4_input_port    => test4_input_port_s,
      test4_data_void_in  => test4_data_void_in_s,
      test4_stop_out      => test4_stop_in_s,
      test5_output_port   => test5_output_port_s,
      test5_data_void_out => test5_data_void_out_s,
      test5_stop_in       => test5_stop_out_s,
      test5_input_port    => test5_input_port_s,
      test5_data_void_in  => test5_data_void_in_s,
      test5_stop_out      => test5_stop_in_s,
      test6_output_port   => test6_output_port_s,
      test6_data_void_out => test6_data_void_out_s,
      test6_stop_in       => test6_stop_out_s,
      test6_input_port    => test6_input_port_s,
      test6_data_void_in  => test6_data_void_in_s,
      test6_stop_out      => test6_stop_in_s,
      mon_noc             => mon_noc,
      mon_mem             => open,
      mon_cache           => open,
      mon_dvfs            => open);

  noc_domain_socket_i : noc_domain_socket
    generic map (
      this_has_token_pm => 0,
      is_tile_io        => false,
      SIMULATION        => SIMULATION,
      ROUTER_PORTS      => ROUTER_PORTS,
      HAS_SYNC          => 1)
    port map (
      raw_rstn                => raw_rstn,
      noc_rstn                => noc_rstn,
      tile_rstn               => tile_rstn,
      noc_clk                 => noc_clk,
      tile_clk                => tile_clk,
      acc_clk                 => open,
      -- CSRs
      tile_config             => open,
      -- DCO config
      dco_freq_sel            => dco_freq_sel,
      dco_div_sel             => dco_div_sel,
      dco_fc_sel              => dco_fc_sel,
      dco_cc_sel              => dco_cc_sel,
      dco_clk_sel             => dco_clk_sel,
      dco_en                  => dco_en,
      dco_clk_delay_sel       => dco_clk_delay_sel,
      -- pad config
      pad_cfg                 => pad_cfg,
      -- NoC
      noc1_data_n_in          => noc1_data_n_in,
      noc1_data_s_in          => noc1_data_s_in,
      noc1_data_w_in          => noc1_data_w_in,
      noc1_data_e_in          => noc1_data_e_in,
      noc1_data_void_in       => noc1_data_void_in,
      noc1_stop_in            => noc1_stop_in,
      noc1_data_n_out         => noc1_data_n_out,
      noc1_data_s_out         => noc1_data_s_out,
      noc1_data_w_out         => noc1_data_w_out,
      noc1_data_e_out         => noc1_data_e_out,
      noc1_data_void_out      => noc1_data_void_out,
      noc1_stop_out           => noc1_stop_out,
      noc2_data_n_in          => noc2_data_n_in,
      noc2_data_s_in          => noc2_data_s_in,
      noc2_data_w_in          => noc2_data_w_in,
      noc2_data_e_in          => noc2_data_e_in,
      noc2_data_void_in       => noc2_data_void_in,
      noc2_stop_in            => noc2_stop_in,
      noc2_data_n_out         => noc2_data_n_out,
      noc2_data_s_out         => noc2_data_s_out,
      noc2_data_w_out         => noc2_data_w_out,
      noc2_data_e_out         => noc2_data_e_out,
      noc2_data_void_out      => noc2_data_void_out,
      noc2_stop_out           => noc2_stop_out,
      noc3_data_n_in          => noc3_data_n_in,
      noc3_data_s_in          => noc3_data_s_in,
      noc3_data_w_in          => noc3_data_w_in,
      noc3_data_e_in          => noc3_data_e_in,
      noc3_data_void_in       => noc3_data_void_in,
      noc3_stop_in            => noc3_stop_in,
      noc3_data_n_out         => noc3_data_n_out,
      noc3_data_s_out         => noc3_data_s_out,
      noc3_data_w_out         => noc3_data_w_out,
      noc3_data_e_out         => noc3_data_e_out,
      noc3_data_void_out      => noc3_data_void_out,
      noc3_stop_out           => noc3_stop_out,
      noc4_data_n_in          => noc4_data_n_in,
      noc4_data_s_in          => noc4_data_s_in,
      noc4_data_w_in          => noc4_data_w_in,
      noc4_data_e_in          => noc4_data_e_in,
      noc4_data_void_in       => noc4_data_void_in,
      noc4_stop_in            => noc4_stop_in,
      noc4_data_n_out         => noc4_data_n_out,
      noc4_data_s_out         => noc4_data_s_out,
      noc4_data_w_out         => noc4_data_w_out,
      noc4_data_e_out         => noc4_data_e_out,
      noc4_data_void_out      => noc4_data_void_out,
      noc4_stop_out           => noc4_stop_out,
      noc5_data_n_in          => noc5_data_n_in,
      noc5_data_s_in          => noc5_data_s_in,
      noc5_data_w_in          => noc5_data_w_in,
      noc5_data_e_in          => noc5_data_e_in,
      noc5_data_void_in       => noc5_data_void_in,
      noc5_stop_in            => noc5_stop_in,
      noc5_data_n_out         => noc5_data_n_out,
      noc5_data_s_out         => noc5_data_s_out,
      noc5_data_w_out         => noc5_data_w_out,
      noc5_data_e_out         => noc5_data_e_out,
      noc5_data_void_out      => noc5_data_void_out,
      noc5_stop_out           => noc5_stop_out,
      noc6_data_n_in          => noc6_data_n_in,
      noc6_data_s_in          => noc6_data_s_in,
      noc6_data_w_in          => noc6_data_w_in,
      noc6_data_e_in          => noc6_data_e_in,
      noc6_data_void_in       => noc6_data_void_in,
      noc6_stop_in            => noc6_stop_in,
      noc6_data_n_out         => noc6_data_n_out,
      noc6_data_s_out         => noc6_data_s_out,
      noc6_data_w_out         => noc6_data_w_out,
      noc6_data_e_out         => noc6_data_e_out,
      noc6_data_void_out      => noc6_data_void_out,
      noc6_stop_out           => noc6_stop_out,
      -- monitors
      mon_noc                 => mon_noc,
	  acc_activity            => '0',

      -- synchronizers out to tile
      noc1_output_port_tile   => noc1_output_port_tile,
      noc1_data_void_out_tile => noc1_data_void_out_tile,
      noc1_stop_in_tile       => noc1_stop_in_tile,
      noc2_output_port_tile   => noc2_output_port_tile,
      noc2_data_void_out_tile => noc2_data_void_out_tile,
      noc2_stop_in_tile       => noc2_stop_in_tile,
      noc3_output_port_tile   => noc3_output_port_tile,
      noc3_data_void_out_tile => noc3_data_void_out_tile,
      noc3_stop_in_tile       => noc3_stop_in_tile,
      noc4_output_port_tile   => noc4_output_port_tile,
      noc4_data_void_out_tile => noc4_data_void_out_tile,
      noc4_stop_in_tile       => noc4_stop_in_tile,
      noc5_output_port_tile   => noc5_output_port_tile,
      noc5_data_void_out_tile => noc5_data_void_out_tile,
      noc5_stop_in_tile       => noc5_stop_in_tile,
      noc6_output_port_tile   => noc6_output_port_tile,
      noc6_data_void_out_tile => noc6_data_void_out_tile,
      noc6_stop_in_tile       => noc6_stop_in_tile,
      -- tile to synchronizers in
      noc1_input_port_tile    => noc1_input_port_tile,
      noc1_data_void_in_tile  => noc1_data_void_in_tile,
      noc1_stop_out_tile      => noc1_stop_out_tile,
      noc2_input_port_tile    => noc2_input_port_tile,
      noc2_data_void_in_tile  => noc2_data_void_in_tile,
      noc2_stop_out_tile      => noc2_stop_out_tile,
      noc3_input_port_tile    => noc3_input_port_tile,
      noc3_data_void_in_tile  => noc3_data_void_in_tile,
      noc3_stop_out_tile      => noc3_stop_out_tile,
      noc4_input_port_tile    => noc4_input_port_tile,
      noc4_data_void_in_tile  => noc4_data_void_in_tile,
      noc4_stop_out_tile      => noc4_stop_out_tile,
      noc5_input_port_tile    => noc5_input_port_tile,
      noc5_data_void_in_tile  => noc5_data_void_in_tile,
      noc5_stop_out_tile      => noc5_stop_out_tile,
      noc6_input_port_tile    => noc6_input_port_tile,
      noc6_data_void_in_tile  => noc6_data_void_in_tile,
      noc6_stop_out_tile      => noc6_stop_out_tile);

end;
