------------------------------------------------------------------------------
--  ESP - xilinx - vc707
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.grlib_config.all;
use work.amba.all;
use work.stdlib.all;
use work.devices.all;
use work.gencomp.all;
use work.leon3.all;
use work.uart.all;
use work.misc.all;
use work.net.all;
use work.svga_pkg.all;
library unisim;
-- pragma translate_off
use work.sim.all;
-- pragma translate_on
use unisim.VCOMPONENTS.all;
use work.monitor_pkg.all;
use work.sldacc.all;
use work.tile.all;
use work.nocpackage.all;
use work.cachepackage.all;
use work.coretypes.all;
use work.config.all;
use work.esp_global.all;
use work.socmap.all;
use work.tiles_pkg.all;

entity top is
  generic (
    SIMULATION          : boolean := false
  );
  port (
    reset           : in    std_ulogic;
    sys_clk_p       : in    std_ulogic;  -- 200 MHz clock
    sys_clk_n       : in    std_ulogic;  -- 200 MHz clock
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
    gtrefclk_p      : in    std_logic;
    gtrefclk_n      : in    std_logic;
    txp             : out   std_logic;
    txn             : out   std_logic;
    rxp             : in    std_logic;
    rxn             : in    std_logic;
    emdio           : inout std_logic;
    emdc            : out   std_ulogic;
    eint            : in    std_ulogic;
    erst            : out   std_ulogic;
    uart_rxd        : in    std_ulogic;  -- UART1_RX (u1i.rxd)
    uart_txd        : out   std_ulogic;  -- UART1_TX (u1o.txd)
    uart_ctsn       : in    std_ulogic;  -- UART1_RTSN (u1i.ctsn)
    uart_rtsn       : out   std_ulogic;  -- UART1_RTSN (u1o.rtsn)
    button          : in    std_logic_vector(3 downto 0);
    switch          : inout std_logic_vector(4 downto 0);
    led             : out   std_logic_vector(6 downto 0));
end;


architecture rtl of top is

component axi_ram_sim is
  generic(
    kbytes		: integer := 1;
    DATA_WIDTH 		: integer := 32;
    ADDR_WIDTH 		: integer := 32;
    STRB_WIDTH 		: integer := 4;
    ID_WIDTH   		: integer := 8;
    PIPELINE_OUTPUT 	: integer := 0
  );
  port(
    clk 		: in std_logic;
    rst 		: in std_logic;
    -- AW Channel
    s_axi_awid 		: in std_logic_vector(7 downto 0);
    s_axi_awaddr 	: in std_logic_vector(GLOB_PHYS_ADDR_BITS-1 downto 0);
    s_axi_awlen 	: in std_logic_vector(7 downto 0);
    s_axi_awsize 	: in std_logic_vector(2 downto 0);
    s_axi_awburst 	: in std_logic_vector(1 downto 0);
    s_axi_awlock 	: in std_logic;
    s_axi_awcache 	: in std_logic_vector(3 downto 0);
    s_axi_awprot 	: in std_logic_vector(2 downto 0);
    s_axi_awvalid 	: in std_logic;
    s_axi_awready 	: out std_logic;
    -- W Channel
    s_axi_wdata 	: in std_logic_vector(MEM_AXIDW-1 downto 0);
    s_axi_wstrb 	: in std_logic_vector(AW-1 downto 0);
    s_axi_wlast 	: in std_logic;
    s_axi_wvalid 	: in std_logic;
    s_axi_wready 	: out std_logic;
    -- B Channel
    s_axi_bid 		: out std_logic_vector(7 downto 0);
    s_axi_bresp 	: out std_logic_vector(1 downto 0);
    s_axi_bvalid 	: out std_logic;
    s_axi_bready 	: in std_logic;
    -- AR Channel
    s_axi_arid 		: in std_logic_vector(7 downto 0);
    s_axi_araddr 	: in std_logic_vector(GLOB_PHYS_ADDR_BITS-1 downto 0);
    s_axi_arlen 	: in std_logic_vector(7 downto 0);
    s_axi_arsize 	: in std_logic_vector(2 downto 0);
    s_axi_arburst 	: in std_logic_vector(1 downto 0);
    s_axi_arlock 	: in std_logic;
    s_axi_arcache 	: in std_logic_vector(3 downto 0);
    s_axi_arprot 	: in std_logic_vector(2 downto 0);
    s_axi_arvalid 	: in std_logic;
    s_axi_arready 	: out std_logic;
    -- R Channel
    s_axi_rid 		: out std_logic_vector(7 downto 0);
    s_axi_rdata 	: out std_logic_vector(MEM_AXIDW-1 downto 0);
    s_axi_rresp 	: out std_logic_vector(1 downto 0);
    s_axi_rlast 	: out std_logic;
    s_axi_rvalid 	: out std_logic;
    s_axi_rready 	: in std_logic
  );
