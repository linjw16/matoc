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

#ifndef XCVR_GTYE3_H
#define XCVR_GTYE3_H

#include "xcvr_gt.h"
#include "gt/gtye3_regs.h"

// signals
def_gt_ch_masked_reg_rw16(gtye3, tx_pma_reset, 0x10000, 0x0001, 0);
int gtye3_ch_tx_pma_reset(struct gt_ch *ch);
def_gt_ch_masked_reg_read16(gtye3, tx_reset_done, 0x10000, 0x0100, 8);

def_gt_ch_masked_reg_rw16(gtye3, rx_pma_reset, 0x10001, 0x0001, 0);
int gtye3_ch_rx_pma_reset(struct gt_ch *ch);
def_gt_ch_masked_reg_read16(gtye3, rx_reset_done, 0x10001, 0x0100, 8);

// common
def_gt_pll_masked_reg_rw16(gtye3, qpll0_cfg0, GTYE3_COM_QPLL0_CFG0_ADDR, GTYE3_COM_QPLL0_CFG0_MASK, GTYE3_COM_QPLL0_CFG0_LSB);
def_gt_pll_masked_reg_rw16(gtye3, common_cfg0, GTYE3_COM_COMMON_CFG0_ADDR, GTYE3_COM_COMMON_CFG0_MASK, GTYE3_COM_COMMON_CFG0_LSB);
def_gt_pll_masked_reg_rw16(gtye3, rsvd_attr0, GTYE3_COM_RSVD_ATTR0_ADDR, GTYE3_COM_RSVD_ATTR0_MASK, GTYE3_COM_RSVD_ATTR0_LSB);
def_gt_pll_masked_reg_rw16(gtye3, ppf0_cfg, GTYE3_COM_PPF0_CFG_ADDR, GTYE3_COM_PPF0_CFG_MASK, GTYE3_COM_PPF0_CFG_LSB);
def_gt_pll_masked_reg_rw16(gtye3, qpll0clkout_rate, GTYE3_COM_QPLL0CLKOUT_RATE_ADDR, GTYE3_COM_QPLL0CLKOUT_RATE_MASK, GTYE3_COM_QPLL0CLKOUT_RATE_LSB);
def_gt_pll_masked_reg_rw16(gtye3, qpll0_cfg1, GTYE3_COM_QPLL0_CFG1_ADDR, GTYE3_COM_QPLL0_CFG1_MASK, GTYE3_COM_QPLL0_CFG1_LSB);
def_gt_pll_masked_reg_rw16(gtye3, qpll0_cfg2, GTYE3_COM_QPLL0_CFG2_ADDR, GTYE3_COM_QPLL0_CFG2_MASK, GTYE3_COM_QPLL0_CFG2_LSB);
def_gt_pll_masked_reg_rw16(gtye3, qpll0_lock_cfg, GTYE3_COM_QPLL0_LOCK_CFG_ADDR, GTYE3_COM_QPLL0_LOCK_CFG_MASK, GTYE3_COM_QPLL0_LOCK_CFG_LSB);
def_gt_pll_masked_reg_rw16(gtye3, qpll0_init_cfg0, GTYE3_COM_QPLL0_INIT_CFG0_ADDR, GTYE3_COM_QPLL0_INIT_CFG0_MASK, GTYE3_COM_QPLL0_INIT_CFG0_LSB);
def_gt_pll_masked_reg_rw16(gtye3, qpll0_init_cfg1, GTYE3_COM_QPLL0_INIT_CFG1_ADDR, GTYE3_COM_QPLL0_INIT_CFG1_MASK, GTYE3_COM_QPLL0_INIT_CFG1_LSB);
def_gt_pll_masked_reg_rw16(gtye3, qpll0_fbdiv, GTYE3_COM_QPLL0_FBDIV_ADDR, GTYE3_COM_QPLL0_FBDIV_MASK, GTYE3_COM_QPLL0_FBDIV_LSB);
def_gt_pll_masked_reg_rw16(gtye3, qpll0_cfg3, GTYE3_COM_QPLL0_CFG3_ADDR, GTYE3_COM_QPLL0_CFG3_MASK, GTYE3_COM_QPLL0_CFG3_LSB);
def_gt_pll_masked_reg_rw16(gtye3, qpll0_cp, GTYE3_COM_QPLL0_CP_ADDR, GTYE3_COM_QPLL0_CP_MASK, GTYE3_COM_QPLL0_CP_LSB);
def_gt_pll_masked_reg_rw16(gtye3, qpll0_refclk_div, GTYE3_COM_QPLL0_REFCLK_DIV_ADDR, GTYE3_COM_QPLL0_REFCLK_DIV_MASK, GTYE3_COM_QPLL0_REFCLK_DIV_LSB);
def_gt_pll_masked_reg_rw16(gtye3, qpll0_ips_refclk_sel, GTYE3_COM_QPLL0_IPS_REFCLK_SEL_ADDR, GTYE3_COM_QPLL0_IPS_REFCLK_SEL_MASK, GTYE3_COM_QPLL0_IPS_REFCLK_SEL_LSB);
def_gt_pll_masked_reg_rw16(gtye3, qpll0_ips_en, GTYE3_COM_QPLL0_IPS_EN_ADDR, GTYE3_COM_QPLL0_IPS_EN_MASK, GTYE3_COM_QPLL0_IPS_EN_LSB);
def_gt_pll_masked_reg_rw16(gtye3, qpll0_lpf, GTYE3_COM_QPLL0_LPF_ADDR, GTYE3_COM_QPLL0_LPF_MASK, GTYE3_COM_QPLL0_LPF_LSB);
def_gt_pll_masked_reg_rw16(gtye3, qpll0_cfg1_g3, GTYE3_COM_QPLL0_CFG1_G3_ADDR, GTYE3_COM_QPLL0_CFG1_G3_MASK, GTYE3_COM_QPLL0_CFG1_G3_LSB);
def_gt_pll_masked_reg_rw16(gtye3, qpll0_cfg2_g3, GTYE3_COM_QPLL0_CFG2_G3_ADDR, GTYE3_COM_QPLL0_CFG2_G3_MASK, GTYE3_COM_QPLL0_CFG2_G3_LSB);
def_gt_pll_masked_reg_rw16(gtye3, qpll0_lpf_g3, GTYE3_COM_QPLL0_LPF_G3_ADDR, GTYE3_COM_QPLL0_LPF_G3_MASK, GTYE3_COM_QPLL0_LPF_G3_LSB);
def_gt_pll_masked_reg_rw16(gtye3, qpll0_lock_cfg_g3, GTYE3_COM_QPLL0_LOCK_CFG_G3_ADDR, GTYE3_COM_QPLL0_LOCK_CFG_G3_MASK, GTYE3_COM_QPLL0_LOCK_CFG_G3_LSB);
def_gt_pll_masked_reg_rw16(gtye3, rsvd_attr1, GTYE3_COM_RSVD_ATTR1_ADDR, GTYE3_COM_RSVD_ATTR1_MASK, GTYE3_COM_RSVD_ATTR1_LSB);
def_gt_pll_masked_reg_rw16(gtye3, qpll0_fbdiv_g3, GTYE3_COM_QPLL0_FBDIV_G3_ADDR, GTYE3_COM_QPLL0_FBDIV_G3_MASK, GTYE3_COM_QPLL0_FBDIV_G3_LSB);
def_gt_pll_masked_reg_rw16(gtye3, rxrecclkout0_sel, GTYE3_COM_RXRECCLKOUT0_SEL_ADDR, GTYE3_COM_RXRECCLKOUT0_SEL_MASK, GTYE3_COM_RXRECCLKOUT0_SEL_LSB);
def_gt_pll_masked_reg_rw16(gtye3, qpll0_sdm_cfg0, GTYE3_COM_QPLL0_SDM_CFG0_ADDR, GTYE3_COM_QPLL0_SDM_CFG0_MASK, GTYE3_COM_QPLL0_SDM_CFG0_LSB);
def_gt_pll_masked_reg_rw16(gtye3, qpll0_sdm_cfg1, GTYE3_COM_QPLL0_SDM_CFG1_ADDR, GTYE3_COM_QPLL0_SDM_CFG1_MASK, GTYE3_COM_QPLL0_SDM_CFG1_LSB);
def_gt_pll_masked_reg_rw16(gtye3, sdm0initseed0_0, GTYE3_COM_SDM0INITSEED0_0_ADDR, GTYE3_COM_SDM0INITSEED0_0_MASK, GTYE3_COM_SDM0INITSEED0_0_LSB);
def_gt_pll_masked_reg_rw16(gtye3, sdm0initseed0_1, GTYE3_COM_SDM0INITSEED0_1_ADDR, GTYE3_COM_SDM0INITSEED0_1_MASK, GTYE3_COM_SDM0INITSEED0_1_LSB);
def_gt_pll_masked_reg_rw16(gtye3, qpll0_sdm_cfg2, GTYE3_COM_QPLL0_SDM_CFG2_ADDR, GTYE3_COM_QPLL0_SDM_CFG2_MASK, GTYE3_COM_QPLL0_SDM_CFG2_LSB);
def_gt_pll_masked_reg_rw16(gtye3, qpll0_cp_g3, GTYE3_COM_QPLL0_CP_G3_ADDR, GTYE3_COM_QPLL0_CP_G3_MASK, GTYE3_COM_QPLL0_CP_G3_LSB);
def_gt_pll_masked_reg_rw16(gtye3, qpll0_cfg4, GTYE3_COM_QPLL0_CFG4_ADDR, GTYE3_COM_QPLL0_CFG4_MASK, GTYE3_COM_QPLL0_CFG4_LSB);
def_gt_pll_masked_reg_rw16(gtye3, bias_cfg0, GTYE3_COM_BIAS_CFG0_ADDR, GTYE3_COM_BIAS_CFG0_MASK, GTYE3_COM_BIAS_CFG0_LSB);
def_gt_pll_masked_reg_rw16(gtye3, bias_cfg1, GTYE3_COM_BIAS_CFG1_ADDR, GTYE3_COM_BIAS_CFG1_MASK, GTYE3_COM_BIAS_CFG1_LSB);
def_gt_pll_masked_reg_rw16(gtye3, bias_cfg2, GTYE3_COM_BIAS_CFG2_ADDR, GTYE3_COM_BIAS_CFG2_MASK, GTYE3_COM_BIAS_CFG2_LSB);
def_gt_pll_masked_reg_rw16(gtye3, bias_cfg3, GTYE3_COM_BIAS_CFG3_ADDR, GTYE3_COM_BIAS_CFG3_MASK, GTYE3_COM_BIAS_CFG3_LSB);
def_gt_pll_masked_reg_rw16(gtye3, bias_cfg4, GTYE3_COM_BIAS_CFG4_ADDR, GTYE3_COM_BIAS_CFG4_MASK, GTYE3_COM_BIAS_CFG4_LSB);
def_gt_pll_masked_reg_rw16(gtye3, qpll1_cfg0, GTYE3_COM_QPLL1_CFG0_ADDR, GTYE3_COM_QPLL1_CFG0_MASK, GTYE3_COM_QPLL1_CFG0_LSB);
def_gt_pll_masked_reg_rw16(gtye3, common_cfg1, GTYE3_COM_COMMON_CFG1_ADDR, GTYE3_COM_COMMON_CFG1_MASK, GTYE3_COM_COMMON_CFG1_LSB);
def_gt_pll_masked_reg_rw16(gtye3, por_cfg, GTYE3_COM_POR_CFG_ADDR, GTYE3_COM_POR_CFG_MASK, GTYE3_COM_POR_CFG_LSB);
def_gt_pll_masked_reg_rw16(gtye3, ppf1_cfg, GTYE3_COM_PPF1_CFG_ADDR, GTYE3_COM_PPF1_CFG_MASK, GTYE3_COM_PPF1_CFG_LSB);
def_gt_pll_masked_reg_rw16(gtye3, qpll1clkout_rate, GTYE3_COM_QPLL1CLKOUT_RATE_ADDR, GTYE3_COM_QPLL1CLKOUT_RATE_MASK, GTYE3_COM_QPLL1CLKOUT_RATE_LSB);
def_gt_pll_masked_reg_rw16(gtye3, qpll1_cfg1, GTYE3_COM_QPLL1_CFG1_ADDR, GTYE3_COM_QPLL1_CFG1_MASK, GTYE3_COM_QPLL1_CFG1_LSB);
def_gt_pll_masked_reg_rw16(gtye3, qpll1_cfg2, GTYE3_COM_QPLL1_CFG2_ADDR, GTYE3_COM_QPLL1_CFG2_MASK, GTYE3_COM_QPLL1_CFG2_LSB);
def_gt_pll_masked_reg_rw16(gtye3, qpll1_lock_cfg, GTYE3_COM_QPLL1_LOCK_CFG_ADDR, GTYE3_COM_QPLL1_LOCK_CFG_MASK, GTYE3_COM_QPLL1_LOCK_CFG_LSB);
def_gt_pll_masked_reg_rw16(gtye3, qpll1_init_cfg0, GTYE3_COM_QPLL1_INIT_CFG0_ADDR, GTYE3_COM_QPLL1_INIT_CFG0_MASK, GTYE3_COM_QPLL1_INIT_CFG0_LSB);
def_gt_pll_masked_reg_rw16(gtye3, qpll1_init_cfg1, GTYE3_COM_QPLL1_INIT_CFG1_ADDR, GTYE3_COM_QPLL1_INIT_CFG1_MASK, GTYE3_COM_QPLL1_INIT_CFG1_LSB);
def_gt_pll_masked_reg_rw16(gtye3, qpll1_fbdiv, GTYE3_COM_QPLL1_FBDIV_ADDR, GTYE3_COM_QPLL1_FBDIV_MASK, GTYE3_COM_QPLL1_FBDIV_LSB);
def_gt_pll_masked_reg_rw16(gtye3, qpll1_cfg3, GTYE3_COM_QPLL1_CFG3_ADDR, GTYE3_COM_QPLL1_CFG3_MASK, GTYE3_COM_QPLL1_CFG3_LSB);
def_gt_pll_masked_reg_rw16(gtye3, qpll1_cp, GTYE3_COM_QPLL1_CP_ADDR, GTYE3_COM_QPLL1_CP_MASK, GTYE3_COM_QPLL1_CP_LSB);
def_gt_pll_masked_reg_rw16(gtye3, qpll1_refclk_div, GTYE3_COM_QPLL1_REFCLK_DIV_ADDR, GTYE3_COM_QPLL1_REFCLK_DIV_MASK, GTYE3_COM_QPLL1_REFCLK_DIV_LSB);
def_gt_pll_masked_reg_rw16(gtye3, qpll1_ips_refclk_sel, GTYE3_COM_QPLL1_IPS_REFCLK_SEL_ADDR, GTYE3_COM_QPLL1_IPS_REFCLK_SEL_MASK, GTYE3_COM_QPLL1_IPS_REFCLK_SEL_LSB);
def_gt_pll_masked_reg_rw16(gtye3, sarc_en, GTYE3_COM_SARC_EN_ADDR, GTYE3_COM_SARC_EN_MASK, GTYE3_COM_SARC_EN_LSB);
def_gt_pll_masked_reg_rw16(gtye3, qpll1_ips_en, GTYE3_COM_QPLL1_IPS_EN_ADDR, GTYE3_COM_QPLL1_IPS_EN_MASK, GTYE3_COM_QPLL1_IPS_EN_LSB);
def_gt_pll_masked_reg_rw16(gtye3, sarc_sel, GTYE3_COM_SARC_SEL_ADDR, GTYE3_COM_SARC_SEL_MASK, GTYE3_COM_SARC_SEL_LSB);
def_gt_pll_masked_reg_rw16(gtye3, qpll1_lpf, GTYE3_COM_QPLL1_LPF_ADDR, GTYE3_COM_QPLL1_LPF_MASK, GTYE3_COM_QPLL1_LPF_LSB);
def_gt_pll_masked_reg_rw16(gtye3, qpll1_cfg1_g3, GTYE3_COM_QPLL1_CFG1_G3_ADDR, GTYE3_COM_QPLL1_CFG1_G3_MASK, GTYE3_COM_QPLL1_CFG1_G3_LSB);
def_gt_pll_masked_reg_rw16(gtye3, qpll1_cfg2_g3, GTYE3_COM_QPLL1_CFG2_G3_ADDR, GTYE3_COM_QPLL1_CFG2_G3_MASK, GTYE3_COM_QPLL1_CFG2_G3_LSB);
def_gt_pll_masked_reg_rw16(gtye3, qpll1_lpf_g3, GTYE3_COM_QPLL1_LPF_G3_ADDR, GTYE3_COM_QPLL1_LPF_G3_MASK, GTYE3_COM_QPLL1_LPF_G3_LSB);
def_gt_pll_masked_reg_rw16(gtye3, qpll1_lock_cfg_g3, GTYE3_COM_QPLL1_LOCK_CFG_G3_ADDR, GTYE3_COM_QPLL1_LOCK_CFG_G3_MASK, GTYE3_COM_QPLL1_LOCK_CFG_G3_LSB);
def_gt_pll_masked_reg_rw16(gtye3, rsvd_attr2, GTYE3_COM_RSVD_ATTR2_ADDR, GTYE3_COM_RSVD_ATTR2_MASK, GTYE3_COM_RSVD_ATTR2_LSB);
def_gt_pll_masked_reg_rw16(gtye3, qpll1_fbdiv_g3, GTYE3_COM_QPLL1_FBDIV_G3_ADDR, GTYE3_COM_QPLL1_FBDIV_G3_MASK, GTYE3_COM_QPLL1_FBDIV_G3_LSB);
def_gt_pll_masked_reg_rw16(gtye3, rxrecclkout1_sel, GTYE3_COM_RXRECCLKOUT1_SEL_ADDR, GTYE3_COM_RXRECCLKOUT1_SEL_MASK, GTYE3_COM_RXRECCLKOUT1_SEL_LSB);
def_gt_pll_masked_reg_rw16(gtye3, qpll1_sdm_cfg0, GTYE3_COM_QPLL1_SDM_CFG0_ADDR, GTYE3_COM_QPLL1_SDM_CFG0_MASK, GTYE3_COM_QPLL1_SDM_CFG0_LSB);
def_gt_pll_masked_reg_rw16(gtye3, qpll1_sdm_cfg1, GTYE3_COM_QPLL1_SDM_CFG1_ADDR, GTYE3_COM_QPLL1_SDM_CFG1_MASK, GTYE3_COM_QPLL1_SDM_CFG1_LSB);
def_gt_pll_masked_reg_rw16(gtye3, sdm1initseed0_0, GTYE3_COM_SDM1INITSEED0_0_ADDR, GTYE3_COM_SDM1INITSEED0_0_MASK, GTYE3_COM_SDM1INITSEED0_0_LSB);
def_gt_pll_masked_reg_rw16(gtye3, sdm1initseed0_1, GTYE3_COM_SDM1INITSEED0_1_ADDR, GTYE3_COM_SDM1INITSEED0_1_MASK, GTYE3_COM_SDM1INITSEED0_1_LSB);
def_gt_pll_masked_reg_rw16(gtye3, qpll1_sdm_cfg2, GTYE3_COM_QPLL1_SDM_CFG2_ADDR, GTYE3_COM_QPLL1_SDM_CFG2_MASK, GTYE3_COM_QPLL1_SDM_CFG2_LSB);
def_gt_pll_masked_reg_rw16(gtye3, qpll1_cp_g3, GTYE3_COM_QPLL1_CP_G3_ADDR, GTYE3_COM_QPLL1_CP_G3_MASK, GTYE3_COM_QPLL1_CP_G3_LSB);
def_gt_pll_masked_reg_rw16(gtye3, rsvd_attr3, GTYE3_COM_RSVD_ATTR3_ADDR, GTYE3_COM_RSVD_ATTR3_MASK, GTYE3_COM_RSVD_ATTR3_LSB);
def_gt_pll_masked_reg_rw16(gtye3, qpll1_cfg4, GTYE3_COM_QPLL1_CFG4_ADDR, GTYE3_COM_QPLL1_CFG4_MASK, GTYE3_COM_QPLL1_CFG4_LSB);

