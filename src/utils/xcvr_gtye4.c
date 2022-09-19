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

#include "xcvr_gtye4.h"

// signals
int gtye4_pll_qpll0_reset(struct gt_pll *pll)
{
    int ret = 0;

    ret = gtye4_pll_set_qpll0_reset(pll, 1);

    if (ret)
        return ret;

    return gtye4_pll_set_qpll0_reset(pll, 0);
}

int gtye4_pll_qpll1_reset(struct gt_pll *pll)
{
    int ret = 0;

    ret = gtye4_pll_set_qpll1_reset(pll, 1);

    if (ret)
        return ret;

    return gtye4_pll_set_qpll1_reset(pll, 0);
}

int gtye4_ch_tx_reset(struct gt_ch *ch)
{
    int ret = 0;

    ret = gtye4_ch_set_tx_reset(ch, 1);

    if (ret)
        return ret;

    return gtye4_ch_set_tx_reset(ch, 0);
}

int gtye4_ch_tx_pma_reset(struct gt_ch *ch)
{
    int ret = 0;

    ret = gtye4_ch_set_tx_pma_reset(ch, 1);

    if (ret)
        return ret;

    return gtye4_ch_set_tx_pma_reset(ch, 0);
}

int gtye4_ch_tx_pcs_reset(struct gt_ch *ch)
{
    int ret = 0;

    ret = gtye4_ch_set_tx_pcs_reset(ch, 1);

    if (ret)
        return ret;

    return gtye4_ch_set_tx_pcs_reset(ch, 0);
}

int gtye4_ch_rx_reset(struct gt_ch *ch)
{
    int ret = 0;

    ret = gtye4_ch_set_rx_reset(ch, 1);

    if (ret)
        return ret;

    return gtye4_ch_set_rx_reset(ch, 0);
}

int gtye4_ch_rx_pma_reset(struct gt_ch *ch)
{
    int ret = 0;

    ret = gtye4_ch_set_rx_pma_reset(ch, 1);

    if (ret)
        return ret;

    return gtye4_ch_set_rx_pma_reset(ch, 0);
}

int gtye4_ch_rx_pcs_reset(struct gt_ch *ch)
{
    int ret = 0;

    ret = gtye4_ch_set_rx_pcs_reset(ch, 1);

    if (ret)
        return ret;

    return gtye4_ch_set_rx_pcs_reset(ch, 0);
}

int gtye4_ch_rx_dfe_lpm_reset(struct gt_ch *ch)
{
    int ret = 0;

    ret = gtye4_ch_set_rx_dfe_lpm_reset(ch, 1);

    if (ret)
        return ret;

    return gtye4_ch_set_rx_dfe_lpm_reset(ch, 0);
}

int gtye4_ch_eyescan_reset(struct gt_ch *ch)
{
    int ret = 0;

    ret = gtye4_ch_set_eyescan_reset(ch, 1);

    if (ret)
        return ret;

    return gtye4_ch_set_eyescan_reset(ch, 0);
}

// RX
int gtye4_ch_get_rx_data_width(struct gt_ch *ch, uint32_t *val)
{
    int ret = 0;
    uint32_t dw;

    ret = gtye4_ch_get_rx_data_width_raw(ch, &dw);
    if (ret)
        return ret;

    *val = (8*(1 << (dw >> 1)) * (4 + (dw & 1))) >> 2;
    return 0;
}

int gtye4_ch_get_rx_int_data_width(struct gt_ch *ch, uint32_t *val)
{
    int ret = 0;
    uint32_t dw, idw;

    ret = gtye4_ch_get_rx_data_width_raw(ch, &dw);
    if (ret)
        return ret;

    ret = gtye4_ch_get_rx_int_data_width_raw(ch, &idw);
    if (ret)
        return ret;

    *val = (16*(1 << idw) * (4 + (dw & 1))) >> 2;
    return 0;
}