end component axi_ram_sim;

component sgmii_vc707
  generic(
    pindex          : integer := 0;
    paddr           : integer := 0;
    pmask           : integer := 16#fff#;
    abits           : integer := 8;
    autonegotiation : integer := 1;
    pirq            : integer := 0;
    debugmem        : integer := 0;
    tech            : integer := 0;
    simulation      : boolean := false
  );
  port(
    sgmiii    :  in  eth_sgmii_in_type;
    sgmiio    :  out eth_sgmii_out_type;
    gmiii     : out   eth_in_type;
    gmiio     : in    eth_out_type;
    reset     : in    std_logic;                     -- Asynchronous reset for entire core.
    apb_clk   : in    std_logic;
    apb_rstn  : in    std_logic;
    apbi      : in    apb_slv_in_type;
    apbo      : out   apb_slv_out_type
  );
end component;

component edcl_ahbmst_emu is
  generic (
    hindex     : integer := 0
  );
  port (
    clk    :  in  std_ulogic;
    reset  :  in  std_ulogic;
    ahbmo  :  out ahb_mst_out_type;
    ahbmi  :  in  ahb_mst_in_type;
    edcl_oen_ctrl  : out std_logic
  );
end component edcl_ahbmst_emu;

-- FPGA DDR3 Controller. Must be moved to FPGA partition
component axi2mig_7series
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
    s_axi_wdata0    : in    std_logic_vector(MEM_AXIDW-1 downto 0);
    s_axi_wstrb0    : in    std_logic_vector((MEM_AXIDW/8)-1 downto 0);
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
    s_axi_rdata0    : out   std_logic_vector(MEM_AXIDW-1 downto 0);
    s_axi_rresp     : out   std_logic_vector(1 downto 0);
    s_axi_rlast     : out   std_logic;
    s_axi_rvalid    : out   std_logic
   );
end component ;

function fix_endian (
le : std_logic_vector((MEM_AXIDW/8) - 1 downto 0))
return std_logic_vector is
variable be : std_logic_vector((MEM_AXIDW/8) - 1 downto 0);
begin
if GLOB_CPU_RISCV = 0 then
  be := le;
else
  for i in 0 to (MEM_AXIDW/8) - 1 loop
	be(i) := le(MEM_AXIDW/8 - (i + 1));
  end loop;  -- i
end if;
return be;
end fix_endian;

-- constants
signal vcc, gnd   : std_logic_vector(31 downto 0);

-- Switches
signal sel0, sel1, sel2, sel3, sel4 : std_ulogic;

-- clock and reset
signal clkm : std_ulogic := '0';
signal rstn, rstraw : std_ulogic;
signal cgi : clkgen_in_type;
signal cgo : clkgen_out_type;
signal lock, calib_done, rst : std_ulogic;
signal clkref  : std_logic;
signal migrstn : std_logic;