// RX
def_gt_ch_masked_reg_rw16(gtye3, rx_data_width_raw, GTYE3_CH_RX_DATA_WIDTH_ADDR, GTYE3_CH_RX_DATA_WIDTH_MASK, GTYE3_CH_RX_DATA_WIDTH_LSB);
int gtye3_ch_get_rx_data_width(struct gt_ch *ch, uint32_t *val);

def_gt_ch_masked_reg_rw16(gtye3, rx_int_data_width_raw, GTYE3_CH_RX_INT_DATAWIDTH_ADDR, GTYE3_CH_RX_INT_DATAWIDTH_MASK, GTYE3_CH_RX_INT_DATAWIDTH_LSB);
int gtye3_ch_get_rx_int_data_width(struct gt_ch *ch, uint32_t *val);

def_gt_ch_masked_reg_rw16(gtye3, es_prescale, GTYE3_CH_ES_PRESCALE_ADDR, GTYE3_CH_ES_PRESCALE_MASK, GTYE3_CH_ES_PRESCALE_LSB);
def_gt_ch_masked_reg_rw16(gtye3, es_eye_scan_en, GTYE3_CH_ES_EYE_SCAN_EN_ADDR, GTYE3_CH_ES_EYE_SCAN_EN_MASK, GTYE3_CH_ES_EYE_SCAN_EN_LSB);
def_gt_ch_masked_reg_rw16(gtye3, es_errdet_en, GTYE3_CH_ES_ERRDET_EN_ADDR, GTYE3_CH_ES_ERRDET_EN_MASK, GTYE3_CH_ES_ERRDET_EN_LSB);
def_gt_ch_masked_reg_rw16(gtye3, es_control, GTYE3_CH_ES_CONTROL_ADDR, GTYE3_CH_ES_CONTROL_MASK, GTYE3_CH_ES_CONTROL_LSB);

