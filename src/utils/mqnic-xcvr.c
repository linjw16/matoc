/*

Copyright 2022, The Regents of the University of California.
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

   1. Redistributions of source code must retain the above copyright notice,
      this list of conditions and the following disclaimer.

   2. Redistributions in binary form must reproduce the above copyright notice,
      this list of conditions and the following disclaimer in the documentation
      and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE REGENTS OF THE UNIVERSITY OF CALIFORNIA ''AS
IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE REGENTS OF THE UNIVERSITY OF CALIFORNIA OR
CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT
OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING
IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY
OF SUCH DAMAGE.

The views and conclusions contained in the software and documentation are those
of the authors and should not be interpreted as representing official policies,
either expressed or implied, of The Regents of the University of California.

*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#include <mqnic/mqnic.h>
#include "xcvr_gtye4.h"

static void usage(char *name)
{
    fprintf(stderr,
        "usage: %s [options]\n"
        " -d name    device to open (/dev/mqnic0)\n"
        " -i number  GT channel index, default 0\n"
        " -s number  set GT speed\n"
        " -c file    CSV file for eye scan\n",
        name);
}


// 10G       25G       bits   addr      MSB    LSB
// 16'h0001, 16'h0000, 4'd0,  16'h0105, 4'd15, 4'd0,  // TX_PROGDIV_RATE
// 16'hE200, 16'hE218, 4'd0,  16'h0057, 4'd15, 4'd0,  // TX_PROGDIV_CFG
// 16'h0001, 16'h0003, 4'd2,  16'h00FB, 4'd2,  4'd1,  // TX_PI_BIASSET
// 16'h0000, 16'h0001, 4'd1,  16'h00FA, 4'd6,  4'd6,  // TXSWBST_EN
// 16'h1000, 16'h0000, 4'd0,  16'h00A8, 4'd15, 4'd0,  // TXPI_CFG1
// 16'h0300, 16'h3000, 4'd0,  16'h00A7, 4'd15, 4'd0,  // TXPI_CFG0
// 16'h6C00, 16'hF800, 4'd0,  16'h0054, 4'd15, 4'd0,  // TXFE_CFG3
// 16'h6C00, 16'hF800, 4'd0,  16'h0053, 4'd15, 4'd0,  // TXFE_CFG2
// 16'h6C00, 16'hF800, 4'd0,  16'h00A1, 4'd15, 4'd0,  // TXFE_CFG1
// 16'h03C2, 16'h03C6, 4'd0,  16'h009D, 4'd15, 4'd0,  // TXFE_CFG0
// 16'h0000, 16'h0003, 4'd2,  16'h00FA, 4'd10, 4'd9,  // TXDRV_FREQBAND
// 16'h0001, 16'h0000, 4'd1,  16'h00D3, 4'd1,  4'd1,  // RX_XMODE_SEL
// 16'h0001, 16'h0002, 4'd2,  16'h0066, 4'd3,  4'd2,  // RX_WIDEMODE_CDR
// 16'h0001, 16'h0000, 4'd0,  16'h0103, 4'd15, 4'd0,  // RX_PROGDIV_RATE
// 16'hE200, 16'hE218, 4'd0,  16'h00C6, 4'd15, 4'd0,  // RX_PROGDIV_CFG, for 33.0 and 16.5 57856 and 57880
// 16'h0054, 16'h0000, 4'd0,  16'h00D2, 4'd15, 4'd0,  // RXPI_CFG1
// 16'h0102, 16'h3006, 4'd0,  16'h0075, 4'd15, 4'd0,  // RXPI_CFG0
// 16'h4101, 16'h4120, 4'd0,  16'h00B0, 4'd15, 4'd0,  // RXDFE_KH_CFG3
// 16'h0200, 16'h281C, 4'd0,  16'h00B1, 4'd15, 4'd0,  // RXDFW_KH_CFG2
// 16'h0000, 16'h0004, 4'd0,  16'h010C, 4'd15, 4'd0,  // RXCKCAL2_X_LOOP_RST_CFG
// 16'h0000, 16'h0004, 4'd0,  16'h010D, 4'd15, 4'd0,  // RXCKCAL2_S_LOOP_RST_CFG
// 16'h0000, 16'h0004, 4'd0,  16'h010B, 4'd15, 4'd0,  // RXCKCAL2_D_LOOP_RST_CFG
// 16'h0000, 16'h0004, 4'd0,  16'h010E, 4'd15, 4'd0,  // RXCKCAL2_DX_LOOP_RST_CFG
// 16'h0000, 16'h0004, 4'd0,  16'h0109, 4'd15, 4'd0,  // RXCKCAL2_Q_LOOP_RST_CFG
// 16'h0000, 16'h0004, 4'd0,  16'h0108, 4'd15, 4'd0,  // RXCKCAL2_I_LOOP_RST_CFG
// 16'h0000, 16'h0004, 4'd0,  16'h010A, 4'd15, 4'd0,  // RXCKCAL2_IQ_LOOP_RST_CFG
// 16'h0012, 16'h0010, 4'd0,  16'h0011, 4'd15, 4'd0,  // RXCDR_CFG3
// 16'h0012, 16'h0010, 4'd0,  16'h011C, 4'd15, 4'd0,  // RXCDR_CFG3_GEN4
// 16'h0012, 16'h0010, 4'd0,  16'h00A5, 4'd15, 4'd0,  // RXCDR_CFG3_GEN3
// 16'h0012, 16'h0010, 4'd6,  16'h0135, 4'd15, 4'd10, // RXCDR_CFG3_GEN2
// 16'h0269, 16'h01E9, 4'd0,  16'h0010, 4'd15, 4'd0,  // RXCDR_CFG2
// 16'h0003, 16'h001F, 4'd5,  16'h00DD, 4'd4,  4'd0,  // RTX_BUF_TERM_CTRL, RTX_BUF_CML_CTRL
// 16'h0001, 16'h0003, 4'd2,  16'h00FB, 4'd5,  4'd4,  // PREIQ_FREQ_BST
// 16'h80C0, 16'h0040, 4'd0,  16'h0101, 4'd15, 4'd0,  // CKCAL2_CFG_1
// 16'hC0C0, 16'h4040, 4'd0,  16'h00F9, 4'd15, 4'd0,  // CKCAL2_CFG_0
// 16'h10C0, 16'h1040, 4'd0,  16'h00F8, 4'd15, 4'd0,  // CKCAL1_CFG_1
// 16'hC0C0, 16'h4040, 4'd0,  16'h00F7, 4'd15, 4'd0,  // CKCAL1_CFG_0
// 16'h4040, 16'h9090, 4'd0,  16'h0116, 4'd15, 4'd0   // CH_HSPMUX

const struct gt_reg_val gtye4_ch_10g_baser_64_dfe_regs[] =
{
    {GTYE4_CH_TX_PROGDIV_RATE_ADDR, GTYE4_CH_TX_PROGDIV_RATE_MASK, GTYE4_CH_TX_PROGDIV_RATE_LSB, GTYE4_CH_TX_PROGDIV_RATE_FULL},
    {GTYE4_CH_TX_PROGDIV_CFG_ADDR, GTYE4_CH_TX_PROGDIV_CFG_MASK, GTYE4_CH_TX_PROGDIV_CFG_LSB, GTYE4_CH_TX_PROGDIV_CFG_33},
    {GTYE4_CH_TX_PI_BIASSET_ADDR, GTYE4_CH_TX_PI_BIASSET_MASK, GTYE4_CH_TX_PI_BIASSET_LSB, 0x0001},
    {GTYE4_CH_TXSWBST_EN_ADDR, GTYE4_CH_TXSWBST_EN_MASK, GTYE4_CH_TXSWBST_EN_LSB, 0x0000},
    {GTYE4_CH_TXPI_CFG1_ADDR, GTYE4_CH_TXPI_CFG1_MASK, GTYE4_CH_TXPI_CFG1_LSB, 0x1000},
    {GTYE4_CH_TXPI_CFG0_ADDR, GTYE4_CH_TXPI_CFG0_MASK, GTYE4_CH_TXPI_CFG0_LSB, 0x0300},
    {GTYE4_CH_TXFE_CFG3_ADDR, GTYE4_CH_TXFE_CFG3_MASK, GTYE4_CH_TXFE_CFG3_LSB, 0x6C00},
    {GTYE4_CH_TXFE_CFG2_ADDR, GTYE4_CH_TXFE_CFG2_MASK, GTYE4_CH_TXFE_CFG2_LSB, 0x6C00},
    {GTYE4_CH_TXFE_CFG1_ADDR, GTYE4_CH_TXFE_CFG1_MASK, GTYE4_CH_TXFE_CFG1_LSB, 0x6C00},
    {GTYE4_CH_TXFE_CFG0_ADDR, GTYE4_CH_TXFE_CFG0_MASK, GTYE4_CH_TXFE_CFG0_LSB, 0x03C2},
    {GTYE4_CH_TXDRV_FREQBAND_ADDR, GTYE4_CH_TXDRV_FREQBAND_MASK, GTYE4_CH_TXDRV_FREQBAND_LSB, 0x0000},
    {GTYE4_CH_RX_XMODE_SEL_ADDR, GTYE4_CH_RX_XMODE_SEL_MASK, GTYE4_CH_RX_XMODE_SEL_LSB, 0x0001},
    {GTYE4_CH_RX_WIDEMODE_CDR_ADDR, GTYE4_CH_RX_WIDEMODE_CDR_MASK, GTYE4_CH_RX_WIDEMODE_CDR_LSB, 0x0001},
    {GTYE4_CH_RX_PROGDIV_RATE_ADDR, GTYE4_CH_RX_PROGDIV_RATE_MASK, GTYE4_CH_RX_PROGDIV_RATE_LSB, GTYE4_CH_RX_PROGDIV_RATE_FULL},
    {GTYE4_CH_RX_PROGDIV_CFG_ADDR, GTYE4_CH_RX_PROGDIV_CFG_MASK, GTYE4_CH_RX_PROGDIV_CFG_LSB, GTYE4_CH_RX_PROGDIV_CFG_33},
    {GTYE4_CH_RXPI_CFG1_ADDR, GTYE4_CH_RXPI_CFG1_MASK, GTYE4_CH_RXPI_CFG1_LSB, 0x0054},
    {GTYE4_CH_RXPI_CFG0_ADDR, GTYE4_CH_RXPI_CFG0_MASK, GTYE4_CH_RXPI_CFG0_LSB, 0x0102},
    {GTYE4_CH_RXDFE_KH_CFG3_ADDR, GTYE4_CH_RXDFE_KH_CFG3_MASK, GTYE4_CH_RXDFE_KH_CFG3_LSB, 0x4101},
    {GTYE4_CH_RXDFE_KH_CFG2_ADDR, GTYE4_CH_RXDFE_KH_CFG2_MASK, GTYE4_CH_RXDFE_KH_CFG2_LSB, 0x0200},
    {GTYE4_CH_RXCKCAL2_X_LOOP_RST_CFG_ADDR, GTYE4_CH_RXCKCAL2_X_LOOP_RST_CFG_MASK, GTYE4_CH_RXCKCAL2_X_LOOP_RST_CFG_LSB, 0x0000},
    {GTYE4_CH_RXCKCAL2_S_LOOP_RST_CFG_ADDR, GTYE4_CH_RXCKCAL2_S_LOOP_RST_CFG_MASK, GTYE4_CH_RXCKCAL2_S_LOOP_RST_CFG_LSB, 0x0000},
    {GTYE4_CH_RXCKCAL2_D_LOOP_RST_CFG_ADDR, GTYE4_CH_RXCKCAL2_D_LOOP_RST_CFG_MASK, GTYE4_CH_RXCKCAL2_D_LOOP_RST_CFG_LSB, 0x0000},
    {GTYE4_CH_RXCKCAL2_DX_LOOP_RST_CFG_ADDR, GTYE4_CH_RXCKCAL2_DX_LOOP_RST_CFG_MASK, GTYE4_CH_RXCKCAL2_DX_LOOP_RST_CFG_LSB, 0x0000},
    {GTYE4_CH_RXCKCAL1_Q_LOOP_RST_CFG_ADDR, GTYE4_CH_RXCKCAL1_Q_LOOP_RST_CFG_MASK, GTYE4_CH_RXCKCAL1_Q_LOOP_RST_CFG_LSB, 0x0000},
    {GTYE4_CH_RXCKCAL1_I_LOOP_RST_CFG_ADDR, GTYE4_CH_RXCKCAL1_I_LOOP_RST_CFG_MASK, GTYE4_CH_RXCKCAL1_I_LOOP_RST_CFG_LSB, 0x0000},
    {GTYE4_CH_RXCKCAL1_IQ_LOOP_RST_CFG_ADDR, GTYE4_CH_RXCKCAL1_IQ_LOOP_RST_CFG_MASK, GTYE4_CH_RXCKCAL1_IQ_LOOP_RST_CFG_LSB, 0x0000},
    {GTYE4_CH_RXCDR_CFG3_ADDR, GTYE4_CH_RXCDR_CFG3_MASK, GTYE4_CH_RXCDR_CFG3_LSB, 0x0012},
    {GTYE4_CH_RXCDR_CFG3_GEN4_ADDR, GTYE4_CH_RXCDR_CFG3_GEN4_MASK, GTYE4_CH_RXCDR_CFG3_GEN4_LSB, 0x0012},
    {GTYE4_CH_RXCDR_CFG3_GEN3_ADDR, GTYE4_CH_RXCDR_CFG3_GEN3_MASK, GTYE4_CH_RXCDR_CFG3_GEN3_LSB, 0x0012},
    {GTYE4_CH_RXCDR_CFG3_GEN2_ADDR, GTYE4_CH_RXCDR_CFG3_GEN2_MASK, GTYE4_CH_RXCDR_CFG3_GEN2_LSB, 0x0012},
    {GTYE4_CH_RXCDR_CFG2_ADDR, GTYE4_CH_RXCDR_CFG2_MASK, GTYE4_CH_RXCDR_CFG2_LSB, 0x0269},
    {GTYE4_CH_RTX_BUF_TERM_CTRL_ADDR, GTYE4_CH_RTX_BUF_TERM_CTRL_MASK, GTYE4_CH_RTX_BUF_TERM_CTRL_LSB, 0x0000},
    {GTYE4_CH_RTX_BUF_CML_CTRL_ADDR, GTYE4_CH_RTX_BUF_CML_CTRL_MASK, GTYE4_CH_RTX_BUF_CML_CTRL_LSB, 0x0003},
    {GTYE4_CH_PREIQ_FREQ_BST_ADDR, GTYE4_CH_PREIQ_FREQ_BST_MASK, GTYE4_CH_PREIQ_FREQ_BST_LSB, 0x0001},
    {GTYE4_CH_CKCAL2_CFG_1_ADDR, GTYE4_CH_CKCAL2_CFG_1_MASK, GTYE4_CH_CKCAL2_CFG_1_LSB, 0x80C0},
    {GTYE4_CH_CKCAL2_CFG_0_ADDR, GTYE4_CH_CKCAL2_CFG_0_MASK, GTYE4_CH_CKCAL2_CFG_0_LSB, 0xC0C0},
    {GTYE4_CH_CKCAL1_CFG_1_ADDR, GTYE4_CH_CKCAL1_CFG_1_MASK, GTYE4_CH_CKCAL1_CFG_1_LSB, 0x10C0},
    {GTYE4_CH_CKCAL1_CFG_0_ADDR, GTYE4_CH_CKCAL1_CFG_0_MASK, GTYE4_CH_CKCAL1_CFG_0_LSB, 0xC0C0},
    {GTYE4_CH_CH_HSPMUX_ADDR, GTYE4_CH_CH_HSPMUX_MASK, GTYE4_CH_CH_HSPMUX_LSB, 0x4040},
    {0, 0, 0, 0}
};

const struct gt_reg_val gtye4_ch_25g_baser_64_dfe_regs[] =
{
    {GTYE4_CH_TX_PROGDIV_RATE_ADDR, GTYE4_CH_TX_PROGDIV_RATE_MASK, GTYE4_CH_TX_PROGDIV_RATE_LSB, GTYE4_CH_TX_PROGDIV_RATE_HALF},
    {GTYE4_CH_TX_PROGDIV_CFG_ADDR, GTYE4_CH_TX_PROGDIV_CFG_MASK, GTYE4_CH_TX_PROGDIV_CFG_LSB, GTYE4_CH_TX_PROGDIV_CFG_16P5},
    {GTYE4_CH_TX_PI_BIASSET_ADDR, GTYE4_CH_TX_PI_BIASSET_MASK, GTYE4_CH_TX_PI_BIASSET_LSB, 0x0003},
    {GTYE4_CH_TXSWBST_EN_ADDR, GTYE4_CH_TXSWBST_EN_MASK, GTYE4_CH_TXSWBST_EN_LSB, 0x0001},
    {GTYE4_CH_TXPI_CFG1_ADDR, GTYE4_CH_TXPI_CFG1_MASK, GTYE4_CH_TXPI_CFG1_LSB, 0x0000},
    {GTYE4_CH_TXPI_CFG0_ADDR, GTYE4_CH_TXPI_CFG0_MASK, GTYE4_CH_TXPI_CFG0_LSB, 0x3000},
    {GTYE4_CH_TXFE_CFG3_ADDR, GTYE4_CH_TXFE_CFG3_MASK, GTYE4_CH_TXFE_CFG3_LSB, 0xF800},
    {GTYE4_CH_TXFE_CFG2_ADDR, GTYE4_CH_TXFE_CFG2_MASK, GTYE4_CH_TXFE_CFG2_LSB, 0xF800},
    {GTYE4_CH_TXFE_CFG1_ADDR, GTYE4_CH_TXFE_CFG1_MASK, GTYE4_CH_TXFE_CFG1_LSB, 0xF800},
    {GTYE4_CH_TXFE_CFG0_ADDR, GTYE4_CH_TXFE_CFG0_MASK, GTYE4_CH_TXFE_CFG0_LSB, 0x03C6},
    {GTYE4_CH_TXDRV_FREQBAND_ADDR, GTYE4_CH_TXDRV_FREQBAND_MASK, GTYE4_CH_TXDRV_FREQBAND_LSB, 0x0003},
    {GTYE4_CH_RX_XMODE_SEL_ADDR, GTYE4_CH_RX_XMODE_SEL_MASK, GTYE4_CH_RX_XMODE_SEL_LSB, 0x0000},
    {GTYE4_CH_RX_WIDEMODE_CDR_ADDR, GTYE4_CH_RX_WIDEMODE_CDR_MASK, GTYE4_CH_RX_WIDEMODE_CDR_LSB, 0x0002},
    {GTYE4_CH_RX_PROGDIV_RATE_ADDR, GTYE4_CH_RX_PROGDIV_RATE_MASK, GTYE4_CH_RX_PROGDIV_RATE_LSB, GTYE4_CH_RX_PROGDIV_RATE_HALF},
    {GTYE4_CH_RX_PROGDIV_CFG_ADDR, GTYE4_CH_RX_PROGDIV_CFG_MASK, GTYE4_CH_RX_PROGDIV_CFG_LSB, GTYE4_CH_RX_PROGDIV_CFG_16P5},
    {GTYE4_CH_RXPI_CFG1_ADDR, GTYE4_CH_RXPI_CFG1_MASK, GTYE4_CH_RXPI_CFG1_LSB, 0x0000},
    {GTYE4_CH_RXPI_CFG0_ADDR, GTYE4_CH_RXPI_CFG0_MASK, GTYE4_CH_RXPI_CFG0_LSB, 0x3006},
    {GTYE4_CH_RXDFE_KH_CFG3_ADDR, GTYE4_CH_RXDFE_KH_CFG3_MASK, GTYE4_CH_RXDFE_KH_CFG3_LSB, 0x4120},
    {GTYE4_CH_RXDFE_KH_CFG2_ADDR, GTYE4_CH_RXDFE_KH_CFG2_MASK, GTYE4_CH_RXDFE_KH_CFG2_LSB, 0x281C},
    {GTYE4_CH_RXCKCAL2_X_LOOP_RST_CFG_ADDR, GTYE4_CH_RXCKCAL2_X_LOOP_RST_CFG_MASK, GTYE4_CH_RXCKCAL2_X_LOOP_RST_CFG_LSB, 0x0004},
    {GTYE4_CH_RXCKCAL2_S_LOOP_RST_CFG_ADDR, GTYE4_CH_RXCKCAL2_S_LOOP_RST_CFG_MASK, GTYE4_CH_RXCKCAL2_S_LOOP_RST_CFG_LSB, 0x0004},
    {GTYE4_CH_RXCKCAL2_D_LOOP_RST_CFG_ADDR, GTYE4_CH_RXCKCAL2_D_LOOP_RST_CFG_MASK, GTYE4_CH_RXCKCAL2_D_LOOP_RST_CFG_LSB, 0x0004},
    {GTYE4_CH_RXCKCAL2_DX_LOOP_RST_CFG_ADDR, GTYE4_CH_RXCKCAL2_DX_LOOP_RST_CFG_MASK, GTYE4_CH_RXCKCAL2_DX_LOOP_RST_CFG_LSB, 0x0004},
    {GTYE4_CH_RXCKCAL1_Q_LOOP_RST_CFG_ADDR, GTYE4_CH_RXCKCAL1_Q_LOOP_RST_CFG_MASK, GTYE4_CH_RXCKCAL1_Q_LOOP_RST_CFG_LSB, 0x0004},
    {GTYE4_CH_RXCKCAL1_I_LOOP_RST_CFG_ADDR, GTYE4_CH_RXCKCAL1_I_LOOP_RST_CFG_MASK, GTYE4_CH_RXCKCAL1_I_LOOP_RST_CFG_LSB, 0x0004},
    {GTYE4_CH_RXCKCAL1_IQ_LOOP_RST_CFG_ADDR, GTYE4_CH_RXCKCAL1_IQ_LOOP_RST_CFG_MASK, GTYE4_CH_RXCKCAL1_IQ_LOOP_RST_CFG_LSB, 0x0004},
    {GTYE4_CH_RXCDR_CFG3_ADDR, GTYE4_CH_RXCDR_CFG3_MASK, GTYE4_CH_RXCDR_CFG3_LSB, 0x0010},
    {GTYE4_CH_RXCDR_CFG3_GEN4_ADDR, GTYE4_CH_RXCDR_CFG3_GEN4_MASK, GTYE4_CH_RXCDR_CFG3_GEN4_LSB, 0x0010},
    {GTYE4_CH_RXCDR_CFG3_GEN3_ADDR, GTYE4_CH_RXCDR_CFG3_GEN3_MASK, GTYE4_CH_RXCDR_CFG3_GEN3_LSB, 0x0010},
    {GTYE4_CH_RXCDR_CFG3_GEN2_ADDR, GTYE4_CH_RXCDR_CFG3_GEN2_MASK, GTYE4_CH_RXCDR_CFG3_GEN2_LSB, 0x0010},
    {GTYE4_CH_RXCDR_CFG2_ADDR, GTYE4_CH_RXCDR_CFG2_MASK, GTYE4_CH_RXCDR_CFG2_LSB, 0x01E9},
    {GTYE4_CH_RTX_BUF_TERM_CTRL_ADDR, GTYE4_CH_RTX_BUF_TERM_CTRL_MASK, GTYE4_CH_RTX_BUF_TERM_CTRL_LSB, 0x0003},
    {GTYE4_CH_RTX_BUF_CML_CTRL_ADDR, GTYE4_CH_RTX_BUF_CML_CTRL_MASK, GTYE4_CH_RTX_BUF_CML_CTRL_LSB, 0x0007},
    {GTYE4_CH_PREIQ_FREQ_BST_ADDR, GTYE4_CH_PREIQ_FREQ_BST_MASK, GTYE4_CH_PREIQ_FREQ_BST_LSB, 0x0003},
    {GTYE4_CH_CKCAL2_CFG_1_ADDR, GTYE4_CH_CKCAL2_CFG_1_MASK, GTYE4_CH_CKCAL2_CFG_1_LSB, 0x0040},
    {GTYE4_CH_CKCAL2_CFG_0_ADDR, GTYE4_CH_CKCAL2_CFG_0_MASK, GTYE4_CH_CKCAL2_CFG_0_LSB, 0x4040},
    {GTYE4_CH_CKCAL1_CFG_1_ADDR, GTYE4_CH_CKCAL1_CFG_1_MASK, GTYE4_CH_CKCAL1_CFG_1_LSB, 0x1040},
    {GTYE4_CH_CKCAL1_CFG_0_ADDR, GTYE4_CH_CKCAL1_CFG_0_MASK, GTYE4_CH_CKCAL1_CFG_0_LSB, 0x4040},
    {GTYE4_CH_CH_HSPMUX_ADDR, GTYE4_CH_CH_HSPMUX_MASK, GTYE4_CH_CH_HSPMUX_LSB, 0x9090},
    {0, 0, 0, 0}
};

int main(int argc, char *argv[])
{
    char *name;
    int opt;
    int ret = 0;

    char *device = NULL;
    struct mqnic *dev;
    int channel_index = 0;
    int channel_speed = 0;

    char *csv_file_name = NULL;
    FILE *csv_file = NULL;

    name = strrchr(argv[0], '/');
    name = name ? 1+name : argv[0];

    while ((opt = getopt(argc, argv, "d:i:s:c:h?")) != EOF)
    {
        switch (opt)
        {
        case 'd':
            device = optarg;
            break;
        case 'i':
            channel_index = atoi(optarg);
            break;
        case 's':
            channel_speed = atoi(optarg);
            break;
        case 'c':
            csv_file_name = optarg;
            break;
        case 'h':
        case '?':
            usage(name);
            return 0;
        default:
            usage(name);
            return -1;
        }
    }

    if (!device)
    {
        fprintf(stderr, "Device not specified\n");
        usage(name);
        return -1;
    }

    dev = mqnic_open(device);

    if (!dev)
    {
        fprintf(stderr, "Failed to open device\n");
        return -1;
    }

    if (dev->pci_device_path)
    {
        char *ptr = strrchr(dev->pci_device_path, '/');
        if (ptr)
            printf("PCIe ID: %s\n", ptr+1);
    }

    printf("Device-level register blocks:\n");
    for (struct mqnic_reg_block *rb = dev->rb_list; rb->type && rb->version; rb++)
        printf(" type 0x%08x (v %d.%d.%d.%d)\n", rb->type, rb->version >> 24, 
                (rb->version >> 16) & 0xff, (rb->version >> 8) & 0xff, rb->version & 0xff);

    mqnic_print_fw_id(dev);

    struct gt_ch *ch;
    struct gt_pll *pll;
    struct gt_pll gt_plls[32];
    struct gt_ch gt_channels[128];
    int num_quads = 0;
    int num_channels = 0;

    uint32_t val;

    printf("Enumerate transceivers\n");
    for (int k = 0; k < 128; k++)
    {
        struct mqnic_reg_block *rb;
        uint32_t info;

        rb = mqnic_find_reg_block(dev->rb_list, 0x0000C150, 0x00000100, k);

        if (!rb)
            break;

        printf("Found DRP interface %d\n", k);

        info = mqnic_reg_read32(rb->regs, 0x0C);

        printf("info: 0x%08x\n", info);

        printf("Found GTYE4 quad\n");

        gt_plls[num_quads].drp_rb = rb;
        num_quads++;

        for (int n = 0; n < (info & 0xFF); n++)
        {
            printf("GT channel %d: DRP index %d, quad %d, quad index %d\n", num_channels, k, num_quads-1, n);
            gt_channels[num_channels].pll = &gt_plls[num_quads-1];
            gt_channels[num_channels].drp_rb = rb;
            gt_channels[num_channels].index = n;
            gt_channels[num_channels].quad_index = num_quads-1;
            num_channels++;

            if (num_channels >= 128)
                break;
        }
    }

    if (channel_index >= num_channels)
    {
        fprintf(stderr, "Channel index out of range\n");
        ret = -1;
        goto err;
    }

    ch = &gt_channels[channel_index];
    pll = ch->pll;

    printf("PLL information\n");

    gtye4_pll_get_qpll0_reset(pll, &val);
    printf("QPLL0 reset: %d\n", val);
    gtye4_pll_get_qpll0_pd(pll, &val);
    printf("QPLL0 PD: %d\n", val);
    gtye4_pll_get_qpll0_lock(pll, &val);
    printf("QPLL0 lock: %d\n", val);

    gtye4_pll_get_qpll1_reset(pll, &val);
    printf("QPLL1 reset: %d\n", val);
    gtye4_pll_get_qpll1_pd(pll, &val);
    printf("QPLL1 PD: %d\n", val);
    gtye4_pll_get_qpll1_lock(pll, &val);
    printf("QPLL1 lock: %d\n", val);

    printf("Channel information\n");

    gtye4_ch_get_tx_reset(ch, &val);
    printf("TX reset: %d\n", val);
    gtye4_ch_get_tx_reset_done(ch, &val);
    printf("TX reset done: %d\n", val);
    gtye4_ch_get_tx_gt_reset_done(ch, &val);
    printf("TX GT reset done: %d\n", val);
    gtye4_ch_get_tx_pma_reset_done(ch, &val);
    printf("TX PMA reset done: %d\n", val);
    gtye4_ch_get_tx_prgdiv_reset_done(ch, &val);
    printf("TX PRGDIV reset done: %d\n", val);
    gtye4_ch_get_tx_pd(ch, &val);
    printf("TX PD: %d\n", val);
    gtye4_ch_get_tx_qpll_sel(ch, &val);
    printf("TX QPLL sel: %d\n", val);
    gtye4_ch_get_tx_polarity(ch, &val);
    printf("TX polarity: %d\n", val);
    gtye4_ch_get_tx_elecidle(ch, &val);
    printf("TX elecidle: %d\n", val);
    gtye4_ch_get_tx_inhibit(ch, &val);
    printf("TX inhibit: %d\n", val);
    gtye4_ch_get_tx_diffctrl(ch, &val);
    printf("TX diffctl: %d\n", val);
    gtye4_ch_get_tx_maincursor(ch, &val);
    printf("TX maincursor: %d\n", val);
    gtye4_ch_get_tx_precursor(ch, &val);
    printf("TX precursor: %d\n", val);
    gtye4_ch_get_tx_postcursor(ch, &val);
    printf("TX postcursor: %d\n", val);
    gtye4_ch_get_tx_prbs_sel(ch, &val);
    printf("TX PRBS sel: %d\n", val);

    gtye4_ch_get_rx_reset(ch, &val);
    printf("RX reset: %d\n", val);
    gtye4_ch_get_rx_reset_done(ch, &val);
    printf("RX reset done: %d\n", val);
    gtye4_ch_get_rx_gt_reset_done(ch, &val);
    printf("RX GT reset done: %d\n", val);
    gtye4_ch_get_rx_pma_reset_done(ch, &val);
    printf("RX PMA reset done: %d\n", val);
    gtye4_ch_get_rx_prgdiv_reset_done(ch, &val);
    printf("RX PRGDIV reset done: %d\n", val);
    gtye4_ch_get_rx_pd(ch, &val);
    printf("RX PD: %d\n", val);
    gtye4_ch_get_rx_qpll_sel(ch, &val);
    printf("RX QPLL sel: %d\n", val);
    gtye4_ch_get_loopback(ch, &val);
    printf("Loopback: %d\n", val);
    gtye4_ch_get_rx_polarity(ch, &val);
    printf("RX polarity: %d\n", val);
    gtye4_ch_get_rx_cdr_hold(ch, &val);
    printf("RX CDR hold: %d\n", val);
    gtye4_ch_get_rx_cdr_lock(ch, &val);
    printf("RX CDR lock: %d\n", val);
    gtye4_ch_get_rx_lpm_en(ch, &val);
    printf("RX LPM enable: %d\n", val);
    gtye4_ch_get_rx_dmonitor(ch, &val);
    printf("RX dmonitor: %d\n", val);
    gtye4_ch_get_rx_prbs_sel(ch, &val);
    printf("RX PRBS sel: %d\n", val);
    gtye4_ch_get_rx_prbs_locked(ch, &val);
    printf("RX PRBS locked: %d\n", val);

    gtye4_ch_get_tx_data_width(ch, &val);
    printf("TX data width: %d\n", val);
    gtye4_ch_get_tx_int_data_width(ch, &val);
    printf("TX int data width: %d\n", val);
    gtye4_ch_get_rx_data_width(ch, &val);
    printf("RX data width: %d\n", val);
    gtye4_ch_get_rx_int_data_width(ch, &val);
    printf("RX int data width: %d\n", val);

    // gt_ch_reg_read(ch, GTYE4_CH_TX_RESET_ADDR, &val);
    // printf("TX reset reg: 0x%04x\n", val);
    // gt_ch_reg_read(ch, GTYE4_CH_RX_RESET_ADDR, &val);
    // printf("RX reset reg: 0x%04x\n", val);

    // gt_ch_reg_read(ch, 0x12000, &val);
    // printf("TX DBG 0: 0x%04x\n", val);
    // gt_ch_reg_read(ch, 0x12001, &val);
    // printf("TX DBG 1: 0x%04x\n", val);
    // gt_ch_reg_read(ch, 0x12002, &val);
    // printf("TX DBG 2: 0x%04x\n", val);

    // gt_ch_reg_read(ch, 0x12100, &val);
    // printf("RX DBG 0: 0x%04x\n", val);
    // gt_ch_reg_read(ch, 0x12101, &val);
    // printf("RX DBG 1: 0x%04x\n", val);
    // gt_ch_reg_read(ch, 0x12102, &val);
    // printf("RX DBG 2: 0x%04x\n", val);
    // gt_ch_reg_read(ch, 0x12104, &val);
    // printf("RX DBG 4: 0x%04x\n", val);
    // gt_ch_reg_read(ch, 0x12105, &val);
    // printf("RX DBG 5: 0x%04x\n", val);

    gt_ch_reg_read(ch, 0x18000, &val);
    printf("PHY TX status 0: %d\n", val);
    gt_ch_reg_read(ch, 0x18001, &val);
    printf("PHY TX status 1: %d\n", val);
    gt_ch_reg_read(ch, 0x18100, &val);
    printf("PHY RX status 0: %d\n", val);
    gt_ch_reg_read(ch, 0x18101, &val);
    printf("PHY RX status 1: %d\n", val);

    if (channel_speed == 10)
    {
        printf("Configure for 10G\n");

        gtye4_pll_set_qpll1_pd(pll, 0);

        gtye4_ch_set_tx_reset(ch, 1);
        gtye4_ch_set_rx_reset(ch, 1);

        gtye4_ch_set_tx_qpll_sel(ch, 1);
        gtye4_ch_set_rx_qpll_sel(ch, 1);

        gt_ch_reg_write_multiple(ch, gtye4_ch_10g_baser_64_dfe_regs);

        gtye4_ch_set_tx_reset(ch, 0);
        gtye4_ch_set_rx_reset(ch, 0);
    }

    if (channel_speed == 25)
    {
        printf("Configure for 25G\n");

        gtye4_ch_set_tx_reset(ch, 1);
        gtye4_ch_set_rx_reset(ch, 1);

        gtye4_ch_set_tx_qpll_sel(ch, 0);
        gtye4_ch_set_rx_qpll_sel(ch, 0);

        gt_ch_reg_write_multiple(ch, gtye4_ch_25g_baser_64_dfe_regs);

        gtye4_ch_set_tx_reset(ch, 0);
        gtye4_ch_set_rx_reset(ch, 0);
    }
	/*
		printf("PLL registers\n");

		for (int k = 0; k <= 0xB0; k++)
		{
			gt_pll_reg_read(pll, k, &val);
			printf("0x%04x: 0x%04x\n", k, val);
		}

		printf("Channel registers\n");

		for (int k = 0; k <= 0x28C; k++)
		{
			gt_ch_reg_read(ch, k, &val);
			printf("0x%04x: 0x%04x\n", k, val);
		}
	*/
	if (csv_file_name)
    {
        int prescale = 4;
        int horz_start = -32;
        int horz_stop = 32;
        int horz_step = 4;
        int vert_start = -32;
        int vert_stop = 32;
        int vert_step = 4;
        int vs_range = 0;

        uint32_t data_width;
        uint32_t int_data_width;

        uint32_t error_count;
        uint32_t sample_count;
        uint32_t bit_count;
        float ber;

        int restart;

        printf("Measuring eye to %s\n", csv_file_name);

        csv_file = fopen(csv_file_name, "w");

        fprintf(csv_file, "#eyescan\n");

        time_t cur_time;
        struct tm *tm_info;
        char buffer[32];

        time(&cur_time);
        tm_info = localtime(&cur_time);
        strftime(buffer, sizeof(buffer), "%F %T", tm_info);

        fprintf(csv_file, "#date,'%s'\n", buffer);

        fprintf(csv_file, "#fpga_id,0x%08x\n", dev->fpga_id);
        fprintf(csv_file, "#fw_id,0x%08x\n", dev->fw_id);
        fprintf(csv_file, "#fw_version,'%d.%d.%d.%d'\n", dev->fw_ver >> 24,
                (dev->fw_ver >> 16) & 0xff,
                (dev->fw_ver >> 8) & 0xff,
                dev->fw_ver & 0xff);
        fprintf(csv_file, "#board_id,0x%08x\n", dev->board_id);
        fprintf(csv_file, "#board_version,'%d.%d.%d.%d'\n", dev->board_ver >> 24,
                (dev->board_ver >> 16) & 0xff,
                (dev->board_ver >> 8) & 0xff,
                dev->board_ver & 0xff);
        fprintf(csv_file, "#build_date,'%s UTC'\n", dev->build_date_str);
        fprintf(csv_file, "#git_hash,'%08x'\n", dev->git_hash);
        fprintf(csv_file, "#release_info,'%08x'\n", dev->rel_info);

        fprintf(csv_file, "#channel_index,%d\n", channel_index);
        fprintf(csv_file, "#channel_type,GTYE4\n");
        fprintf(csv_file, "#quad,%d\n", ch->quad_index);
        fprintf(csv_file, "#channel,%d\n", ch->index);

        printf("Init for eye scan\n");

        gtye4_ch_get_rx_data_width(ch, &data_width);
        gtye4_ch_get_rx_int_data_width(ch, &int_data_width);

        printf("Data width: %d\n", data_width);
        printf("Int data width: %d\n", int_data_width);

        fprintf(csv_file, "#data_width,%d\n", data_width);
        fprintf(csv_file, "#int_data_width,%d\n", int_data_width);
        fprintf(csv_file, "#prescale,%d\n", 1 << (prescale+1));
        fprintf(csv_file, "#vert_range,%d\n", vs_range);
        fprintf(csv_file, "horiz_offset,vert_offset,ut_sign,bit_count,error_count\n");

        gtye4_ch_set_es_control(ch, 0x00);

        gtye4_ch_set_es_prescale(ch, 4);
        gtye4_ch_set_es_errdet_en(ch, 1);

        gtye4_ch_set_es_qual_mask_clear(ch);
        gtye4_ch_set_es_sdata_mask_width(ch, int_data_width);

        gtye4_ch_set_rx_eyescan_vs_range(ch, 0);

        gtye4_ch_set_es_horz_offset(ch, 0x800);
        gtye4_ch_set_rx_eyescan_vs_neg_dir(ch, 0);
        gtye4_ch_set_rx_eyescan_vs_code(ch, 0);
        gtye4_ch_set_rx_eyescan_vs_ut_sign(ch, 0);

        gtye4_ch_set_es_eye_scan_en(ch, 1);

        gtye4_ch_rx_pma_reset(ch);

        for (int ber_tries = 0; ber_tries < 10; ber_tries++)
        {
            for (int reset_tries = 0; reset_tries < 30; reset_tries++)
            {
                gtye4_ch_get_rx_reset_done(ch, &val);
                if (val)
                    break;
                usleep(100000);
            }

            if (!val)
            {
                fprintf(stderr, "Error: channel stuck in reset\n");
                ret = -1;
                goto err;
            }

            usleep(100000);

            // check for lock
            gtye4_ch_set_es_control(ch, 0x01);

            for (int wait_tries = 0; wait_tries < 30; wait_tries++)
            {
                gtye4_ch_get_es_control_status(ch, &val);
                if (val & 1)
                    break;
                usleep(100000);
            }

            if (!(val & 1))
            {
                fprintf(stderr, "Error: eye scan did not finish (%d)\n", val);
                ret = -1;
                goto err;
            }

            gtye4_ch_set_es_control(ch, 0x00);

            gtye4_ch_get_es_error_count(ch, &error_count);
            gtye4_ch_get_es_sample_count(ch, &sample_count);
            sample_count = sample_count * (1 << (1+4));
            bit_count = sample_count * int_data_width;

            ber = (float)error_count / (float)bit_count;

            if (ber < 0.01)
                break;

            printf("High BER (%02f), resetting eye scan logic\n", ber);

            gtye4_ch_set_es_horz_offset(ch, 0x880);
            gtye4_ch_set_eyescan_reset(ch, 1);
            gtye4_ch_set_es_horz_offset(ch, 0x800);
            gtye4_ch_set_eyescan_reset(ch, 0);
        }

        if (ber > 0.01)
        {
            fprintf(stderr, "Error: High BER, alignment failed\n");
            ret = -1;
            goto err;
        }

        // set up for measurement
        int horz_offset = horz_start;
        int vert_offset = vert_start;
        int ut_sign = 0;

        gtye4_ch_set_es_control(ch, 0x00);
        gtye4_ch_set_es_prescale(ch, prescale);
        gtye4_ch_set_es_errdet_en(ch, 1);
        gtye4_ch_set_es_horz_offset(ch, (horz_offset & 0x7ff) | 0x800);
        gtye4_ch_set_rx_eyescan_vs_neg_dir(ch, (vert_offset < 0));
        gtye4_ch_set_rx_eyescan_vs_code(ch, vert_offset < 0 ? -vert_offset : vert_offset);
        gtye4_ch_set_rx_eyescan_vs_ut_sign(ch, ut_sign);

        // start measurement
        printf("Start eye scan\n");

        gtye4_ch_set_es_control(ch, 0x01);

        while (1)
        {
            for (int wait_tries = 0; wait_tries < 3000; wait_tries++)
            {
                gtye4_ch_get_es_control_status(ch, &val);
                if (val & 1)
                    break;
                usleep(1000);
            }

            if (!(val & 1))
            {
                fprintf(stderr, "Error: eye scan did not finish (%d)\n", val);
                ret = -1;
                goto err;
            }

            gtye4_ch_set_es_control(ch, 0x00);

            gtye4_ch_get_es_error_count(ch, &error_count);
            gtye4_ch_get_es_sample_count(ch, &sample_count);
            sample_count = sample_count * (1 << (1+4));
            bit_count = sample_count * int_data_width;

            printf("%d,%d,%d,%d,%d\n", horz_offset, vert_offset, ut_sign, bit_count, error_count);

            fprintf(csv_file, "%d,%d,%d,%d,%d\n", horz_offset, vert_offset, ut_sign, bit_count, error_count);

            restart = 0;

            if (!ut_sign)
            {
                ut_sign = 1;
                restart = 1;
            }
            else
            {
                ut_sign = 0;
            }

            gtye4_ch_set_rx_eyescan_vs_ut_sign(ch, ut_sign);

            if (restart)
            {
                gtye4_ch_set_es_control(ch, 0x01);
                continue;
            }

            if (vert_offset < vert_stop)
            {
                vert_offset += vert_step;
                restart = 1;
            }
            else
            {
                vert_offset = vert_start;
            }

            gtye4_ch_set_rx_eyescan_vs_neg_dir(ch, (vert_offset < 0));
            gtye4_ch_set_rx_eyescan_vs_code(ch, vert_offset < 0 ? -vert_offset : vert_offset);

            if (restart)
            {
                gtye4_ch_set_es_control(ch, 0x01);
                continue;
            }

            if (horz_offset < horz_stop)
            {
                horz_offset += horz_step;
                restart = 1;
            }
            else
            {
                break;
            }

            gtye4_ch_set_es_horz_offset(ch, (horz_offset & 0x7ff) | 0x800);

            if (restart)
            {
                gtye4_ch_set_es_control(ch, 0x01);
                continue;
            }
        }

        printf("Done\n");
    }

err:

    mqnic_close(dev);

    return ret;
}