-- AXI_SIM_RAM
signal s_axi_awid 		: std_logic_vector(7 downto 0);
signal s_axi_awaddr 	: std_logic_vector(GLOB_PHYS_ADDR_BITS-1 downto 0);
signal s_axi_awlen 		: std_logic_vector(7 downto 0);
signal s_axi_awsize 	: std_logic_vector(2 downto 0);
signal s_axi_awburst 	: std_logic_vector(1 downto 0);
signal s_axi_awlock 	: std_logic;
signal s_axi_awcache 	: std_logic_vector(3 downto 0);
signal s_axi_awprot 	: std_logic_vector(2 downto 0);
signal s_axi_awvalid 	: std_logic;
signal s_axi_awready 	: std_logic;
signal s_axi_wdata 		: std_logic_vector(MEM_AXIDW-1 downto 0);
signal s_axi_wstrb 		: std_logic_vector((MEM_AXIDW/8)-1 downto 0);
signal s_axi_wstrb_adj  : std_logic_vector((MEM_AXIDW/8)-1 downto 0);
signal s_axi_wlast 		: std_logic;
signal s_axi_wvalid 	: std_logic;
signal s_axi_wready 	: std_logic;
signal s_axi_bid 		: std_logic_vector(7 downto 0);
signal s_axi_bresp 		: std_logic_vector(1 downto 0);
signal s_axi_bvalid 	: std_logic;
signal s_axi_bready 	: std_logic;
signal s_axi_arid 		: std_logic_vector(7 downto 0);
signal s_axi_araddr 	: std_logic_vector(GLOB_PHYS_ADDR_BITS-1 downto 0);
signal s_axi_arlen 		: std_logic_vector(7 downto 0);
signal s_axi_arsize 	: std_logic_vector(2 downto 0);
signal s_axi_arburst 	: std_logic_vector(1 downto 0);
signal s_axi_arlock 	: std_logic;
signal s_axi_arcache 	: std_logic_vector(3 downto 0);
signal s_axi_arprot 	: std_logic_vector(2 downto 0);
signal s_axi_arvalid 	: std_logic;
signal s_axi_arready 	: std_logic;
signal s_axi_rid 		: std_logic_vector(7 downto 0);
signal s_axi_rdata 		: std_logic_vector(MEM_AXIDW-1 downto 0);
signal s_axi_rresp 		: std_logic_vector(1 downto 0);
signal s_axi_rlast 		: std_logic;
signal s_axi_rvalid 	: std_logic;
signal s_axi_rready 	: std_logic;

-- Tiles

-- UART
signal uart_rxd_int  : std_logic;       -- UART1_RX (u1i.rxd)
signal uart_txd_int  : std_logic;       -- UART1_TX (u1o.txd)
signal uart_ctsn_int : std_logic;       -- UART1_RTSN (u1i.ctsn)
signal uart_rtsn_int : std_logic;       -- UART1_RTSN (u1o.rtsn)

-- Memory controller DDR3
signal ddr_ahbsi   : ahb_slv_in_vector_type(0 to MEM_ID_RANGE_MSB);
signal ddr_ahbso   : ahb_slv_out_vector_type(0 to MEM_ID_RANGE_MSB);

-- DVI (unused on this board)
signal dvi_apbi  : apb_slv_in_type;
signal dvi_apbo  : apb_slv_out_type;
signal dvi_ahbmi : ahb_mst_in_type;
signal dvi_ahbmo : ahb_mst_out_type;

-- Ethernet
signal gmiii : eth_in_type;
signal gmiio : eth_out_type;
signal sgmiii :  eth_sgmii_in_type;
signal sgmiio :  eth_sgmii_out_type;
signal sgmiirst : std_logic;
signal ethernet_phy_int : std_logic;
signal rxd1 : std_logic;
signal txd1 : std_logic;
signal ethi : eth_in_type;
signal etho : eth_out_type;
signal egtx_clk :std_ulogic;
signal negtx_clk :std_ulogic;
constant CPU_FREQ : integer := 50000;  -- cpu frequency in KHz
signal eth0_apbi : apb_slv_in_type;
signal eth0_apbo : apb_slv_out_type;
signal sgmii0_apbi : apb_slv_in_type;
signal sgmii0_apbo : apb_slv_out_type;
signal eth0_ahbmi : ahb_mst_in_type;
signal eth0_ahbmo : ahb_mst_out_type;
signal edcl_ahbmo : ahb_mst_out_type;

-- CPU flags
signal cpuerr : std_ulogic;

-- NOC
signal chip_rst : std_ulogic;
signal sys_clk : std_logic_vector(0 to 0);
signal chip_refclk : std_ulogic := '0';

