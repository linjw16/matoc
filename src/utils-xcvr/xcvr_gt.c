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

#include "drp.h"
#include "xcvr_gt.h"

int gt_pll_reg_read(struct gt_pll *pll, uint32_t addr, uint32_t *val)
{
    if (!pll)
        return -1;

    if (pll->drp_rb)
        return drp_rb_reg_read(pll->drp_rb, addr | (1 << 19), val);

    return -1;
}

int gt_pll_reg_read_masked(struct gt_pll *pll, uint32_t addr, uint32_t *val, uint32_t mask, uint32_t shift)
{
    int ret = 0;
    uint32_t v;

    ret = gt_pll_reg_read(pll, addr, &v);
    if (ret)
        return ret;

    *val = (v & mask) >> shift;
    return 0;
}

int gt_pll_reg_write(struct gt_pll *pll, uint32_t addr, uint32_t val)
{
    if (!pll)
        return -1;

    if (pll->drp_rb)
        return drp_rb_reg_write(pll->drp_rb, addr | (1 << 19), val);

    return -1;
}

int gt_pll_reg_write_masked(struct gt_pll *pll, uint32_t addr, uint32_t val, uint32_t mask, uint32_t shift)
{
    int ret = 0;
    uint32_t old_val;

    ret = gt_pll_reg_read(pll, addr, &old_val);
    if (ret)
        return ret;

    return gt_pll_reg_write(pll, addr, ((val << shift) & mask) | (old_val & ~mask));
}

int gt_pll_reg_write_multiple(struct gt_pll *pll, const struct gt_reg_val *vals)
{
    int ret = 0;
    const struct gt_reg_val *val = vals;

    while (val && val->mask)
    {
        ret = gt_pll_reg_write_masked(pll, val->addr, val->value, val->mask, val->shift);
        if (ret)
            return ret;
        val++;
    }

    return 0;
}

int gt_ch_reg_read(struct gt_ch *ch, uint32_t addr, uint32_t *val)
{
    if (!ch)
        return -1;

    if (ch->drp_rb)
        return drp_rb_reg_read(ch->drp_rb, addr | (ch->index << 17), val);

    return -1;
}

int gt_ch_reg_read_masked(struct gt_ch *ch, uint32_t addr, uint32_t *val, uint32_t mask, uint32_t shift)
{
    int ret = 0;
    uint32_t v;

    ret = gt_ch_reg_read(ch, addr, &v);
    if (ret)
        return ret;

    *val = (v & mask) >> shift;
    return 0;
}

int gt_ch_reg_write(struct gt_ch *ch, uint32_t addr, uint32_t val)
{
    if (!ch)
        return -1;

    if (ch->drp_rb)
        return drp_rb_reg_write(ch->drp_rb, addr | (ch->index << 17), val);

    return -1;
}

int gt_ch_reg_write_masked(struct gt_ch *ch, uint32_t addr, uint32_t val, uint32_t mask, uint32_t shift)
{
    int ret = 0;
    uint32_t old_val;

    ret = gt_ch_reg_read(ch, addr, &old_val);
    if (ret)
        return ret;

    return gt_ch_reg_write(ch, addr, ((val << shift) & mask) | (old_val & ~mask));
}

int gt_ch_reg_write_multiple(struct gt_ch *ch, const struct gt_reg_val *vals)
{
    int ret = 0;
    const struct gt_reg_val *val = vals;

    while (val && val->mask)
    {
        ret = gt_ch_reg_write_masked(ch, val->addr, val->value, val->mask, val->shift);
        if (ret)
            return ret;
        val++;
    }

    return 0;
}
