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
-- pragma translate_off
use work.sim.all;
library unisim;
use unisim.all;
-- pragma translate_on
use work.monitor_pkg.all;
use work.esp_csr_pkg.all;
use work.misc.all;
use work.jtag_pkg.all;
use work.sldacc.all;
use work.nocpackage.all;
use work.tile.all;
use work.cachepackage.all;
use work.coretypes.all;

use work.grlib_config.all;
use work.socmap.all;

entity tile_mem is
  generic (
    SIMULATION   : boolean := false;
    this_has_dco : integer range 0 to 2 := 0;
    this_has_ddr : integer range 0 to 1 := 1);
  port (
    raw_rstn           : in  std_ulogic;
    tile_rst           : in  std_ulogic;
    ext_clk            : in  std_ulogic;
    clk_div            : out std_ulogic;
    tile_clk_out       : out std_ulogic;
    -- DCO config
    dco_freq_sel       : in std_logic_vector(1 downto 0);
    dco_div_sel        : in std_logic_vector(2 downto 0);
    dco_fc_sel         : in std_logic_vector(5 downto 0);
    dco_cc_sel         : in std_logic_vector(5 downto 0);
    dco_clk_sel        : in std_ulogic;
    dco_en             : in std_ulogic;  
    dco_clk_delay_sel  : in std_logic_vector(11 downto 0);
    dco_clk_div2       : out std_ulogic;
    dco_clk_div2_90    : out std_ulogic;
    tile_rstn_out          : out std_ulogic;
    phy_rstn           : out std_ulogic;
    ddr_axi_si         : out   axi_mosi_type;
    ddr_axi_so         : in    axi_somi_type;
	-- FPGA proxy memory link (this_has_ddr -> 0)
    fpga_data_in       : in  std_logic_vector(CFG_MEM_LINK_BITS - 1 downto 0);
    fpga_data_out      : out std_logic_vector(CFG_MEM_LINK_BITS - 1 downto 0);
    fpga_oen           : out std_ulogic;
    fpga_valid_in      : in  std_ulogic;
    fpga_valid_out     : out std_ulogic;
    fpga_clk_in        : in  std_ulogic;
    fpga_clk_out       : out std_ulogic;
    fpga_credit_in     : in  std_ulogic;
    fpga_credit_out    : out std_ulogic;
    -- NOC
    test1_output_port   : in coh_noc_flit_type;
    test1_data_void_out : in std_ulogic;
    test1_stop_in       : in std_ulogic;
    test2_output_port   : in coh_noc_flit_type;
    test2_data_void_out : in std_ulogic;
    test2_stop_in       : in std_ulogic;
    test3_output_port   : in coh_noc_flit_type;
    test3_data_void_out : in std_ulogic;
    test3_stop_in       : in std_ulogic;
    test4_output_port   : in dma_noc_flit_type;
    test4_data_void_out : in std_ulogic;
    test4_stop_in       : in std_ulogic;
    test5_output_port   : in misc_noc_flit_type;
    test5_data_void_out : in std_ulogic;
    test5_stop_in       : in std_ulogic;
    test6_output_port   : in dma_noc_flit_type;
    test6_data_void_out : in std_ulogic;
    test6_stop_in       : in std_ulogic;
    test1_input_port    : out coh_noc_flit_type;
    test1_data_void_in  : out std_ulogic;
    test1_stop_out      : out std_ulogic;
    test2_input_port    : out coh_noc_flit_type;
    test2_data_void_in  : out std_ulogic;
    test2_stop_out      : out std_ulogic;
    test3_input_port    : out coh_noc_flit_type;
    test3_data_void_in  : out std_ulogic;
    test3_stop_out      : out std_ulogic;
    test4_input_port    : out dma_noc_flit_type;
    test4_data_void_in  : out std_ulogic;
    test4_stop_out      : out std_ulogic;
    test5_input_port    : out misc_noc_flit_type;
    test5_data_void_in  : out std_ulogic;
    test5_stop_out      : out std_ulogic;
    test6_input_port    : out dma_noc_flit_type;
    test6_data_void_in  : out std_ulogic;
    test6_stop_out      : out std_ulogic;
    mon_noc             : in  monitor_noc_vector(1 to 6);
    mon_mem             : out monitor_mem_type;
    mon_cache           : out monitor_cache_type;
    mon_dvfs            : out monitor_dvfs_type);
end;