attribute mark_debug : string;
attribute mark_debug of s_axi_awid  : signal is "true";
attribute mark_debug of s_axi_awaddr : signal is "true";
attribute mark_debug of s_axi_awlen  : signal is "true";
attribute mark_debug of s_axi_awsize : signal is "true";
attribute mark_debug of s_axi_awburst : signal is "true";
attribute mark_debug of s_axi_awlock  : signal is "true";
attribute mark_debug of s_axi_awcache : signal is "true";
attribute mark_debug of s_axi_awprot  : signal is "true";
attribute mark_debug of s_axi_awvalid : signal is "true";
attribute mark_debug of s_axi_awready : signal is "true";
attribute mark_debug of s_axi_wdata	 : signal is "true";
attribute mark_debug of s_axi_wstrb : signal is "true";
attribute mark_debug of s_axi_wlast : signal is "true";
attribute mark_debug of s_axi_wvalid : signal is "true";
attribute mark_debug of s_axi_wready : signal is "true";
attribute mark_debug of s_axi_bid 	 : signal is "true";
attribute mark_debug of s_axi_bresp  : signal is "true";
attribute mark_debug of s_axi_bvalid : signal is "true";
attribute mark_debug of s_axi_bready : signal is "true";
attribute mark_debug of s_axi_arid 	 : signal is "true";
attribute mark_debug of s_axi_araddr : signal is "true";
attribute mark_debug of s_axi_arlen  : signal is "true";
attribute mark_debug of s_axi_arsize : signal is "true";
attribute mark_debug of s_axi_arburst : signal is "true";
attribute mark_debug of s_axi_arlock  : signal is "true";
attribute mark_debug of s_axi_arcache : signal is "true";
attribute mark_debug of s_axi_arprot  : signal is "true";
attribute mark_debug of s_axi_arvalid : signal is "true";
attribute mark_debug of s_axi_arready : signal is "true";
attribute mark_debug of s_axi_rid 	 : signal is "true";
attribute mark_debug of s_axi_rdata  : signal is "true";
attribute mark_debug of s_axi_rresp  : signal is "true";
attribute mark_debug of s_axi_rlast  : signal is "true";
attribute mark_debug of s_axi_rvalid : signal is "true";
attribute mark_debug of s_axi_rready : signal is "true";
attribute mark_debug of edcl_ahbmo : signal is "true";
attribute mark_debug of eth0_ahbmi  : signal is "true";
attribute mark_debug of eth0_ahbmo  : signal is "true";

attribute keep : boolean;
attribute syn_keep : string;
attribute keep of clkm : signal is true;
attribute keep of chip_refclk : signal is true;
attribute syn_keep of clkm : signal is "true";
attribute syn_keep of chip_refclk : signal is "true";

begin

-------------------------------------------------------------------------------
-- Leds -----------------------------------------------------------------------
-------------------------------------------------------------------------------

  -- From CPU 0
  led0_pad : outpad generic map (tech => CFG_FABTECH, level => cmos, voltage => x18v)
    port map (led(0), cpuerr);
  --pragma translate_off
  process(clkm, rstn)
  begin  -- process
    if rstn = '1' then
      assert cpuerr = '0' report "Program Completed!" severity failure;
    end if;
  end process;
  --pragma translate_on

  -- From DDR controller (on FPGA)
  led2_pad : outpad generic map (tech => CFG_FABTECH, level => cmos, voltage => x18v)
    port map (led(2), calib_done);
  led3_pad : outpad generic map (tech => CFG_FABTECH, level => cmos, voltage => x18v)
    port map (led(3), lock);
  led4_pad : outpad generic map (tech => CFG_FABTECH, level => cmos, voltage => x18v)
    port map (led(4), ddr_ahbso(0).hready);

  -- Unused
  led1_pad : outpad generic map (tech => CFG_FABTECH, level => cmos, voltage => x18v)
    port map (led(1), '0');
  led5_pad : outpad generic map (tech => CFG_FABTECH, level => cmos, voltage => x18v)
    port map (led(5), '0');
  led6_pad : outpad generic map (tech => CFG_FABTECH, level => cmos, voltage => x18v)
    port map (led(6), '0');

-------------------------------------------------------------------------------
-- Switches -------------------------------------------------------------------
-------------------------------------------------------------------------------

  sw0_pad : iopad generic map (tech => CFG_FABTECH, level => cmos, voltage => x18v)
    port map (switch(0), '0', '1', sel0);
  sw1_pad : iopad generic map (tech => CFG_FABTECH, level => cmos, voltage => x18v)
    port map (switch(1), '0', '1', sel1);
  sw2_pad : iopad generic map (tech => CFG_FABTECH, level => cmos, voltage => x18v)
    port map (switch(2), '0', '1', sel2);
  sw3_pad : iopad generic map (tech => CFG_FABTECH, level => cmos, voltage => x18v)
    port map (switch(3), '0', '1', sel3);
  sw4_pad : iopad generic map (tech => CFG_FABTECH, level => cmos, voltage => x18v)
    port map (switch(4), '0', '1', sel4);