int gtye4_ch_set_es_qual_mask(struct gt_ch *ch, uint8_t *mask)
{
    int ret = 0;

    for (int k = 0; k < 5; k++)
    {
        ret = gt_ch_reg_write(ch, GTYE4_CH_ES_QUAL_MASK0_ADDR+k, mask[2*k+0] | (mask[2*k+1] << 8));
        if (ret)
            return ret;
        ret = gt_ch_reg_write(ch, GTYE4_CH_ES_QUAL_MASK5_ADDR+k, mask[2*k+10] | (mask[2*k+11] << 8));
        if (ret)
            return ret;
    }

    return 0;
}

int gtye4_ch_set_es_qual_mask_clear(struct gt_ch *ch)
{
    int ret = 0;

    for (int k = 0; k < 5; k++)
    {
        ret = gt_ch_reg_write(ch, GTYE4_CH_ES_QUAL_MASK0_ADDR+k, 0xffff);
        if (ret)
            return ret;
        ret = gt_ch_reg_write(ch, GTYE4_CH_ES_QUAL_MASK5_ADDR+k, 0xffff);
        if (ret)
            return ret;
    }

    return 0;
}

int gtye4_ch_set_es_sdata_mask(struct gt_ch *ch, uint8_t *mask)
{
    int ret = 0;

    for (int k = 0; k < 5; k++)
    {
        ret = gt_ch_reg_write(ch, GTYE4_CH_ES_SDATA_MASK0_ADDR+k, mask[2*k+0] | (mask[2*k+1] << 8));
        if (ret)
            return ret;
        ret = gt_ch_reg_write(ch, GTYE4_CH_ES_SDATA_MASK5_ADDR+k, mask[2*k+10] | (mask[2*k+11] << 8));
        if (ret)
            return ret;
    }

    return 0;
}

int gtye4_ch_set_es_sdata_mask_width(struct gt_ch *ch, int width)
{
    int ret = 0;

    for (int k = 0; k < 5; k++)
    {
        int shift = width - (80 - ((k+1)*16));
        uint32_t mask = 0xffff;

        if (shift < 0)
        {
            mask = 0xffff;
        }
        else if (shift > 16)
        {
            mask = 0x0000;
        }
        else
        {
            mask = 0xffff >> shift;
        }

        ret = gt_ch_reg_write(ch, GTYE4_CH_ES_SDATA_MASK0_ADDR+k, mask);
        if (ret)
            return ret;
        ret = gt_ch_reg_write(ch, GTYE4_CH_ES_SDATA_MASK5_ADDR+k, 0xffff);
        if (ret)
            return ret;
    }

    return 0;
}

int gtye4_ch_get_rx_prbs_error_count(struct gt_ch *ch, uint32_t *val)
{
    int ret = 0;
    uint32_t v1, v2;

    ret = gt_ch_reg_read(ch, GTYE4_CH_RX_PRBS_ERR_CNT_L_ADDR | (ch->index << 17), &v1);
    if (ret)
        return ret;

    ret = gt_ch_reg_read(ch, GTYE4_CH_RX_PRBS_ERR_CNT_H_ADDR | (ch->index << 17), &v2);
    if (ret)
        return ret;

    *val = v1 | (v2 << 16);
    return 0;
}

// TX
int gtye4_ch_get_tx_data_width(struct gt_ch *ch, uint32_t *val)
{
    int ret = 0;
    uint32_t dw;

    ret = gtye4_ch_get_tx_data_width_raw(ch, &dw);
    if (ret)
        return ret;

    *val = (8*(1 << (dw >> 1)) * (4 + (dw & 1))) >> 2;
    return 0;
}

int gtye4_ch_get_tx_int_data_width(struct gt_ch *ch, uint32_t *val)
{
    int ret = 0;
    uint32_t dw, idw;

    ret = gtye4_ch_get_tx_data_width_raw(ch, &dw);
    if (ret)
        return ret;

    ret = gtye4_ch_get_tx_int_data_width_raw(ch, &idw);
    if (ret)
        return ret;

    *val = (16*(1 << idw) * (4 + (dw & 1))) >> 2;
    return 0;
}