architecture rtl of tile_mem is

  -- Tile synchronous reset
  signal rst : std_ulogic;

  -- DCO
  signal dco_clk_lock : std_ulogic;
  signal dco_clk      : std_ulogic;
  signal tile_clk     : std_ulogic;
  signal dco_en_int   : std_ulogic;

  -- Delay line for DDR ui_clk delay
  signal dco_clk_div2_int    : std_logic;
  signal dco_clk_div2_90_int : std_logic;
  component DELAY_CELL_ASIC is
    port (
      data_in : in std_logic;
      sel     : in std_Logic_vector(3 downto 0);
      data_out : out std_logic);
  end component DELAY_CELL_ASIC;

  -- LLC
  signal llc_rstn : std_ulogic;

  -- Queues
  signal coherence_req_rdreq        : std_ulogic;
  signal coherence_req_data_out     : coh_noc_flit_type;
  signal coherence_req_empty        : std_ulogic;
  signal coherence_fwd_wrreq        : std_ulogic;
  signal coherence_fwd_data_in      : coh_noc_flit_type;
  signal coherence_fwd_full         : std_ulogic;
  signal coherence_rsp_snd_wrreq    : std_ulogic;
  signal coherence_rsp_snd_data_in  : coh_noc_flit_type;
  signal coherence_rsp_snd_full     : std_ulogic;
  signal coherence_rsp_rcv_rdreq    : std_ulogic;
  signal coherence_rsp_rcv_data_out : coh_noc_flit_type;
  signal coherence_rsp_rcv_empty    : std_ulogic;
  signal dma_rcv_rdreq              : std_ulogic;
  signal dma_rcv_data_out           : dma_noc_flit_type;
  signal dma_rcv_empty              : std_ulogic;
  signal dma_snd_wrreq              : std_ulogic;
  signal dma_snd_data_in            : dma_noc_flit_type;
  signal dma_snd_full               : std_ulogic;
  signal dma_snd_atleast_4slots     : std_ulogic;
  signal dma_snd_exactly_3slots     : std_ulogic;
  signal coherent_dma_rcv_rdreq     : std_ulogic;
  signal coherent_dma_rcv_data_out  : dma_noc_flit_type;
  signal coherent_dma_rcv_empty     : std_ulogic;
  signal coherent_dma_snd_wrreq     : std_ulogic;
  signal coherent_dma_snd_data_in   : dma_noc_flit_type;
  signal coherent_dma_snd_full      : std_ulogic;
  signal coherent_dma_snd_atleast_4slots : std_ulogic;
  signal coherent_dma_snd_exactly_3slots : std_ulogic;
  -- These requests are delivered through NoC5 (32 bits always)
  -- however, the proxy that handles expects a flit size in
  -- accordance with CFG_MEM_LINK_BITS. Hence we need to pad and move
  -- header info and preamble to the right bit position
  signal remote_ahbs_rcv_rdreq      : std_ulogic;
  signal remote_ahbs_rcv_data_out   : misc_noc_flit_type;
  signal remote_ahbs_rcv_empty      : std_ulogic;
  signal remote_ahbs_snd_wrreq      : std_ulogic;
  signal remote_ahbs_snd_data_in    : misc_noc_flit_type;
  signal remote_ahbs_snd_full       : std_ulogic;
  -- Extended remote_ahbs_* signals that
  signal remote_ahbm_rcv_rdreq      : std_ulogic;
  signal remote_ahbm_rcv_data_out   : arch_noc_flit_type;
  signal remote_ahbm_rcv_empty      : std_ulogic;
  signal remote_ahbm_snd_wrreq      : std_ulogic;
  signal remote_ahbm_snd_data_in    : arch_noc_flit_type;
  signal remote_ahbm_snd_full       : std_ulogic;
  --
  signal apb_rcv_rdreq              : std_ulogic;
  signal apb_rcv_data_out           : misc_noc_flit_type;
  signal apb_rcv_empty              : std_ulogic;
  signal apb_snd_wrreq              : std_ulogic;
  signal apb_snd_data_in            : misc_noc_flit_type;
  signal apb_snd_full               : std_ulogic;

  -- LLC/FPGA-based memory link
  signal llc_ext_req_ready : std_ulogic;
  signal llc_ext_req_valid : std_ulogic;
  signal llc_ext_req_data  : std_logic_vector(CFG_MEM_LINK_BITS - 1 downto 0);
  signal llc_ext_rsp_ready : std_ulogic;
  signal llc_ext_rsp_valid : std_ulogic;
  signal llc_ext_rsp_data  : std_logic_vector(CFG_MEM_LINK_BITS - 1 downto 0);


  -- Bus
  signal ahbsi : ahb_slv_in_type;
  signal ahbso : ahb_slv_out_vector;
  signal apbi  : apb_slv_in_type;
  signal apbo  : apb_slv_out_vector;

  -- Mon
  signal mon_mem_int    : monitor_mem_type;
  signal mon_cache_int  : monitor_cache_type;
  signal mon_dvfs_int   : monitor_dvfs_type;
  signal mon_ddr        : monitor_ddr_type;

  -- Soft reset
  signal srst : std_ulogic;

  -- Tile parameters
  signal tile_config : std_logic_vector(ESP_CSR_WIDTH - 1 downto 0);

  signal tile_id : integer range 0 to CFG_TILES_NUM - 1;

  signal this_mem_id       : integer range 0 to MEM_ID_RANGE_MSB;
  signal this_ddr_hindex   : integer range 0 to NAHBSLV - 1;
  signal this_ddr_hconfig  : ahb_config_type;

  signal this_llc_pindex   : integer range 0 to NAPBSLV - 1;
  signal this_llc_pconfig  : apb_config_type;

  signal this_csr_pindex   : integer range 0 to NAPBSLV - 1;
  signal this_csr_pconfig  : apb_config_type;

  signal this_local_y      : local_yx;
  signal this_local_x      : local_yx;

  -- AXI Crossbar Signals
  signal mst0_aw_id       : std_logic_vector(1 downto 0);
  signal mst0_aw_addr     : std_logic_vector(GLOB_PHYS_ADDR_BITS-1 downto 0);
  signal mst0_aw_len      : std_logic_vector(7 downto 0);
  signal mst0_aw_size     : std_logic_vector(2 downto 0);
  signal mst0_aw_burst    : std_logic_vector(1 downto 0);
  signal mst0_aw_lock     : std_logic;
  signal mst0_aw_cache    : std_logic_vector(3 downto 0);
  signal mst0_aw_prot     : std_logic_vector(2 downto 0);
  signal mst0_aw_qos      : std_logic_vector(3 downto 0);
  signal mst0_aw_atop     : std_logic_vector(5 downto 0);
  signal mst0_aw_region   : std_logic_vector(3 downto 0);
  signal mst0_aw_user     : std_logic_vector(3 downto 0);
  signal mst0_aw_valid    : std_logic;
  signal mst0_aw_ready    : std_logic;
  signal mst0_w_data      : std_logic_vector(AXIDW-1 downto 0);
  signal mst0_w_strb      : std_logic_vector(AW-1 downto 0);
  signal mst0_w_last      : std_logic;
  signal mst0_w_user      : std_logic_vector(3 downto 0);
  signal mst0_w_valid     : std_logic;
  signal mst0_w_ready     : std_logic;
  signal mst0_b_id        : std_logic_vector(1 downto 0);
  signal mst0_b_resp      : std_logic_vector(1 downto 0);
  signal mst0_b_user      : std_logic_vector(3 downto 0);
  signal mst0_b_valid     : std_logic;
  signal mst0_b_ready     : std_logic;
  signal mst0_ar_id       : std_logic_vector(1 downto 0);
  signal mst0_ar_addr     : std_logic_vector(GLOB_PHYS_ADDR_BITS-1 downto 0);
  signal mst0_ar_len      : std_logic_vector(7 downto 0);
  signal mst0_ar_size     : std_logic_vector(2 downto 0);
  signal mst0_ar_burst    : std_logic_vector(1 downto 0);
  signal mst0_ar_lock     : std_logic;
  signal mst0_ar_cache    : std_logic_vector(3 downto 0);
  signal mst0_ar_prot     : std_logic_vector(2 downto 0);
  signal mst0_ar_qos      : std_logic_vector(3 downto 0);
  signal mst0_ar_region   : std_logic_vector(3 downto 0);
  signal mst0_ar_user     : std_logic_vector(3 downto 0);
  signal mst0_ar_valid    : std_logic;
  signal mst0_ar_ready    : std_logic;
  signal mst0_r_id        : std_logic_vector(1 downto 0);
  signal mst0_r_data      : std_logic_vector(AXIDW-1 downto 0);
  signal mst0_r_resp      : std_logic_vector(1 downto 0);
  signal mst0_r_last      : std_logic;
  signal mst0_r_user      : std_logic_vector(3 downto 0);
  signal mst0_r_valid     : std_logic;
  signal mst0_r_ready     : std_logic;

  signal mst1_aw_id       : std_logic_vector(1 downto 0);
  signal mst1_aw_addr     : std_logic_vector(GLOB_PHYS_ADDR_BITS-1 downto 0);
  signal mst1_aw_len      : std_logic_vector(7 downto 0);
  signal mst1_aw_size     : std_logic_vector(2 downto 0);
  signal mst1_aw_burst    : std_logic_vector(1 downto 0);
  signal mst1_aw_lock     : std_logic;
  signal mst1_aw_cache    : std_logic_vector(3 downto 0);
  signal mst1_aw_prot     : std_logic_vector(2 downto 0);
  signal mst1_aw_qos      : std_logic_vector(3 downto 0);
  signal mst1_aw_atop     : std_logic_vector(5 downto 0);
  signal mst1_aw_region   : std_logic_vector(3 downto 0);
  signal mst1_aw_user     : std_logic_vector(3 downto 0);
  signal mst1_aw_valid    : std_logic;
  signal mst1_aw_ready    : std_logic;
  signal mst1_w_data      : std_logic_vector(AXIDW-1 downto 0);
  signal mst1_w_strb      : std_logic_vector(AW-1 downto 0);
  signal mst1_w_last      : std_logic;
  signal mst1_w_user      : std_logic_vector(3 downto 0);
  signal mst1_w_valid     : std_logic;
  signal mst1_w_ready     : std_logic;
  signal mst1_b_id        : std_logic_vector(1 downto 0);
  signal mst1_b_resp      : std_logic_vector(1 downto 0);
  signal mst1_b_user      : std_logic_vector(3 downto 0);
  signal mst1_b_valid     : std_logic;
  signal mst1_b_ready     : std_logic;
  signal mst1_ar_id       : std_logic_vector(1 downto 0);
  signal mst1_ar_addr     : std_logic_vector(GLOB_PHYS_ADDR_BITS-1 downto 0);
  signal mst1_ar_len      : std_logic_vector(7 downto 0);
  signal mst1_ar_size     : std_logic_vector(2 downto 0);
  signal mst1_ar_burst    : std_logic_vector(1 downto 0);
  signal mst1_ar_lock     : std_logic;
  signal mst1_ar_cache    : std_logic_vector(3 downto 0);
  signal mst1_ar_prot     : std_logic_vector(2 downto 0);
  signal mst1_ar_qos      : std_logic_vector(3 downto 0);
  signal mst1_ar_region   : std_logic_vector(3 downto 0);
  signal mst1_ar_user     : std_logic_vector(3 downto 0);
  signal mst1_ar_valid    : std_logic;
  signal mst1_ar_ready    : std_logic;
  signal mst1_r_id        : std_logic_vector(1 downto 0);
  signal mst1_r_data      : std_logic_vector(AXIDW-1 downto 0);
  signal mst1_r_resp      : std_logic_vector(1 downto 0);
  signal mst1_r_last      : std_logic;
  signal mst1_r_user      : std_logic_vector(3 downto 0);
  signal mst1_r_valid     : std_logic;
  signal mst1_r_ready     : std_logic;

  signal mst2_aw_id       : std_logic_vector(1 downto 0);
  signal mst2_aw_addr     : std_logic_vector(GLOB_PHYS_ADDR_BITS-1 downto 0);
  signal mst2_aw_len      : std_logic_vector(7 downto 0);
  signal mst2_aw_size     : std_logic_vector(2 downto 0);
  signal mst2_aw_burst    : std_logic_vector(1 downto 0);
  signal mst2_aw_lock     : std_logic;
  signal mst2_aw_cache    : std_logic_vector(3 downto 0);
  signal mst2_aw_prot     : std_logic_vector(2 downto 0);
  signal mst2_aw_qos      : std_logic_vector(3 downto 0);
  signal mst2_aw_atop     : std_logic_vector(5 downto 0);
  signal mst2_aw_region   : std_logic_vector(3 downto 0);
  signal mst2_aw_user     : std_logic_vector(3 downto 0);
  signal mst2_aw_valid    : std_logic;
  signal mst2_aw_ready    : std_logic;
  signal mst2_w_data      : std_logic_vector(AXIDW-1 downto 0);
  signal mst2_w_strb      : std_logic_vector(AW-1 downto 0);
  signal mst2_w_last      : std_logic;
  signal mst2_w_user      : std_logic_vector(3 downto 0);
  signal mst2_w_valid     : std_logic;
  signal mst2_w_ready     : std_logic;
  signal mst2_b_id        : std_logic_vector(1 downto 0);
  signal mst2_b_resp      : std_logic_vector(1 downto 0);
  signal mst2_b_user      : std_logic_vector(3 downto 0);
  signal mst2_b_valid     : std_logic;
  signal mst2_b_ready     : std_logic;
  signal mst2_ar_id       : std_logic_vector(1 downto 0);
  signal mst2_ar_addr     : std_logic_vector(GLOB_PHYS_ADDR_BITS-1 downto 0);
  signal mst2_ar_len      : std_logic_vector(7 downto 0);
  signal mst2_ar_size     : std_logic_vector(2 downto 0);
  signal mst2_ar_burst    : std_logic_vector(1 downto 0);
  signal mst2_ar_lock     : std_logic;
  signal mst2_ar_cache    : std_logic_vector(3 downto 0);
  signal mst2_ar_prot     : std_logic_vector(2 downto 0);
  signal mst2_ar_qos      : std_logic_vector(3 downto 0);
  signal mst2_ar_region   : std_logic_vector(3 downto 0);
  signal mst2_ar_user     : std_logic_vector(3 downto 0);
  signal mst2_ar_valid    : std_logic;
  signal mst2_ar_ready    : std_logic;
  signal mst2_r_id        : std_logic_vector(1 downto 0);
  signal mst2_r_data      : std_logic_vector(AXIDW-1 downto 0);
  signal mst2_r_resp      : std_logic_vector(1 downto 0);
  signal mst2_r_last      : std_logic;
  signal mst2_r_user      : std_logic_vector(3 downto 0);
  signal mst2_r_valid     : std_logic;
  signal mst2_r_ready     : std_logic;

  signal rom_aw_id        : std_logic_vector(3 downto 0);
  signal rom_aw_addr      : std_logic_vector(GLOB_PHYS_ADDR_BITS-1 downto 0);
  signal rom_aw_len       : std_logic_vector(7 downto 0);
  signal rom_aw_size      : std_logic_vector(2 downto 0);
  signal rom_aw_burst     : std_logic_vector(1 downto 0);
  signal rom_aw_lock      : std_logic;
  signal rom_aw_cache     : std_logic_vector(3 downto 0);
  signal rom_aw_prot      : std_logic_vector(2 downto 0);
  signal rom_aw_qos       : std_logic_vector(3 downto 0);
  signal rom_aw_atop      : std_logic_vector(5 downto 0);
  signal rom_aw_region    : std_logic_vector(3 downto 0);
  signal rom_aw_user      : std_logic_vector(3 downto 0);
  signal rom_aw_valid     : std_logic;
  signal rom_aw_ready     : std_logic;
  signal rom_w_data       : std_logic_vector(AXIDW-1 downto 0);
  signal rom_w_strb       : std_logic_vector(AW-1 downto 0);
  signal rom_w_last       : std_logic;
  signal rom_w_user       : std_logic_vector(3 downto 0);
  signal rom_w_valid      : std_logic;
  signal rom_w_ready      : std_logic;
  signal rom_b_id         : std_logic_vector(3 downto 0);
  signal rom_b_resp       : std_logic_vector(1 downto 0);
  signal rom_b_user       : std_logic_vector(3 downto 0);
  signal rom_b_valid      : std_logic;
  signal rom_b_ready      : std_logic;
  signal rom_ar_id        : std_logic_vector(3 downto 0);
  signal rom_ar_addr      : std_logic_vector(GLOB_PHYS_ADDR_BITS-1 downto 0);
  signal rom_ar_len       : std_logic_vector(7 downto 0);
  signal rom_ar_size      : std_logic_vector(2 downto 0);
  signal rom_ar_burst     : std_logic_vector(1 downto 0);
  signal rom_ar_lock      : std_logic;
  signal rom_ar_cache     : std_logic_vector(3 downto 0);
  signal rom_ar_prot      : std_logic_vector(2 downto 0);
  signal rom_ar_qos       : std_logic_vector(3 downto 0);
  signal rom_ar_region    : std_logic_vector(3 downto 0);
  signal rom_ar_user      : std_logic_vector(3 downto 0);
  signal rom_ar_valid     : std_logic;
  signal rom_ar_ready     : std_logic;
  signal rom_r_id         : std_logic_vector(3 downto 0);
  signal rom_r_data       : std_logic_vector(AXIDW-1 downto 0);
  signal rom_r_resp       : std_logic_vector(1 downto 0);
  signal rom_r_last       : std_logic;
  signal rom_r_user       : std_logic_vector(3 downto 0);
  signal rom_r_valid      : std_logic;
  signal rom_r_ready      : std_logic;

  signal dram_aw_qos      : std_logic_vector(3 downto 0);
  signal dram_aw_atop     : std_logic_vector(5 downto 0);
  signal dram_aw_region   : std_logic_vector(3 downto 0);
  signal dram_aw_user     : std_logic_vector(3 downto 0);
  signal dram_w_user      : std_logic_vector(3 downto 0);
  signal dram_b_user      : std_logic_vector(3 downto 0);
  signal dram_ar_qos      : std_logic_vector(3 downto 0);
  signal dram_ar_region   : std_logic_vector(3 downto 0);
  signal dram_ar_user     : std_logic_vector(3 downto 0);
  signal dram_r_user      : std_logic_vector(3 downto 0);

  constant this_local_apb_en : std_logic_vector(0 to NAPBSLV - 1) := (
    0 => '1',                           -- CSRs
    1 => to_std_logic(CFG_LLC_ENABLE),  -- last-level cache
    others => '0');

  constant this_local_ahb_en : std_logic_vector(0 to NAHBSLV - 1) := (
    0      => '1',  -- memory
    others => '0');

  attribute keep              : string;
  attribute mark_debug : string;
  attribute mark_debug of remote_ahbm_rcv_rdreq  : signal is "true";
  attribute mark_debug of remote_ahbm_rcv_data_out : signal is "true";
  attribute mark_debug of remote_ahbm_rcv_empty : signal is "true";
  attribute mark_debug of remote_ahbm_snd_wrreq : signal is "true"; 
  attribute mark_debug of remote_ahbm_snd_data_in : signal is "true"; 
  attribute mark_debug of remote_ahbm_snd_full : signal is "true";
  
  attribute mark_debug of  mst0_aw_id       : signal is "true";
  attribute mark_debug of  mst0_aw_addr     : signal is "true";
  attribute mark_debug of  mst0_aw_len      : signal is "true";
  attribute mark_debug of  mst0_aw_size     : signal is "true";
  attribute mark_debug of  mst0_aw_burst    : signal is "true";
  attribute mark_debug of  mst0_aw_lock     : signal is "true";
  attribute mark_debug of  mst0_aw_cache    : signal is "true";
  attribute mark_debug of  mst0_aw_prot     : signal is "true";
  attribute mark_debug of  mst0_aw_qos      : signal is "true";
  attribute mark_debug of  mst0_aw_atop     : signal is "true";
  attribute mark_debug of  mst0_aw_region   : signal is "true";
  attribute mark_debug of  mst0_aw_user     : signal is "true";
  attribute mark_debug of  mst0_aw_valid    : signal is "true";
  attribute mark_debug of  mst0_aw_ready    : signal is "true";
  attribute mark_debug of  mst0_w_data      : signal is "true";
  attribute mark_debug of  mst0_w_strb      : signal is "true";
  attribute mark_debug of  mst0_w_last      : signal is "true";
  attribute mark_debug of  mst0_w_user      : signal is "true";
  attribute mark_debug of  mst0_w_valid     : signal is "true";
  attribute mark_debug of mst0_w_ready     : signal is "true";

  attribute mark_debug of  mst1_aw_id       : signal is "true";
  attribute mark_debug of  mst1_aw_addr     : signal is "true";
  attribute mark_debug of  mst1_aw_len      : signal is "true";
  attribute mark_debug of  mst1_aw_size     : signal is "true";
  attribute mark_debug of  mst1_aw_burst    : signal is "true";
  attribute mark_debug of  mst1_aw_lock     : signal is "true";
  attribute mark_debug of  mst1_aw_cache    : signal is "true";
  attribute mark_debug of  mst1_aw_prot     : signal is "true";
  attribute mark_debug of  mst1_aw_qos      : signal is "true";
  attribute mark_debug of  mst1_aw_atop     : signal is "true";
  attribute mark_debug of  mst1_aw_region   : signal is "true";
  attribute mark_debug of  mst1_aw_user     : signal is "true";
  attribute mark_debug of  mst1_aw_valid    : signal is "true";
  attribute mark_debug of  mst1_aw_ready    : signal is "true";
  attribute mark_debug of  mst1_w_data      : signal is "true";
  attribute mark_debug of  mst1_w_strb      : signal is "true";
  attribute mark_debug of  mst1_w_last      : signal is "true";
  attribute mark_debug of  mst1_w_user      : signal is "true";
  attribute mark_debug of  mst1_w_valid     : signal is "true";
  attribute mark_debug of mst1_w_ready     : signal is "true";
  
  attribute mark_debug of  mst2_aw_id       : signal is "true";
  attribute mark_debug of  mst2_aw_addr     : signal is "true";
  attribute mark_debug of  mst2_aw_len      : signal is "true";
  attribute mark_debug of  mst2_aw_size     : signal is "true";
  attribute mark_debug of  mst2_aw_burst    : signal is "true";
  attribute mark_debug of  mst2_aw_lock     : signal is "true";
  attribute mark_debug of  mst2_aw_cache    : signal is "true";
  attribute mark_debug of  mst2_aw_prot     : signal is "true";
  attribute mark_debug of  mst2_aw_qos      : signal is "true";
  attribute mark_debug of  mst2_aw_atop     : signal is "true";
  attribute mark_debug of  mst2_aw_region   : signal is "true";
  attribute mark_debug of  mst2_aw_user     : signal is "true";
  attribute mark_debug of  mst2_aw_valid    : signal is "true";
  attribute mark_debug of  mst2_aw_ready    : signal is "true";
  attribute mark_debug of  mst2_w_data      : signal is "true";
  attribute mark_debug of  mst2_w_strb      : signal is "true";
  attribute mark_debug of  mst2_w_last      : signal is "true";
  attribute mark_debug of  mst2_w_user      : signal is "true";
  attribute mark_debug of  mst2_w_valid     : signal is "true";
  attribute mark_debug of  mst2_w_ready     : signal is "true";
  
  attribute mark_debug of coherence_req_rdreq        : signal is "true"; 
  attribute mark_debug of coherence_req_data_out     : signal is "true"; 
  attribute mark_debug of coherence_req_empty        : signal is "true"; 
  attribute mark_debug of coherence_fwd_wrreq        : signal is "true"; 
  attribute mark_debug of coherence_fwd_data_in      : signal is "true"; 
  attribute mark_debug of coherence_fwd_full         : signal is "true"; 
  attribute mark_debug of coherence_rsp_snd_wrreq    : signal is "true"; 
  attribute mark_debug of coherence_rsp_snd_data_in  : signal is "true"; 
  attribute mark_debug of coherence_rsp_snd_full     : signal is "true"; 
  attribute mark_debug of coherence_rsp_rcv_rdreq    : signal is "true"; 
  attribute mark_debug of coherence_rsp_rcv_data_out : signal is "true";
  attribute mark_debug of coherence_rsp_rcv_empty    : signal is "true"; 

  attribute mark_debug of dma_rcv_rdreq           : signal is "true"; 
  attribute mark_debug of dma_rcv_data_out        : signal is "true"; 
  attribute mark_debug of dma_rcv_empty           : signal is "true"; 
  attribute mark_debug of dma_snd_wrreq           : signal is "true"; 
  attribute mark_debug of dma_snd_data_in         : signal is "true"; 
  attribute mark_debug of dma_snd_full            : signal is "true"; 
  attribute mark_debug of dma_snd_atleast_4slots  : signal is "true"; 
  attribute mark_debug of dma_snd_exactly_3slots  : signal is "true"; 