-------------------------------------------------------------------------------
-- Buttons --------------------------------------------------------------------
-------------------------------------------------------------------------------

  --pio_pad : inpad generic map (tech => CFG_FABTECH, level => cmos, voltage => x18v)
  --  port map (button(i-4), gpioi.din(i));

----------------------------------------------------------------------
--- FPGA Reset and Clock generation  ---------------------------------
----------------------------------------------------------------------

  vcc <= (others => '1'); gnd <= (others => '0');
  cgi.pllctrl <= "00"; cgi.pllrst <= rstraw;

  reset_pad : inpad generic map (tech => CFG_FABTECH, level => cmos, voltage => x18v) port map (reset, rst);
  rst0 : rstgen         -- reset generator
  generic map (acthigh => 1, syncin => 0)
  port map (rst, clkm, lock, rstn, rstraw);
  lock <= calib_done and cgo.clklock;

  rst1 : rstgen         -- reset generator
  generic map (acthigh => 1)
  port map (rst, clkm, lock, migrstn, open);


-----------------------------------------------------------------------------
-- UART pads
-----------------------------------------------------------------------------

  uart_rxd_pad   : inpad  generic map (level => cmos, voltage => x18v, tech => CFG_FABTECH) port map (uart_rxd, uart_rxd_int);
  uart_txd_pad   : outpad generic map (level => cmos, voltage => x18v, tech => CFG_FABTECH) port map (uart_txd, uart_txd_int);
  uart_ctsn_pad : inpad  generic map (level => cmos, voltage => x18v, tech => CFG_FABTECH) port map (uart_ctsn, uart_ctsn_int);
  uart_rtsn_pad : outpad generic map (level => cmos, voltage => x18v, tech => CFG_FABTECH) port map (uart_rtsn, uart_rtsn_int);

