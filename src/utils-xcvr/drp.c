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

#include <mqnic/mqnic.h>

int drp_rb_reg_read(struct mqnic_reg_block *rb, uint32_t addr, uint32_t *val)
{
    mqnic_reg_write32(rb->regs, 0x14, addr);
    mqnic_reg_write32(rb->regs, 0x10, 0x00000001);
    mqnic_reg_read32(rb->regs, 0x10);
    if ((mqnic_reg_read32(rb->regs, 0x10) & 0x00000101) != 0)
        return -1;
    *val = mqnic_reg_read32(rb->regs, 0x1C);
    return 0;
}

int drp_rb_reg_write(struct mqnic_reg_block *rb, uint32_t addr, uint32_t val)
{
    mqnic_reg_write32(rb->regs, 0x14, addr);
    mqnic_reg_write32(rb->regs, 0x18, val);
    mqnic_reg_write32(rb->regs, 0x10, 0x00000003);
    mqnic_reg_read32(rb->regs, 0x10);
    if ((mqnic_reg_read32(rb->regs, 0x10) & 0x00000101) != 0)
        return -1;
    return 0;
}