begin

  -- DCO Reset synchronizer
  rst_gen: if this_has_dco = 1 generate
    rst_ddr: if this_has_ddr /= 0 generate
      tile_rstn_out : rstgen
        generic map (acthigh => 1, syncin => 0)
        port map (tile_rst, dco_clk_div2_90_int, dco_clk_lock, rst, open);

      -- DDR PHY reset
      ddr_rstn : rstgen
        generic map (acthigh => 1, syncin => 0)
        port map (tile_rst, dco_clk_div2_int, dco_clk_lock, phy_rstn, open);
    end generate rst_ddr;

    rst_mem: if this_has_ddr = 0 generate
      tile_rstn_out : rstgen
        generic map (acthigh => 1, syncin => 0)
        port map (tile_rst, dco_clk, dco_clk_lock, rst, open);
      phy_rstn <= rst;
    end generate rst_mem;

  end generate rst_gen;

  no_rst_gen: if this_has_dco /= 1 generate
    rst <= tile_rst;
    phy_rstn <= tile_rst;
  end generate no_rst_gen;

  tile_rstn_out <= rst;

  -- DCO
  dco_en_int <= dco_en and raw_rstn;
  dco_gen: if this_has_dco = 1 generate

    dco_i: dco
      generic map (
        tech => CFG_FABTECH,
        enable_div2 => this_has_ddr,
        dlog => 9)                      -- come out of reset after NoC, but
                                        -- before tile_io.
      port map (
        rstn     => raw_rstn,
        ext_clk  => ext_clk,
        en       => dco_en_int,
        clk_sel  => dco_clk_sel,
        cc_sel   => dco_cc_sel,
        fc_sel   => dco_fc_sel,
        div_sel  => dco_div_sel,
        freq_sel => dco_freq_sel,
        clk      => dco_clk,
        clk_div2 => dco_clk_div2_int,
        clk_div2_90 => open,
        clk_div  => clk_div,
        lock     => dco_clk_lock);


    clk_delay_asic_gen: if CFG_FABTECH = asic and this_has_ddr /= 0 generate
      DELAY_CELL_ASIC_1: DELAY_CELL_ASIC
        port map (
          data_in  => dco_clk_div2_int,
          sel      => dco_clk_delay_sel(3 downto 0),
          data_out => dco_clk_div2_90_int);

      tile_clk <= dco_clk_div2_90_int;
    end generate clk_delay_asic_gen;

    noc_clk_delay_gen: if this_has_ddr = 0 generate
      dco_clk_div2_90_int <= dco_clk_div2_int;
      tile_clk <= dco_clk;
    end generate noc_clk_delay_gen;

  end generate dco_gen;

  no_dco_gen: if this_has_dco /= 1 generate
    clk_div             <= ext_clk;
    tile_clk            <= ext_clk;
    dco_clk_lock        <= '1';
    dco_clk_div2_int    <= '0';
    dco_clk_div2_90_int <= '0';
  end generate no_dco_gen;

  dco_clk_div2    <= dco_clk_div2_int;
  dco_clk_div2_90 <= dco_clk_div2_90_int;
  tile_clk_out    <= tile_clk;

  -----------------------------------------------------------------------------
  -- Tile parameters
  -----------------------------------------------------------------------------
  tile_id           <= to_integer(unsigned(tile_config(ESP_CSR_TILE_ID_MSB downto ESP_CSR_TILE_ID_LSB)));

  this_mem_id       <= tile_mem_id(tile_id);
  this_ddr_hindex   <= ddr_hindex(this_mem_id);
  this_ddr_hconfig  <= fixed_ahbso_hconfig(this_ddr_hindex);

  this_llc_pindex   <= llc_cache_pindex(tile_id);
  this_llc_pconfig  <= fixed_apbo_pconfig(this_llc_pindex);

  this_csr_pindex   <= tile_csr_pindex(tile_id);
  this_csr_pconfig  <= fixed_apbo_pconfig(this_csr_pindex);

  this_local_y      <= tile_y(tile_id);
  this_local_x      <= tile_x(tile_id);

  -----------------------------------------------------------------------------
  -- Bus
  -----------------------------------------------------------------------------

  axi_crossbar_gen: if this_has_ddr /= 0 generate
  -- instantiate the bus if using on-chip DDR controller
  axi2 : crossbar_wrap                       -- AXICrossbar
    generic map (
      NMST 		=> 3,
      NSLV 		=> 2,
      AXI_ID_WIDTH 	=>  2,
      AXI_ID_WIDTH_SLV 	=>  4,
      AXI_ADDR_WIDTH 	=> GLOB_PHYS_ADDR_BITS,
      AXI_DATA_WIDTH 	=> AXIDW,
      AXI_USER_WIDTH 	=>  4,
      AXI_STRB_WIDTH 	=> AW,
      ROMBase 		=> X"0000_0000",
      ROMLength 	=> X"0000_1000",
      DRAMBase 		=> DRAM_BASE,
      DRAMLength 	=> X"4000_0000"
    )
    port map (
      clk 		=> tile_clk,
      rstn 		=> rst,
      mst0_aw_id 	=> mst0_aw_id,
      mst0_aw_addr 	=> mst0_aw_addr,
      mst0_aw_len 	=> mst0_aw_len,
      mst0_aw_size 	=> mst0_aw_size,
      mst0_aw_burst 	=> mst0_aw_burst,
      mst0_aw_lock 	=> mst0_aw_lock,
      mst0_aw_cache 	=> (others => '0'),
      mst0_aw_prot 	=> mst0_aw_prot,
      mst0_aw_qos 	=> (others => '0'),
      mst0_aw_atop 	=> (others => '0'),
      mst0_aw_region 	=> (others => '0'),
      mst0_aw_user 	=> (others => '0'),
      mst0_aw_valid 	=> mst0_aw_valid,
      mst0_aw_ready 	=> mst0_aw_ready,
      mst0_w_data 	=> mst0_w_data,
      mst0_w_strb 	=> mst0_w_strb,
      mst0_w_last 	=> mst0_w_last,
      mst0_w_user 	=> (others => '0'),
      mst0_w_valid 	=> mst0_w_valid,
      mst0_w_ready 	=> mst0_w_ready,
      mst0_b_id 	=> mst0_b_id,
      mst0_b_resp 	=> mst0_b_resp,
      mst0_b_user 	=> mst0_b_user,
      mst0_b_valid 	=> mst0_b_valid,
      mst0_b_ready 	=> mst0_b_ready,
      mst0_ar_id 	=> mst0_ar_id,
      mst0_ar_addr 	=> mst0_ar_addr,
      mst0_ar_len 	=> mst0_ar_len,
      mst0_ar_size 	=> mst0_ar_size,
      mst0_ar_burst 	=> mst0_ar_burst,
      mst0_ar_lock 	=> mst0_ar_lock,
      mst0_ar_cache 	=> (others => '0'),
      mst0_ar_prot 	=> mst0_ar_prot,
      mst0_ar_qos 	=> (others => '0'),
      mst0_ar_region 	=> (others => '0'),
      mst0_ar_user 	=> (others => '0'),
      mst0_ar_valid 	=> mst0_ar_valid,
      mst0_ar_ready 	=> mst0_ar_ready,
      mst0_r_id 	=> mst0_r_id,
      mst0_r_data 	=> mst0_r_data,
      mst0_r_resp 	=> mst0_r_resp,
      mst0_r_last 	=> mst0_r_last,
      mst0_r_user 	=> mst0_r_user,
      mst0_r_valid	=> mst0_r_valid,
      mst0_r_ready 	=> mst0_r_ready,

      mst1_aw_id 	=> mst1_aw_id,
      mst1_aw_addr 	=> mst1_aw_addr,
      mst1_aw_len 	=> mst1_aw_len,
      mst1_aw_size 	=> mst1_aw_size,
      mst1_aw_burst => mst1_aw_burst,
      mst1_aw_lock 	=> mst1_aw_lock,
      mst1_aw_cache => (others => '0'),
      mst1_aw_prot 	=> mst1_aw_prot,
      mst1_aw_qos 	=> (others => '0'),
      mst1_aw_atop 	=> (others => '0'),
      mst1_aw_region => (others => '0'),
      mst1_aw_user 	=> (others => '0'),
      mst1_aw_valid	=> mst1_aw_valid,
      mst1_aw_ready => mst1_aw_ready,
      mst1_w_data 	=> mst1_w_data,
      mst1_w_strb 	=> mst1_w_strb,
      mst1_w_last 	=> mst1_w_last,
      mst1_w_user 	=> (others => '0'),
      mst1_w_valid 	=> mst1_w_valid,
      mst1_w_ready 	=> mst1_w_ready,
      mst1_b_id 	=> mst1_b_id,
      mst1_b_resp 	=> mst1_b_resp,
      mst1_b_user 	=> mst1_b_user,
      mst1_b_valid 	=> mst1_b_valid,
      mst1_b_ready 	=> mst1_b_ready,
      mst1_ar_id	=> mst1_ar_id,
      mst1_ar_addr 	=> mst1_ar_addr,
      mst1_ar_len 	=> mst1_ar_len,
      mst1_ar_size 	=> mst1_ar_size,
      mst1_ar_burst	=> mst1_ar_burst,
      mst1_ar_lock 	=> mst1_ar_lock,
      mst1_ar_cache	=> (others => '0'),
      mst1_ar_prot 	=> mst1_ar_prot,
      mst1_ar_qos 	=> (others => '0'),
      mst1_ar_region => (others => '0'),
      mst1_ar_user 	=> (others => '0'),
      mst1_ar_valid => mst1_ar_valid,
      mst1_ar_ready => mst1_ar_ready,
      mst1_r_id 	=> mst1_r_id,
      mst1_r_data 	=> mst1_r_data,
      mst1_r_resp 	=> mst1_r_resp,
      mst1_r_last 	=> mst1_r_last,
      mst1_r_user 	=> mst1_r_user,
      mst1_r_valid 	=> mst1_r_valid,
      mst1_r_ready 	=> mst1_r_ready,

      mst2_aw_id 	=> mst2_aw_id,
      mst2_aw_addr 	=> mst2_aw_addr,
      mst2_aw_len 	=> mst2_aw_len,
      mst2_aw_size 	=> mst2_aw_size,
      mst2_aw_burst => mst2_aw_burst,
      mst2_aw_lock 	=> mst2_aw_lock,
      mst2_aw_cache => (others => '0'),
      mst2_aw_prot 	=> mst2_aw_prot,
      mst2_aw_qos 	=> (others => '0'),
      mst2_aw_atop 	=> (others => '0'),
      mst2_aw_region => (others => '0'),
      mst2_aw_user 	=> (others => '0'),
      mst2_aw_valid	=> mst2_aw_valid,
      mst2_aw_ready => mst2_aw_ready,
      mst2_w_data 	=> mst2_w_data,
      mst2_w_strb 	=> mst2_w_strb,
      mst2_w_last 	=> mst2_w_last,
      mst2_w_user 	=> (others => '0'),
      mst2_w_valid 	=> mst2_w_valid,
      mst2_w_ready 	=> mst2_w_ready,
      mst2_b_id 	=> mst2_b_id,
      mst2_b_resp 	=> mst2_b_resp,
      mst2_b_user 	=> mst2_b_user,
      mst2_b_valid 	=> mst2_b_valid,
      mst2_b_ready 	=> mst2_b_ready,
      mst2_ar_id	=> mst2_ar_id,
      mst2_ar_addr 	=> mst2_ar_addr,
      mst2_ar_len 	=> mst2_ar_len,
      mst2_ar_size 	=> mst2_ar_size,
      mst2_ar_burst => mst2_ar_burst,
      mst2_ar_lock 	=> mst2_ar_lock,
      mst2_ar_cache => (others => '0'),
      mst2_ar_prot 	=> mst2_ar_prot,
      mst2_ar_qos 	=> (others => '0'),
      mst2_ar_region => (others => '0'),
      mst2_ar_user 	=> (others => '0'),
      mst2_ar_valid => mst2_ar_valid,
      mst2_ar_ready => mst2_ar_ready,
      mst2_r_id 	=> mst2_r_id,
      mst2_r_data 	=> mst2_r_data,
      mst2_r_resp 	=> mst2_r_resp,
      mst2_r_last 	=> mst2_r_last,
      mst2_r_user 	=> mst2_r_user,
      mst2_r_valid 	=> mst2_r_valid,
      mst2_r_ready 	=> mst2_r_ready,


      rom_aw_id 	=> rom_aw_id,
      rom_aw_addr 	=> rom_aw_addr,
      rom_aw_len 	=> rom_aw_len,
      rom_aw_size 	=> rom_aw_size,
      rom_aw_burst 	=> rom_aw_burst,
      rom_aw_lock 	=> rom_aw_lock,
      rom_aw_cache 	=> rom_aw_cache,
      rom_aw_prot 	=> rom_aw_prot,
      rom_aw_qos 	=> rom_aw_qos,
      rom_aw_atop 	=> rom_aw_atop,
      rom_aw_region 	=> rom_aw_region,
      rom_aw_user 	=> rom_aw_user,
      rom_aw_valid 	=> rom_aw_valid,
      rom_aw_ready 	=> '0',
      rom_w_data 	=> rom_w_data,
      rom_w_strb 	=> rom_w_strb,
      rom_w_last 	=> rom_w_last,
      rom_w_user 	=> rom_w_user,
      rom_w_valid 	=> rom_w_valid,
      rom_w_ready 	=> '0',
      rom_b_id 		=> (others => '0'),
      rom_b_resp 	=> (others => '0'),
      rom_b_user 	=> (others => '0'),
      rom_b_valid 	=> '0',
      rom_b_ready 	=> rom_b_ready,
      rom_ar_id 	=> rom_ar_id,
      rom_ar_addr 	=> rom_ar_addr,
      rom_ar_len 	=> rom_ar_len,
      rom_ar_size 	=> rom_ar_size,
      rom_ar_burst 	=> rom_ar_burst,
      rom_ar_lock 	=> rom_ar_lock,
      rom_ar_cache 	=> rom_ar_cache,
      rom_ar_prot 	=> rom_ar_prot,
      rom_ar_qos 	=> rom_ar_qos,
      rom_ar_region 	=> rom_ar_region,
      rom_ar_user 	=> rom_ar_user,
      rom_ar_valid 	=> rom_ar_valid,
      rom_ar_ready 	=> '0',
      rom_r_id 		=> (others => '0'),
      rom_r_data 	=> (others => '0'),
      rom_r_resp 	=> (others => '0'),
      rom_r_last 	=> '0',
      rom_r_user 	=> (others => '0'),
      rom_r_valid 	=> '0',
      rom_r_ready 	=> rom_r_ready,

      dram_aw_id 	=> ddr_axi_si.aw.id(3 downto 0),
      dram_aw_addr 	=> ddr_axi_si.aw.addr,
      dram_aw_len 	=> ddr_axi_si.aw.len,
      dram_aw_size 	=> ddr_axi_si.aw.size,
      dram_aw_burst => ddr_axi_si.aw.burst,
      dram_aw_lock 	=> ddr_axi_si.aw.lock,
      dram_aw_cache => ddr_axi_si.aw.cache,
      dram_aw_prot 	=> ddr_axi_si.aw.prot,
      dram_aw_qos 	=> ddr_axi_si.aw.qos,
      dram_aw_atop 	=> ddr_axi_si.aw.atop,
      dram_aw_region => ddr_axi_si.aw.region,
      dram_aw_user 	 => ddr_axi_si.aw.user(3 downto 0),
      dram_aw_valid	=> ddr_axi_si.aw.valid,
      dram_aw_ready	=> ddr_axi_so.aw.ready,
      dram_w_data 	=> ddr_axi_si.w.data,
      dram_w_strb 	=> ddr_axi_si.w.strb,
      dram_w_last 	=> ddr_axi_si.w.last,
      dram_w_user 	=> ddr_axi_si.w.user(3 downto 0),
      dram_w_valid 	=> ddr_axi_si.w.valid,
      dram_w_ready 	=> ddr_axi_so.w.ready,
      dram_b_id 	=> ddr_axi_so.b.id(3 downto 0),
      dram_b_resp 	=> ddr_axi_so.b.resp,
      dram_b_user 	=> dram_b_user,
      
	  dram_b_valid 	=> ddr_axi_so.b.valid,
      dram_b_ready 	=> ddr_axi_si.b.ready,
      dram_ar_id 	=> ddr_axi_si.ar.id(3 downto 0),
      dram_ar_addr 	=> ddr_axi_si.ar.addr,
      dram_ar_len 	=> ddr_axi_si.ar.len,
      dram_ar_size 	=> ddr_axi_si.ar.size,
      dram_ar_burst	=> ddr_axi_si.ar.burst,
      dram_ar_lock 	=> ddr_axi_si.ar.lock,
      dram_ar_cache => ddr_axi_si.ar.cache,
      dram_ar_prot 	=> ddr_axi_si.ar.prot,
      dram_ar_qos 	=> ddr_axi_si.ar.qos,
      dram_ar_region => ddr_axi_si.ar.region,
      dram_ar_user 	=> ddr_axi_si.ar.user(3 downto 0),
      dram_ar_valid	=> ddr_axi_si.ar.valid,
      dram_ar_ready => ddr_axi_so.ar.ready,
      dram_r_id 	=> ddr_axi_so.r.id(3 downto 0),
      dram_r_data 	=> ddr_axi_so.r.data,
      dram_r_resp 	=> ddr_axi_so.r.resp,
      dram_r_last 	=> ddr_axi_so.r.last,
      dram_r_user 	=> dram_r_user,
      dram_r_valid 	=> ddr_axi_so.r.valid,
      dram_r_ready 	=> ddr_axi_si.r.ready
    );
  end generate axi_crossbar_gen;

  -----------------------------------------------------------------------
  ---  Drive unused bus ports
  -----------------------------------------------------------------------
  no_pslv_gen : for i in 0 to NAPBSLV - 1 generate
    no_pslv_i_gen : if this_local_apb_en(i) = '0' generate
      apbo(i) <= apb_none;
    end generate no_pslv_i_gen;
  end generate no_pslv_gen;

  -----------------------------------------------------------------------------
  -- Services
  -----------------------------------------------------------------------------

  -- DVFS monitor
  mon_dvfs_int.vf        <= "1000";         --run at highest frequency always
  mon_dvfs_int.transient <= '0';
  mon_dvfs_int.clk       <= tile_clk;
  mon_dvfs_int.acc_idle  <= '0';
  mon_dvfs_int.traffic   <= '0';
  mon_dvfs_int.burst     <= '0';

  mon_dvfs <= mon_dvfs_int;

  -- Memory access monitor
  mon_mem_int.clk              <= tile_clk;
  mon_mem_int.coherent_req     <= coherence_req_rdreq;
  mon_mem_int.coherent_fwd     <= coherence_fwd_wrreq;
  mon_mem_int.coherent_rsp_rcv <= coherence_rsp_rcv_rdreq;
  mon_mem_int.coherent_rsp_snd <= coherence_rsp_snd_wrreq;
  mon_mem_int.dma_req          <= dma_rcv_rdreq;
  mon_mem_int.dma_rsp          <= dma_snd_wrreq;
  mon_mem_int.coherent_dma_req <= coherent_dma_rcv_rdreq;
  mon_mem_int.coherent_dma_rsp <= coherent_dma_snd_wrreq;

  mon_mem <= mon_mem_int;

  mon_cache <= mon_cache_int;

  mon_ddr.clk <= tile_clk;
  detect_ddr_access : process(ahbsi)
  begin
    if this_has_ddr = 1 then
      mon_ddr.word_transfer <= '0';