----------------------------------------------------------------------
---  DDR3 memory controller ------------------------------------------
----------------------------------------------------------------------

  clkgenmigref0 : clkgen
    generic map (CFG_FABTECH, 16, 32, 0, 0, 0, 0, 0, 100000)
    port map (clkm, clkm, chip_refclk, open, clkref, open, open, cgi, cgo, open, open, open);

	s_axi_wstrb_adj <= fix_endian(s_axi_wstrb);

    gen_mig : if (SIMULATION /= true) generate
        ddrc : axi2mig_7series
      generic map (
        AXIDW => MEM_AXIDW
	  )
      port map(
        ddr3_dq         => ddr3_dq,
        ddr3_dqs_p      => ddr3_dqs_p,
        ddr3_dqs_n      => ddr3_dqs_n,
        ddr3_addr       => ddr3_addr,
        ddr3_ba         => ddr3_ba,
        ddr3_ras_n      => ddr3_ras_n,
        ddr3_cas_n      => ddr3_cas_n,
        ddr3_we_n       => ddr3_we_n,
        ddr3_reset_n    => ddr3_reset_n,
        ddr3_ck_p       => ddr3_ck_p,
        ddr3_ck_n       => ddr3_ck_n,
        ddr3_cke        => ddr3_cke,
        ddr3_cs_n       => ddr3_cs_n,
        ddr3_dm         => ddr3_dm,
        ddr3_odt        => ddr3_odt,
		calib_done     	=> calib_done,
		rst_n_syn      	=> migrstn,
		rst_n_async     => rstraw,
        sys_clk_p       => sys_clk_p,
        sys_clk_n       => sys_clk_n,
        clk_ref_i       => clkref,
        ui_clk          => clkm,
        ui_clk_sync_rst => open,
        s_axi_awid0      => s_axi_awid,
        s_axi_awaddr0    => s_axi_awaddr,
        s_axi_awlen     => s_axi_awlen,
        s_axi_awsize    => s_axi_awsize,
        s_axi_awburst   => s_axi_awburst,
        s_axi_awlock    => s_axi_awlock,
        s_axi_awcache   => s_axi_awcache,
        s_axi_awprot    => s_axi_awprot,
        s_axi_awqos    => (others => '0'),
        s_axi_awvalid   => s_axi_awvalid,
        s_axi_awready   => s_axi_awready,
        s_axi_wdata0     => s_axi_wdata,
        s_axi_wstrb0     => s_axi_wstrb,
        s_axi_wlast     => s_axi_wlast,
        s_axi_wvalid    => s_axi_wvalid,
        s_axi_wready    => s_axi_wready,
        s_axi_bready    => s_axi_bready,
        s_axi_bid0       => s_axi_bid,
        s_axi_bresp     => s_axi_bresp,
        s_axi_bvalid    => s_axi_bvalid,
        s_axi_arid0      => s_axi_arid,
        s_axi_araddr0    => s_axi_araddr,
        s_axi_arlen     => s_axi_arlen,
        s_axi_arsize    => s_axi_arsize,
        s_axi_arburst   => s_axi_arburst,
        s_axi_arlock    => s_axi_arlock,
        s_axi_arcache   => s_axi_arcache,
        s_axi_arprot    => s_axi_arprot,
        s_axi_arqos    => (others => '0'),
        s_axi_arvalid   => s_axi_arvalid,
        s_axi_arready   => s_axi_arready,
        s_axi_rready    => s_axi_rready,
        s_axi_rid0       => s_axi_rid,
        s_axi_rdata0     => s_axi_rdata,
        s_axi_rresp     => s_axi_rresp,
        s_axi_rlast     => s_axi_rlast,
        s_axi_rvalid    => s_axi_rvalid
        );

  end generate gen_mig;

  gen_mig_model : if (SIMULATION = true) generate
    -- pragma translate_off

    mig_axiram : axi_ram_sim
      generic map (
	kbytes			=> 2 * 1024,
        DATA_WIDTH 		=> MEM_AXIDW,
        ADDR_WIDTH 		=> GLOB_PHYS_ADDR_BITS,
        STRB_WIDTH 		=> AW,
        ID_WIDTH   		=> 8,
        PIPELINE_OUTPUT => 0
        )
      port map(
        clk 	=> clkm,
        rst 	=> rstn,
        -- AW Channel
        s_axi_awid 	=> s_axi_awid,
        s_axi_awaddr 	=> s_axi_awaddr,
        s_axi_awlen	=> s_axi_awlen,
        s_axi_awsize 	=> s_axi_awsize,
        s_axi_awburst 	=> s_axi_awburst,
        s_axi_awlock 	=> s_axi_awlock,
        s_axi_awcache 	=> s_axi_awcache,
        s_axi_awprot 	=> s_axi_awprot,
        s_axi_awvalid 	=> s_axi_awvalid,
        s_axi_awready 	=> s_axi_awready,
        -- W Channel
        s_axi_wdata 	=> s_axi_wdata,
        s_axi_wstrb 	=> s_axi_wstrb,
        s_axi_wlast 	=> s_axi_wlast,
        s_axi_wvalid 	=> s_axi_wvalid,
        s_axi_wready 	=> s_axi_wready,
        -- B Channel
        s_axi_bid	=> s_axi_bid,
        s_axi_bresp 	=> s_axi_bresp,
        s_axi_bvalid 	=> s_axi_bvalid,
        s_axi_bready 	=> s_axi_bready,
        -- AR Channel
        s_axi_arid	=> s_axi_arid,
        s_axi_araddr 	=> s_axi_araddr,
        s_axi_arlen 	=> s_axi_arlen,
        s_axi_arsize 	=> s_axi_arsize,
        s_axi_arburst 	=> s_axi_arburst,
        s_axi_arlock 	=> s_axi_arlock,
        s_axi_arcache 	=> s_axi_arcache,
        s_axi_arprot 	=> s_axi_arprot,
        s_axi_arvalid 	=> s_axi_arvalid,
        s_axi_arready 	=> s_axi_arready,
        -- R Channel
        s_axi_rid 	=> s_axi_rid,
        s_axi_rdata 	=> s_axi_rdata,
        s_axi_rresp 	=> s_axi_rresp,
        s_axi_rlast 	=> s_axi_rlast,
        s_axi_rvalid 	=> s_axi_rvalid,
        s_axi_rready 	=> s_axi_rready
        );

    ddr3_dq           <= (others => 'Z');
    ddr3_dqs_p        <= (others => 'Z');
    ddr3_dqs_n        <= (others => 'Z');
    ddr3_addr         <= (others => '0');
    ddr3_ba           <= (others => '0');
    ddr3_ras_n        <= '0';
    ddr3_cas_n        <= '0';
    ddr3_we_n         <= '0';
    ddr3_reset_n      <= '1';
    ddr3_ck_p         <= (others => '0');
    ddr3_ck_n         <= (others => '0');
    ddr3_cke          <= (others => '0');
    ddr3_cs_n         <= (others => '0');
    ddr3_dm           <= (others => '0');
    ddr3_odt          <= (others => '0');

    calib_done <= '1';
    clkm <= not clkm after 5.0 ns;

    -- pragma translate_on
  end generate gen_mig_model;