int gtye3_ch_set_es_qual_mask(struct gt_ch *ch, uint8_t *mask);
int gtye3_ch_set_es_qual_mask_clear(struct gt_ch *ch);

int gtye3_ch_set_es_sdata_mask(struct gt_ch *ch, uint8_t *mask);
int gtye3_ch_set_es_sdata_mask_width(struct gt_ch *ch, int width);

def_gt_ch_masked_reg_rw16(gtye3, es_horz_offset, GTYE3_CH_ES_HORZ_OFFSET_ADDR, GTYE3_CH_ES_HORZ_OFFSET_MASK, GTYE3_CH_ES_HORZ_OFFSET_LSB);
def_gt_ch_masked_reg_rw16(gtye3, rx_eyescan_vs_range, GTYE3_CH_RX_EYESCAN_VS_RANGE_ADDR, GTYE3_CH_RX_EYESCAN_VS_RANGE_MASK, GTYE3_CH_RX_EYESCAN_VS_RANGE_LSB);
def_gt_ch_masked_reg_rw16(gtye3, rx_eyescan_vs_code, GTYE3_CH_RX_EYESCAN_VS_CODE_ADDR, GTYE3_CH_RX_EYESCAN_VS_CODE_MASK, GTYE3_CH_RX_EYESCAN_VS_CODE_LSB);
def_gt_ch_masked_reg_rw16(gtye3, rx_eyescan_vs_ut_sign, GTYE3_CH_RX_EYESCAN_VS_UT_SIGN_ADDR, GTYE3_CH_RX_EYESCAN_VS_UT_SIGN_MASK, GTYE3_CH_RX_EYESCAN_VS_UT_SIGN_LSB);
def_gt_ch_masked_reg_rw16(gtye3, rx_eyescan_vs_neg_dir, GTYE3_CH_RX_EYESCAN_VS_NEG_DIR_ADDR, GTYE3_CH_RX_EYESCAN_VS_NEG_DIR_MASK, GTYE3_CH_RX_EYESCAN_VS_NEG_DIR_LSB);
def_gt_ch_masked_reg_read16(gtye3, es_error_count, GTYE3_CH_ES_ERROR_COUNT_ADDR, GTYE3_CH_ES_ERROR_COUNT_MASK, GTYE3_CH_ES_ERROR_COUNT_LSB);
def_gt_ch_masked_reg_read16(gtye3, es_sample_count, GTYE3_CH_ES_SAMPLE_COUNT_ADDR, GTYE3_CH_ES_SAMPLE_COUNT_MASK, GTYE3_CH_ES_SAMPLE_COUNT_LSB);
def_gt_ch_masked_reg_read16(gtye3, es_control_status, GTYE3_CH_ES_CONTROL_STATUS_ADDR, GTYE3_CH_ES_CONTROL_STATUS_MASK, GTYE3_CH_ES_CONTROL_STATUS_LSB);

// TX
def_gt_ch_masked_reg_rw16(gtye3, tx_data_width_raw, GTYE3_CH_TX_DATA_WIDTH_ADDR, GTYE3_CH_TX_DATA_WIDTH_MASK, GTYE3_CH_TX_DATA_WIDTH_LSB);
int gtye3_ch_get_tx_data_width(struct gt_ch *ch, uint32_t *val);

def_gt_ch_masked_reg_rw16(gtye3, tx_int_data_width_raw, GTYE3_CH_TX_INT_DATAWIDTH_ADDR, GTYE3_CH_TX_INT_DATAWIDTH_MASK, GTYE3_CH_TX_INT_DATAWIDTH_LSB);
int gtye3_ch_get_tx_int_data_width(struct gt_ch *ch, uint32_t *val);

#endif /* XCVR_GTYE3_H */