--      if ahbsi.hready =  '1' and ahbsi.htrans /= HTRANS_IDLE then
--        mon_ddr.word_transfer <= '1';
--      end if;
    else
      -- TODO: connect to FPGA link activity
      mon_ddr.word_transfer <= '0';
    end if;
  end process detect_ddr_access;

  --Memory mapped registers
  mem_tile_csr : esp_tile_csr
    generic map(
      pindex      => 0)
    port map(
      clk => tile_clk,
      rstn => rst,
      pconfig => this_csr_pconfig,
      mon_ddr => mon_ddr,
      mon_mem => mon_mem_int,
      mon_noc => mon_noc,
      mon_l2 => monitor_cache_none,
      mon_llc => mon_cache_int,
      mon_acc => monitor_acc_none,
      mon_dvfs => mon_dvfs_int,
      tile_config => tile_config,
      srst => srst,
      tp_acc_rst => open,
      apbi => apbi,
      apbo => apbo(0)
    );

  -----------------------------------------------------------------------------
  -- Proxies
  -----------------------------------------------------------------------------

  -- FROM NoC
  no_cache_coherence : if CFG_LLC_ENABLE = 0 generate
    -- Handle CPU coherent requests and accelerator non-coherent DMA
    noc2aximst_1 : noc2aximst
      generic map (
        tech        		=> CFG_FABTECH,
        mst_index   		=> 0,
        axitran     		=> GLOB_CPU_AXI,
        little_end  		=> GLOB_CPU_RISCV,
        eth_dma     		=> 0,
        narrow_noc  		=> 0,
        cacheline   		=> CFG_DLINE,	
		this_coh_flit_size  => COH_NOC_FLIT_SIZE)
      port map (
        ACLK  		=> tile_clk,
        ARESETn 	=> rst,
        local_y 	=> this_local_y,
        local_x 	=> this_local_x,
        --AR Channel
        AR_ID 		=> mst0_ar_id,
        AR_ADDR 	=> mst0_ar_addr,
        AR_LEN 		=> mst0_ar_len,
        AR_SIZE 	=> mst0_ar_size,
        AR_BURST 	=> mst0_ar_burst,
        AR_LOCK 	=> mst0_ar_lock,
        AR_PROT 	=> mst0_ar_prot,
        AR_VALID 	=> mst0_ar_valid,
        AR_READY 	=> mst0_ar_ready,
        --R Channel
        R_ID    	=> mst0_r_id,
        R_DATA  	=> mst0_r_data,
        R_RESP  	=> mst0_r_resp,
        R_LAST  	=> mst0_r_last,
        R_VALID 	=> mst0_r_valid,
        R_READY 	=> mst0_r_ready,
        --AW Channel
        AW_ID 		=> mst0_aw_id,
        AW_ADDR 	=> mst0_aw_addr,
        AW_LEN 		=> mst0_aw_len,
        AW_SIZE 	=> mst0_aw_size,
        AW_BURST 	=> mst0_aw_burst,
        AW_LOCK 	=> mst0_aw_lock,
        AW_PROT 	=> mst0_aw_prot,
        AW_VALID 	=> mst0_aw_valid,
        AW_READY 	=> mst0_aw_ready,
        --W Channel
        W_DATA 		=> mst0_w_data,
        W_STRB 		=> mst0_w_strb,
        W_LAST 		=> mst0_w_last,
        W_VALID 	=> mst0_w_valid,
        W_READY 	=> mst0_w_ready,
        --B Channel
        B_ID 		=> mst0_b_id,
        B_RESP 		=> mst0_b_resp,
        B_VALID 	=> mst0_b_valid,
        B_READY 	=> mst0_b_ready,
        --NoC
        coherence_req_rdreq 		=> coherence_req_rdreq,
        coherence_req_data_out 		=> coherence_req_data_out,
        coherence_req_empty			=> coherence_req_empty,
        coherence_rsp_snd_wrreq 	=> coherence_rsp_snd_wrreq,
        coherence_rsp_snd_data_in 	=> coherence_rsp_snd_data_in,
        coherence_rsp_snd_full 		=> coherence_rsp_snd_full,
        dma_rcv_rdreq             	=> dma_rcv_rdreq,
        dma_rcv_data_out          	=> dma_rcv_data_out,
        dma_rcv_empty             	=> dma_rcv_empty,
        dma_snd_wrreq             	=> dma_snd_wrreq,
        dma_snd_data_in           	=> dma_snd_data_in,
        dma_snd_full              	=> dma_snd_full
      );

    -- No LLC wrapper
    mon_cache_int <= monitor_cache_none;

    -- FPGA-based memory link is not supported when ESP cahces are not enabled
    fpga_data_out <= (others => '0');
    fpga_oen <= '0';
    fpga_valid_out <= '0';
    fpga_clk_out <= '0';
    fpga_credit_out <= '0';

    -- Handle JTAG or EDCL requests to memory as well as ETH DMA
    noc2aximst_2 : noc2aximst
      generic map (
        tech        => CFG_FABTECH,
        mst_index   => 1,
        axitran     => 0,
        little_end  => 0,
        eth_dma     => 1,
        narrow_noc  => 0,
        cacheline   => 1,
		this_coh_flit_size  => ARCH_NOC_FLIT_SIZE)
      port map (
        ACLK  		=> tile_clk,
        ARESETn 	=> rst,
        local_y 	=> this_local_y,
        local_x 	=> this_local_x,
        --AR Channel
        AR_ID 		=> mst1_ar_id,
        AR_ADDR 	=> mst1_ar_addr,
        AR_LEN 		=> mst1_ar_len,
        AR_SIZE 	=> mst1_ar_size,
        AR_BURST 	=> mst1_ar_burst,
        AR_LOCK 	=> mst1_ar_lock,
        AR_PROT 	=> mst1_ar_prot,
        AR_VALID 	=> mst1_ar_valid,
        AR_READY 	=> mst1_ar_ready,
        --R Channel
        R_ID 		=> mst1_r_id,
        R_DATA 		=> mst1_r_data,
        R_RESP 		=> mst1_r_resp,
        R_LAST 		=> mst1_r_last,
        R_VALID 	=> mst1_r_valid,
        R_READY 	=> mst1_r_ready,
        --AW Channel
        AW_ID 		=> mst1_aw_id,
        AW_ADDR 	=> mst1_aw_addr,
        AW_LEN 		=> mst1_aw_len,
        AW_SIZE 	=> mst1_aw_size,
        AW_BURST 	=> mst1_aw_burst,
        AW_LOCK 	=> mst1_aw_lock,
        AW_PROT 	=> mst1_aw_prot,
        AW_VALID 	=> mst1_aw_valid,
        AW_READY 	=> mst1_aw_ready,
        --W Channel
        W_DATA 		=> mst1_w_data,
        W_STRB 		=> mst1_w_strb,
        W_LAST 		=> mst1_w_last,
        W_VALID 	=> mst1_w_valid,
        W_READY 	=> mst1_w_ready,
        --B Channel
        B_ID 		=> mst1_b_id,
        B_RESP 		=> mst1_b_resp,
        B_VALID 	=> mst1_b_valid,
        B_READY 	=> mst1_b_ready,
        --NoC
        coherence_req_rdreq 		=> remote_ahbm_rcv_rdreq,
        coherence_req_data_out 		=> remote_ahbm_rcv_data_out,
        coherence_req_empty 		=> remote_ahbm_rcv_empty,
        coherence_rsp_snd_wrreq 	=> remote_ahbm_snd_wrreq,
        coherence_rsp_snd_data_in 	=> remote_ahbm_snd_data_in,
        coherence_rsp_snd_full 		=> remote_ahbm_snd_full,

        dma_rcv_rdreq             	=> coherent_dma_rcv_rdreq,
        dma_rcv_data_out          	=> coherent_dma_rcv_data_out,
        dma_rcv_empty             	=> coherent_dma_rcv_empty,
        dma_snd_wrreq             	=> coherent_dma_snd_wrreq,
        dma_snd_data_in           	=> coherent_dma_snd_data_in,
        dma_snd_full              	=> coherent_dma_snd_full
        );

	  -- Tie off mst2 signals (only 2 masters are used)
      mst2_aw_id 	<= "10";
      mst2_aw_addr 	<= (others => '0');
      mst2_aw_len 	<= (others => '0');
      mst2_aw_size 	<= (others => '0');
      mst2_aw_burst <= (others => '0');	
      mst2_aw_lock 	<= '0';
      mst2_aw_prot 	<= (others => '0');
      mst2_aw_valid	<= '0';

      mst2_w_data 	<= (others => '0');
      mst2_w_strb 	<= (others => '0');
      mst2_w_last 	<= '0';
      mst2_w_valid 	<= '0';
	
      mst2_b_ready 	<= '0';

      mst2_ar_id	<= "10";
      mst2_ar_addr 	<= (others => '0');
      mst2_ar_len 	<= (others => '0');
      mst2_ar_size 	<= (others => '0');
      mst2_ar_burst <= (others => '0');	
      mst2_ar_lock 	<= '0';
      mst2_ar_prot 	<= (others => '0');
      mst2_ar_valid <= '0';
	
      mst2_r_ready 	<= '0';

  end generate no_cache_coherence;

  with_cache_coherence : if CFG_LLC_ENABLE /= 0 generate

    non_coh_dma_proxy_gen: if this_has_ddr /= 0 generate
    -- Handle accelerators non-coherent DMA

    noc2aximst_1 : noc2aximst
      generic map (
        tech        		=> CFG_FABTECH,
        mst_index   		=> 0,
        axitran     		=> GLOB_CPU_AXI,
        little_end  		=> GLOB_CPU_RISCV,
        eth_dma     		=> 0,
        narrow_noc  		=> 0,
        cacheline   		=> CFG_DLINE,
		this_coh_flit_size  => ARCH_NOC_FLIT_SIZE)
      port map (
        ACLK  		=> tile_clk,
        ARESETn 	=> rst,
        local_y 	=> this_local_y,
        local_x 	=> this_local_x,
        --AR Channel
        AR_ID 		=> mst0_ar_id,
        AR_ADDR 	=> mst0_ar_addr,
        AR_LEN 		=> mst0_ar_len,
        AR_SIZE 	=> mst0_ar_size,
        AR_BURST 	=> mst0_ar_burst,
        AR_LOCK 	=> mst0_ar_lock,
        AR_PROT 	=> mst0_ar_prot,
        AR_VALID 	=> mst0_ar_valid,
        AR_READY 	=> mst0_ar_ready,
        --R Channel
        R_ID    	=> mst0_r_id,
        R_DATA  	=> mst0_r_data,
        R_RESP  	=> mst0_r_resp,
        R_LAST  	=> mst0_r_last,
        R_VALID 	=> mst0_r_valid,
        R_READY 	=> mst0_r_ready,
        --AW Channel
        AW_ID 		=> mst0_aw_id,
        AW_ADDR 	=> mst0_aw_addr,
        AW_LEN 		=> mst0_aw_len,
        AW_SIZE 	=> mst0_aw_size,
        AW_BURST 	=> mst0_aw_burst,
        AW_LOCK 	=> mst0_aw_lock,
        AW_PROT 	=> mst0_aw_prot,
        AW_VALID 	=> mst0_aw_valid,
        AW_READY 	=> mst0_aw_ready,
        --W Channel
        W_DATA 		=> mst0_w_data,
        W_STRB 		=> mst0_w_strb,
        W_LAST 		=> mst0_w_last,
        W_VALID 	=> mst0_w_valid,
        W_READY 	=> mst0_w_ready,
        --B Channel
        B_ID 		=> mst0_b_id,
        B_RESP 		=> mst0_b_resp,
        B_VALID 	=> mst0_b_valid,
        B_READY 	=> mst0_b_ready,
        --NoC
        coherence_req_rdreq       => open,
        coherence_req_data_out    => (others => '0'),
        coherence_req_empty       => '1',
        coherence_rsp_snd_wrreq   => open,
        coherence_rsp_snd_data_in => open,
        coherence_rsp_snd_full    => '0',
        dma_rcv_rdreq             	=> dma_rcv_rdreq,
        dma_rcv_data_out          	=> dma_rcv_data_out,
        dma_rcv_empty             	=> dma_rcv_empty,
        dma_snd_wrreq             	=> dma_snd_wrreq,
        dma_snd_data_in           	=> dma_snd_data_in,
        dma_snd_full              	=> dma_snd_full

      );

    end generate non_coh_dma_proxy_gen;

    -- Handle CPU coherent requests and accelerators coherent DMA
    llc_rstn <= not srst and rst;

    llc_wrapper_1 : llc_wrapper_axi
      generic map (
        tech          => CFG_FABTECH,
        sets          => CFG_LLC_SETS,
        ways          => CFG_LLC_WAYS,
        ahb_if_en     => this_has_ddr,
        nl2           => CFG_NL2,
        nllc          => CFG_NLLC_COHERENT,
        noc_xlen      => CFG_XLEN,
        noc_ylen      => CFG_YLEN,
        hindex        => 2,
        pindex        => 1,
        pirq          => CFG_SLD_LLC_CACHE_IRQ,
        cacheline     => CFG_DLINE,
        little_end    => GLOB_CPU_RISCV,
        l2_cache_en   => CFG_L2_ENABLE,
        cache_tile_id => cache_tile_id,
        dma_tile_id   => dma_tile_id,
        tile_cache_id => tile_cache_id,
        tile_dma_id   => tile_dma_id,
        eth_dma_id    => tile_dma_id(io_tile_id),
        dma_y         => dma_y,
        dma_x         => dma_x,
        cache_y       => cache_y,
        cache_x       => cache_x)
      port map (
        rst                        => llc_rstn,
        clk                        => tile_clk,
        local_y                    => this_local_y,
        local_x                    => this_local_x,
        pconfig                    => this_llc_pconfig,

        --AR Channel
        AR_ID 		=> mst2_ar_id,
        AR_ADDR 	=> mst2_ar_addr,
        AR_LEN 		=> mst2_ar_len,
        AR_SIZE 	=> mst2_ar_size,
        AR_BURST 	=> mst2_ar_burst,
        AR_LOCK 	=> mst2_ar_lock,
        AR_PROT 	=> mst2_ar_prot,
        AR_VALID 	=> mst2_ar_valid,
        AR_READY 	=> mst2_ar_ready,
        --R Channel
        R_ID 		=> mst2_r_id,
        R_DATA 		=> mst2_r_data,
        R_RESP 		=> mst2_r_resp,
        R_LAST 		=> mst2_r_last,
        R_VALID 	=> mst2_r_valid,
        R_READY 	=> mst2_r_ready,
        --AW Channel
        AW_ID 		=> mst2_aw_id,
        AW_ADDR 	=> mst2_aw_addr,
        AW_LEN 		=> mst2_aw_len,
        AW_SIZE 	=> mst2_aw_size,
        AW_BURST 	=> mst2_aw_burst,
        AW_LOCK 	=> mst2_aw_lock,
        AW_PROT 	=> mst2_aw_prot,
        AW_VALID 	=> mst2_aw_valid,
        AW_READY 	=> mst2_aw_ready,
        --W Channel
        W_DATA 		=> mst2_w_data,
        W_STRB 		=> mst2_w_strb,
        W_LAST 		=> mst2_w_last,
        W_VALID 	=> mst2_w_valid,
        W_READY 	=> mst2_w_ready,
        --B Channel
        B_ID 		=> mst2_b_id,
        B_RESP 		=> mst2_b_resp,
        B_VALID 	=> mst2_b_valid,
        B_READY 	=> mst2_b_ready,

        apbi                       => apbi,
        apbo                       => apbo(1),
        -- NoC1->tile
        coherence_req_rdreq        => coherence_req_rdreq,
        coherence_req_data_out     => coherence_req_data_out,
        coherence_req_empty        => coherence_req_empty,
        -- tile->NoC2
        coherence_fwd_wrreq        => coherence_fwd_wrreq,
        coherence_fwd_data_in      => coherence_fwd_data_in,
        coherence_fwd_full         => coherence_fwd_full,
        -- tile->NoC3
        coherence_rsp_snd_wrreq    => coherence_rsp_snd_wrreq,
        coherence_rsp_snd_data_in  => coherence_rsp_snd_data_in,
        coherence_rsp_snd_full     => coherence_rsp_snd_full,
        -- NoC3->tile
        coherence_rsp_rcv_rdreq    => coherence_rsp_rcv_rdreq,
        coherence_rsp_rcv_data_out => coherence_rsp_rcv_data_out,
        coherence_rsp_rcv_empty    => coherence_rsp_rcv_empty,
        -- NoC4->tile
        dma_rcv_rdreq              => coherent_dma_rcv_rdreq,
        dma_rcv_data_out           => coherent_dma_rcv_data_out,
        dma_rcv_empty              => coherent_dma_rcv_empty,
        -- tile->NoC6
        dma_snd_wrreq              => coherent_dma_snd_wrreq,
        dma_snd_data_in            => coherent_dma_snd_data_in,
        dma_snd_full               => coherent_dma_snd_full,
        -- LLC->ext
        ext_req_ready              => llc_ext_req_ready,
        ext_req_valid              => llc_ext_req_valid,
        ext_req_data               => llc_ext_req_data,
        -- ext->LLC
        ext_rsp_ready              => llc_ext_rsp_ready,
        ext_rsp_valid              => llc_ext_rsp_valid,
        ext_rsp_data               => llc_ext_rsp_data,
        -- Monitor
        mon_cache                  => mon_cache_int
        );


    mem2ext_gen: if this_has_ddr = 0 generate
    -- Use FPGA-based memory link if DDR controller is not available
    -- This option is only supported with the ESP cache hierarchy enabled
    mem2ext_1: mem2ext
      port map (
        clk               => tile_clk,
        rstn              => rst,
        local_y           => this_local_y,
        local_x           => this_local_x,
        fpga_data_in      => fpga_data_in,
        fpga_data_out     => fpga_data_out,
        fpga_valid_in     => fpga_valid_in,
        fpga_valid_out    => fpga_valid_out,
        fpga_oen          => fpga_oen,
        fpga_clk_in       => fpga_clk_in,
        fpga_clk_out      => fpga_clk_out,
        fpga_credit_in    => fpga_credit_in,
        fpga_credit_out   => fpga_credit_out,
        llc_ext_req_ready => llc_ext_req_ready,
        llc_ext_req_valid => llc_ext_req_valid,
        llc_ext_req_data  => llc_ext_req_data,
        llc_ext_rsp_ready => llc_ext_rsp_ready,
        llc_ext_rsp_valid => llc_ext_rsp_valid,
        llc_ext_rsp_data  => llc_ext_rsp_data,
        dma_rcv_rdreq     => dma_rcv_rdreq,
        dma_rcv_data_out  => dma_rcv_data_out,
        dma_rcv_empty     => dma_rcv_empty,
        dma_snd_wrreq     => dma_snd_wrreq,
        dma_snd_data_in   => dma_snd_data_in,
        dma_snd_full      => dma_snd_full);

    -- ESPLink cannot access memory through the FPGA-based link.
    -- A second instance of ESPLink is placed on the FPGA connected to DDR to
    -- load programs in memory
    remote_ahbm_rcv_rdreq <= '0';
    remote_ahbm_snd_data_in <= (others => '0');
    remote_ahbm_snd_wrreq <= '0';
    end generate mem2ext_gen;

    no_fpga_mem_gen: if this_has_ddr /= 0 generate
      fpga_data_out <= (others => '0');
      fpga_oen <= '0';
      fpga_valid_out <= '0';
      fpga_clk_out <= '0';
      fpga_credit_out <= '0';
    end generate no_fpga_mem_gen;

    esplink_proxy_gen: if this_has_ddr /= 0 generate
    -- Handle JTAG or EDCL requests to memory
    noc2aximst_2 : noc2aximst
      generic map (
        tech        => CFG_FABTECH,
        mst_index   => 1,
        axitran     => 0,
        little_end  => 0,
        eth_dma     => 0,
        narrow_noc  => 0,
        cacheline   => 1,
		this_coh_flit_size  => ARCH_NOC_FLIT_SIZE)
      port map (
        ACLK  		=> tile_clk,
        ARESETn 	=> rst,
        local_y 	=> this_local_y,
        local_x 	=> this_local_x,
        --AR Channel
        AR_ID 		=> mst1_ar_id,
        AR_ADDR 	=> mst1_ar_addr,
        AR_LEN 		=> mst1_ar_len,
        AR_SIZE 	=> mst1_ar_size,
        AR_BURST 	=> mst1_ar_burst,
        AR_LOCK 	=> mst1_ar_lock,
        AR_PROT 	=> mst1_ar_prot,
        AR_VALID 	=> mst1_ar_valid,
        AR_READY 	=> mst1_ar_ready,
        --R Channel
        R_ID 		=> mst1_r_id,
        R_DATA 		=> mst1_r_data,
        R_RESP 		=> mst1_r_resp,
        R_LAST 		=> mst1_r_last,
        R_VALID 	=> mst1_r_valid,
        R_READY 	=> mst1_r_ready,
        --AW Channel
        AW_ID 		=> mst1_aw_id,
        AW_ADDR 	=> mst1_aw_addr,
        AW_LEN 		=> mst1_aw_len,
        AW_SIZE 	=> mst1_aw_size,
        AW_BURST 	=> mst1_aw_burst,
        AW_LOCK 	=> mst1_aw_lock,
        AW_PROT 	=> mst1_aw_prot,
        AW_VALID 	=> mst1_aw_valid,
        AW_READY 	=> mst1_aw_ready,
        --W Channel
        W_DATA 		=> mst1_w_data,
        W_STRB 		=> mst1_w_strb,
        W_LAST 		=> mst1_w_last,
        W_VALID 	=> mst1_w_valid,
        W_READY 	=> mst1_w_ready,
        --B Channel
        B_ID 		=> mst1_b_id,
        B_RESP 		=> mst1_b_resp,
        B_VALID 	=> mst1_b_valid,
        B_READY 	=> mst1_b_ready,
        --NoC
        coherence_req_rdreq 		=> remote_ahbm_rcv_rdreq,
        coherence_req_data_out 		=> remote_ahbm_rcv_data_out,
        coherence_req_empty 		=> remote_ahbm_rcv_empty,
        coherence_rsp_snd_wrreq 	=> remote_ahbm_snd_wrreq,
        coherence_rsp_snd_data_in 	=> remote_ahbm_snd_data_in,
        coherence_rsp_snd_full 		=> remote_ahbm_snd_full,

        dma_rcv_rdreq             => open,
        dma_rcv_data_out          => (others => '0'),
        dma_rcv_empty             => '1',
        dma_snd_wrreq             => open,
        dma_snd_data_in           => open,
        dma_snd_full              => '0'
        );

    end generate esplink_proxy_gen;

  end generate with_cache_coherence;

  remote_ahbs_rcv_rdreq <= remote_ahbm_rcv_rdreq;
  remote_ahbm_rcv_empty <= remote_ahbs_rcv_empty;
  remote_ahbs_snd_wrreq <= remote_ahbm_snd_wrreq;
  remote_ahbm_snd_full  <= remote_ahbs_snd_full;

  large_bus: if ARCH_BITS /= 32 generate
    remote_ahbm_rcv_data_out <= narrow_to_large_flit(remote_ahbs_rcv_data_out);
    remote_ahbs_snd_data_in <= large_to_narrow_flit(remote_ahbm_snd_data_in);
  end generate large_bus;

  std_bus: if ARCH_BITS = 32 generate
    remote_ahbm_rcv_data_out <= remote_ahbs_rcv_data_out;
    remote_ahbs_snd_data_in  <= remote_ahbm_snd_data_in;
  end generate std_bus;

  -- APB to LLC cache and CSRs
  noc2apb_1 : noc2apb
    generic map (
      tech         => CFG_FABTECH,
      local_apb_en => this_local_apb_en)
    port map (
      rst              => rst,
      clk              => tile_clk,
      local_y          => this_local_y,
      local_x          => this_local_x,
      apbi             => apbi,
      apbo             => apbo,
      pready           => '1',
      apb_snd_wrreq    => apb_snd_wrreq,
      apb_snd_data_in  => apb_snd_data_in,
      apb_snd_full     => apb_snd_full,
      apb_rcv_rdreq    => apb_rcv_rdreq,
      apb_rcv_data_out => apb_rcv_data_out,
      apb_rcv_empty    => apb_rcv_empty);

  -----------------------------------------------------------------------------
  -- Tile queues
  -----------------------------------------------------------------------------


  mem_tile_q_1 : mem_tile_q
    generic map (
      tech => CFG_FABTECH)
    port map (
      rst                        => rst,
      clk                        => tile_clk,
      coherence_req_rdreq        => coherence_req_rdreq,
      coherence_req_data_out     => coherence_req_data_out,
      coherence_req_empty        => coherence_req_empty,
      coherence_fwd_wrreq        => coherence_fwd_wrreq,
      coherence_fwd_data_in      => coherence_fwd_data_in,
      coherence_fwd_full         => coherence_fwd_full,
      coherence_rsp_snd_wrreq    => coherence_rsp_snd_wrreq,
      coherence_rsp_snd_data_in  => coherence_rsp_snd_data_in,
      coherence_rsp_snd_full     => coherence_rsp_snd_full,
      coherence_rsp_rcv_rdreq    => coherence_rsp_rcv_rdreq,
      coherence_rsp_rcv_data_out => coherence_rsp_rcv_data_out,
      coherence_rsp_rcv_empty    => coherence_rsp_rcv_empty,
      dma_rcv_rdreq              => dma_rcv_rdreq,
      dma_rcv_data_out           => dma_rcv_data_out,
      dma_rcv_empty              => dma_rcv_empty,
      coherent_dma_snd_wrreq     => coherent_dma_snd_wrreq,
      coherent_dma_snd_data_in   => coherent_dma_snd_data_in,
      coherent_dma_snd_full      => coherent_dma_snd_full,
      coherent_dma_snd_atleast_4slots => coherent_dma_snd_atleast_4slots,
      coherent_dma_snd_exactly_3slots => coherent_dma_snd_exactly_3slots,
      dma_snd_wrreq              => dma_snd_wrreq,
      dma_snd_data_in            => dma_snd_data_in,
      dma_snd_full               => dma_snd_full,
      dma_snd_atleast_4slots     => dma_snd_atleast_4slots,
      dma_snd_exactly_3slots     => dma_snd_exactly_3slots,
      coherent_dma_rcv_rdreq     => coherent_dma_rcv_rdreq,
      coherent_dma_rcv_data_out  => coherent_dma_rcv_data_out,
      coherent_dma_rcv_empty     => coherent_dma_rcv_empty,
      remote_ahbs_rcv_rdreq      => remote_ahbs_rcv_rdreq,
      remote_ahbs_rcv_data_out   => remote_ahbs_rcv_data_out,
      remote_ahbs_rcv_empty      => remote_ahbs_rcv_empty,
      remote_ahbs_snd_wrreq      => remote_ahbs_snd_wrreq,
      remote_ahbs_snd_data_in    => remote_ahbs_snd_data_in,
      remote_ahbs_snd_full       => remote_ahbs_snd_full,
      apb_rcv_rdreq              => apb_rcv_rdreq,
      apb_rcv_data_out           => apb_rcv_data_out,
      apb_rcv_empty              => apb_rcv_empty,
      apb_snd_wrreq              => apb_snd_wrreq,
      apb_snd_data_in            => apb_snd_data_in,
      apb_snd_full               => apb_snd_full,
      noc1_out_data              => test1_output_port,
      noc1_out_void              => test1_data_void_out,
      noc1_out_stop              => test1_stop_out,
      noc1_in_data               => test1_input_port,
      noc1_in_void               => test1_data_void_in,
      noc1_in_stop               => test1_stop_in,
      noc2_out_data              => test2_output_port,
      noc2_out_void              => test2_data_void_out,
      noc2_out_stop              => test2_stop_out,
      noc2_in_data               => test2_input_port,
      noc2_in_void               => test2_data_void_in,
      noc2_in_stop               => test2_stop_in,
      noc3_out_data              => test3_output_port,
      noc3_out_void              => test3_data_void_out,
      noc3_out_stop              => test3_stop_out,
      noc3_in_data               => test3_input_port,
      noc3_in_void               => test3_data_void_in,
      noc3_in_stop               => test3_stop_in,
      noc4_out_data              => test4_output_port,
      noc4_out_void              => test4_data_void_out,
      noc4_out_stop              => test4_stop_out,
      noc4_in_data               => test4_input_port,
      noc4_in_void               => test4_data_void_in,
      noc4_in_stop               => test4_stop_in,
      noc5_out_data              => test5_output_port,
      noc5_out_void              => test5_data_void_out,
      noc5_out_stop              => test5_stop_out,
      noc5_in_data               => test5_input_port,
      noc5_in_void               => test5_data_void_in,
      noc5_in_stop               => test5_stop_in,
      noc6_out_data              => test6_output_port,
      noc6_out_void              => test6_data_void_out,
      noc6_out_stop              => test6_stop_out,
      noc6_in_data               => test6_input_port,
      noc6_in_void               => test6_data_void_in,
      noc6_in_stop               => test6_stop_in);

end;