-----------------------------------------------------------------------
---  ETHERNET ---------------------------------------------------------
-----------------------------------------------------------------------

  eth0 : if SIMULATION = false and CFG_GRETH = 1 generate -- Gaisler ethernet MAC
    e1 : grethm
      generic map(
        hindex => CFG_AHB_JTAG,
        ehindex => CFG_AHB_JTAG + 1,
        pindex => 6,
        paddr => 16#800#,
        pmask => 16#f00#,
        pirq => 12,
        memtech => CFG_FABTECH,
        little_end  => GLOB_CPU_RISCV * CFG_L2_DISABLE,
        rmii => 0,
        enable_mdio => 1,
        fifosize => CFG_ETH_FIFO,
        nsync => 2,
        edcl => CFG_DSU_ETH,
        edclbufsz => CFG_ETH_BUF,
        phyrstadr => 7,
        macaddrh => CFG_ETH_ENM,
        macaddrl => CFG_ETH_ENL,
        enable_mdint => 1,
        ipaddrh => CFG_ETH_IPM,
        ipaddrl => CFG_ETH_IPL,
        giga => CFG_GRETH1G,
        ramdebug => 0,
        gmiimode => 1,
        edclsepahbg => 1)
      port map(
        rst => rstn,
        clk => chip_refclk,
        mdcscaler => CPU_FREQ/1000,
        ahbmi => eth0_ahbmi,
        ahbmo => eth0_ahbmo,
        eahbmo => edcl_ahbmo,
        apbi => eth0_apbi,
        apbo => eth0_apbo,
        ethi => gmiii,
        etho => gmiio);

    sgmiirst <= not rstraw;

    sgmii0 : sgmii_vc707
      generic map(
        pindex          => 7,
        paddr           => 16#010#,
        pmask           => 16#ff0#,
        abits           => 8,
        autonegotiation => 1,
        pirq            => 11,
        debugmem        => 1,
        tech            => CFG_FABTECH,
        simulation      => SIMULATION
        )
      port map(
        sgmiii   => sgmiii,
        sgmiio   => sgmiio,
        gmiii    => gmiii,
        gmiio    => gmiio,
        reset    => sgmiirst,
        apb_clk  => chip_refclk,
        apb_rstn => rstn,
        apbi     => sgmii0_apbi,
        apbo     => sgmii0_apbo
        );

    emdio_pad : iopad generic map (tech => CFG_FABTECH, level => cmos, voltage => x18v)
      port map (emdio, sgmiio.mdio_o, sgmiio.mdio_oe, sgmiii.mdio_i);

    emdc_pad : outpad generic map (tech => CFG_FABTECH, level => cmos, voltage => x18v)
      port map (emdc, sgmiio.mdc);

    eint_pad : inpad generic map (tech => CFG_FABTECH, level => cmos, voltage => x18v)
      port map (eint, sgmiii.mdint);

    erst_pad : outpad generic map (tech => CFG_FABTECH, level => cmos, voltage => x18v)
      port map (erst, sgmiio.reset);

    sgmiii.clkp <= gtrefclk_p;
    sgmiii.clkn <= gtrefclk_n;
    txp         <= sgmiio.txp;
    txn         <= sgmiio.txn;
    sgmiii.rxp  <= rxp;
    sgmiii.rxn  <= rxn;

  end generate;

  no_eth0 : if SIMULATION = true or CFG_GRETH = 0 generate
    eth0_apbo <= apb_none;
    sgmii0_apbo <= apb_none;
    eth0_ahbmo <= ahbm_none;
    --edcl_ahbmo <= ahbm_none;
    txp <= '0';
    txn <= '1';
    emdc <= '0';
    erst <= '0';
    emdio <= '0';

    edcl_ahb_emu_i : edcl_ahbmst_emu
    generic map(
        hindex => CFG_AHB_JTAG+1
    )
    port map(
        clk => chip_refclk,
        reset => rstn,
        ahbmo => edcl_ahbmo,
        ahbmi => eth0_ahbmi,
        edcl_oen_ctrl => open
    );

  --no_eth0 : if SIMULATION = true or CFG_GRETH = 0 generate
  --  eth0_apbo <= apb_none;
  --  sgmii0_apbo <= apb_none;
  --  eth0_ahbmo <= ahbm_none;
  --  edcl_ahbmo <= ahbm_none;
  --  txp <= '0';
  --  txn <= '1';
  --  emdc <= '0';
  --  erst <= '0';
  --  emdio <= '0';
  end generate;

  -----------------------------------------------------------------------------
  -- CHIP
  -----------------------------------------------------------------------------
  chip_rst <= rstn;
  sys_clk(0) <= clkm;

  esp_1: esp
    generic map (
      SIMULATION => SIMULATION)
    port map (
      rst           => chip_rst,
      sys_clk       => sys_clk(0 to MEM_ID_RANGE_MSB),
      refclk        => chip_refclk,
      uart_rxd       => uart_rxd_int,
      uart_txd       => uart_txd_int,
      uart_ctsn      => uart_ctsn_int,
      uart_rtsn      => uart_rtsn_int,
      cpuerr         => cpuerr,
      -- AW Channel
      s_axi_awid 	=> s_axi_awid,
      s_axi_awaddr 	=> s_axi_awaddr,
      s_axi_awlen 	=> s_axi_awlen,
      s_axi_awsize 	=> s_axi_awsize,
      s_axi_awburst => s_axi_awburst,
      s_axi_awlock 	=> s_axi_awlock,
      s_axi_awcache => s_axi_awcache,
      s_axi_awprot 	=> s_axi_awprot,
      s_axi_awvalid => s_axi_awvalid,
      s_axi_awready => s_axi_awready,
      -- W Channel
      s_axi_wdata 	=> s_axi_wdata,
      s_axi_wstrb 	=> s_axi_wstrb,
      s_axi_wlast 	=> s_axi_wlast,
      s_axi_wvalid 	=> s_axi_wvalid,
      s_axi_wready 	=> s_axi_wready,
      -- B Channel
      s_axi_bid 	=> s_axi_bid,
      s_axi_bresp 	=> s_axi_bresp,
      s_axi_bvalid 	=> s_axi_bvalid,
      s_axi_bready 	=> s_axi_bready,
      -- AR Channel
      s_axi_arid 	=> s_axi_arid,
      s_axi_araddr 	=> s_axi_araddr,
      s_axi_arlen 	=> s_axi_arlen,
      s_axi_arsize 	=> s_axi_arsize,
      s_axi_arburst => s_axi_arburst,
      s_axi_arlock 	=> s_axi_arlock,
      s_axi_arcache => s_axi_arcache,
      s_axi_arprot 	=> s_axi_arprot,
      s_axi_arvalid => s_axi_arvalid,
      s_axi_arready => s_axi_arready,
      -- R Channel
      s_axi_rid 	=> s_axi_rid,
      s_axi_rdata 	=> s_axi_rdata,
      s_axi_rresp 	=> s_axi_rresp,
      s_axi_rlast 	=> s_axi_rlast,
      s_axi_rvalid 	=> s_axi_rvalid,
      s_axi_rready 	=> s_axi_rready,
      -- END
      eth0_ahbmi     	=> eth0_ahbmi,
      eth0_ahbmo     	=> eth0_ahbmo,
      edcl_ahbmo     	=> edcl_ahbmo,
      eth0_apbi      	=> eth0_apbi,
      eth0_apbo      	=> eth0_apbo,
      sgmii0_apbi    	=> sgmii0_apbi,
      sgmii0_apbo    	=> sgmii0_apbo,
      dvi_apbi       	=> dvi_apbi,
      dvi_apbo       	=> dvi_apbo,
      dvi_ahbmi      	=> dvi_ahbmi,
      dvi_ahbmo      	=> dvi_ahbmo);

 end;

