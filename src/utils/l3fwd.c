/*
 * Created on Tue May 17 2022
 *
 * Copyright (c) 2022 IOA UCAS
 *
 * @Filename:	 mqnic.c
 * @Author:		 Jiawei Lin
 * @Last edit:	 15:05:28
 */
#include <stdio.h>	/* printf */
#include <stdlib.h>	/* atoi */
#include <string.h>

#include <mqnic/mqnic.h>

static void usage(char *name)
{
	fprintf(stderr,
			"usage: %s [options]\n"
			" -d name    device to open (/dev/mqnic0)\n"
			" -i         initial table entries\n"
			" -r file    read entries to file\n"
			" -w file    write entries from file\n",
			name);
}

#define TCAM_WIDTH 32
// #define DEBUG

#define FILE_TYPE_BIN 0
#define FILE_TYPE_HEX 1
#define FILE_TYPE_BIT 2

/* filename: tb/fpga_core/mqnic.py, modules/mqnic_hw.h */
#define MQNIC_RB_APP_MAT_TYPE 0x01020304
#define MQNIC_RB_APP_MAT_VER 0x00000100
#define APP_MAT_BAR_TCAM_WR_DATA 0x0100
#define APP_MAT_BAR_TCAM_WR_KEEP 0x0180
#define APP_MAT_BAR_ACTN_WR_DATA 0x0010
#define APP_MAT_BAR_CSR 0x0020
#define MQNIC_BOARD_ID_F1000 0x10ee9013
#define MQNIC_RB_DRP_TYPE 0x0000C150
#define MQNIC_RB_DRP_VER 0x00000100
/*
	Action Code: size: 16B
		[127:80]	Destination MAC		6 octets
		[79:32]		Source MAC			6 octets
		[31:16]		VLAN Data			2 octets
		[15:8]		channel				1 octets
		[7:0]		Op. code			1 octets
	Operation code: size 1 byte
		[7]			set DMAC			1 bit
		[6]			set DMAC			1 bit
		[5:4]		VLAN OP				2 bit
					2'b01				insert
					2'b10				remove
					2'b11				modify
		[3]			set tdest			1 bit
		[2]			set tid				1 bit
		[1]			Calculate Checksum 	1 bit
		[0]			Reserved			2 bit
*/
struct actn_entry
{
	uint64_t dmac;
	uint64_t smac;
	uint16_t vlan;
	uint8_t channel;
	uint8_t op_code;
};

int l3fwd_tcam_wr(struct mqnic_reg_block *rb, uint32_t data[8], uint32_t keep[8], uint16_t addr)
{
	if (rb->type != MQNIC_RB_APP_MAT_TYPE || rb->version != MQNIC_RB_APP_MAT_VER)
	{
		fprintf(stderr, "TYPE/VER check failed. \n");
		return -1;
	}

	for (int i = 0; i < 8; i++)
	{
		mqnic_reg_write32(rb->regs, APP_MAT_BAR_TCAM_WR_DATA + i * 4, data[i]);
		mqnic_reg_write32(rb->regs, APP_MAT_BAR_TCAM_WR_KEEP + i * 4, keep[i]);
		uint16_t addr_1 = APP_MAT_BAR_TCAM_WR_DATA + i * 4;
		uint16_t addr_2 = APP_MAT_BAR_TCAM_WR_KEEP + i * 4;
		fprintf(stdout, "\t tcam_data[%04X] = %08X\n", addr_1, data[i]);
		fprintf(stdout, "\t tcam_keep[%04X] = %08X\n", addr_2, keep[i]);
	}

	uint32_t csr = 0x8000 | (addr & 0x7FFF);
	mqnic_reg_write32(rb->regs, APP_MAT_BAR_CSR, csr);
	fprintf(stdout, "\t csr[%04X] = %08X\n", APP_MAT_BAR_CSR, csr);

	if (csr == mqnic_reg_read32(rb->regs, APP_MAT_BAR_CSR))
	{
		return 0;
	}
	else
	{
		fprintf(stderr, "l3fwd_tcam_wr failed. \n");
		return -1;
	}
}

int l3fwd_actn_wr(struct mqnic_reg_block *rb, struct actn_entry e, uint16_t addr)
{
	if (rb->type != MQNIC_RB_APP_MAT_TYPE || rb->version != MQNIC_RB_APP_MAT_VER)
	{
		fprintf(stderr, "TYPE/VER check failed. \n");
		return -1;
	}
	uint32_t mask = 0xFFFFFFFF;
	uint32_t val = (((e.vlan << 16) | (e.channel << 8) | e.op_code) & mask);
	uint16_t addr_1 = APP_MAT_BAR_ACTN_WR_DATA + 0x0;
	fprintf(stdout, "\t actn_data[%04X] = %08X\n", addr_1, val);
	mqnic_reg_write32(rb->regs, addr_1, val);
	val = (e.smac & mask);
	addr_1 = addr_1 + 4;
	fprintf(stdout, "\t actn_data[%04X] = %08X\n", addr_1, val);
	mqnic_reg_write32(rb->regs, addr_1, val);
	val = (((e.dmac << 16) | (e.smac >> 32)) & mask);
	addr_1 = addr_1 + 4;
	fprintf(stdout, "\t actn_data[%04X] = %08X\n", addr_1, val);
	mqnic_reg_write32(rb->regs, addr_1, val);
	val = (e.dmac >> 16) & mask;
	addr_1 = addr_1 + 4;
	fprintf(stdout, "\t actn_data[%04X] = %08X\n", addr_1, val);
	mqnic_reg_write32(rb->regs, addr_1, val);

	uint32_t csr = (0x8000 | (addr & 0x7FFF)) << 16;
	mqnic_reg_write32(rb->regs, APP_MAT_BAR_CSR, csr);
	fprintf(stdout, "\t csr[%04X] = %08X\n", APP_MAT_BAR_CSR, csr);

	if (csr == mqnic_reg_read32(rb->regs, APP_MAT_BAR_CSR))
	{
		return 0;
	}
	else
	{
		fprintf(stderr, "l3fwd_actn_wr failed. \n");
		return -1;
	}
}

/* inline */ int f_print_csr(volatile uint8_t *reg, int beg, int end)
{
	end = end > beg + 128 ? beg + 128 : end;
	for (int i = beg; i < end; i = i + 4)
	{
		fprintf(stdout, "\t reg[%04X] = %08X,", i, mqnic_reg_read32(reg, i));
		if (i % 0x10 == 0xC)
		{
			fprintf(stdout, "\n");
		}
	}
	fprintf(stdout, "\n");
	return 0;
}

int main(int argc, char *argv[])
{

	char *name;
	int opt;
	int rtn = 0;

	char *device = NULL;
	char *read_file_name = NULL;
	char *write_file_name = NULL;
	// FILE *read_file = NULL;
	// FILE *write_file = NULL;

	char arg_read = 0;
	char arg_write = 0;
	char arg_init = 0;
	char arg_switch = 0;

	struct mqnic *dev = NULL;

	name = strrchr(argv[0], '/');
	name = name ? 1 + name : argv[0];

	while ((opt = getopt(argc, argv, "d:r:w:sh?i")) != EOF)
	{
		switch (opt)
		{
		case 'd':
			device = optarg;
			break;
		case 'i':
			arg_init = 1;
			break;
		case 'r':
			arg_read = 1;
			read_file_name = optarg;
			break;
		case 'w':
			arg_write = 1;
			write_file_name = optarg;
			break;
		case 's':
			arg_switch = 1;
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
		// fprintf(stderr, "Device not specified\n");
		// usage(name);
		device = "/dev/mqnic0";
	}

#ifndef DEBUG

	dev = mqnic_open(device);

	if (!dev)
	{
		fprintf(stderr, "Failed to open device\n");
		return -1;
	}

	if (!dev->pci_device_path[0])
	{
		fprintf(stderr, "Failed to determine PCIe device path\n");
		rtn = -1;
		goto err;
	}

	/* Reg block list of mqnic0/resource0 */
	struct mqnic_reg_block *drp_rb = mqnic_find_reg_block(dev->rb_list, MQNIC_RB_DRP_TYPE, MQNIC_RB_DRP_VER, 0);

	if (!drp_rb)
	{
		fprintf(stderr, "Error: DRP block not found\n");
		goto err;
	}

	struct mqnic_reg_block *rb_list = mqnic_enumerate_reg_block_list(dev->app_regs, 0, dev->app_regs_size);
	struct mqnic_reg_block *rb = mqnic_find_reg_block(rb_list, MQNIC_RB_APP_MAT_TYPE, MQNIC_RB_APP_MAT_VER, 0);

	if (!rb)
	{
		fprintf(stderr, "Error: APP_MAT block not found\n");
		goto err;
	}

#else

	struct mqnic t;
	dev = &t;
	volatile uint8_t rb_regs[0x200] = {};
	struct mqnic_reg_block rb =
		{
			MQNIC_RB_APP_MAT_TYPE,
			MQNIC_RB_APP_MAT_VER,
			rb_regs,
			rb_regs};

#endif

	if (arg_read+arg_write+arg_init>1)
		fprintf(stderr, "\t(r,w,i) = (%d,%d,%d)\n", arg_read, arg_write, arg_init);

	if (arg_init)
	{
		uint32_t data[8] = {
			0xC0A80101,
			0xC0A80102,
			0xC0A80103,
			0xC0A80104,
			0xC0A80105,
			0xC0A80106,
			0xC0A80107,
			0xC0A80108};
		uint32_t keep[8] = {
			0xFFFFFFFF,
			0xFFFFFFFF,
			0xFFFFFFFF,
			0xFFFFFFFF,
			0xFFFFFFFF,
			0xFFFFFFFF,
			0xFFFFFFFF,
			0xFFFFFFFF};
		uint16_t addr = 0x0000;
		l3fwd_tcam_wr(rb, data, keep, addr);
		sleep(0.1);

		for (int i = 0; i < 0x8; i++)
		{
			struct actn_entry entry = {
				0xDAD1D2D3D4D0 + i + 1,
				0x5A5152535450 + i + 1,
				0xFF00 + i + 1,
				((i + 1) % 0x8),
				0b11011010 // 0xDA
			};
			l3fwd_actn_wr(rb, entry, addr + i);
			sleep(0.1);
		}
	}

	if (arg_read)
	{
		// fprintf(stderr, "\tRead filename: %s\n", read_file_name);
		int beg, end, bias;
		if (sscanf(read_file_name, "%X+:%X", &beg, &bias) == 2) {
			// printf("beg=%04X, bias=%04X", beg, bias);
			f_print_csr(dev->regs, beg, beg + bias);
		} else if (sscanf(read_file_name, "%X:%X", &beg, &end) == 2) {
			// printf("beg=%04X, end=%04X", beg, end);
			f_print_csr(dev->regs, beg, end);
		} else {
			f_print_csr(dev->regs, beg, beg+4);
		}
	}

	if (arg_write)
	{
		int addr, data;
		fprintf(stderr, "\twrite filename: %s\n", write_file_name);
		if (sscanf(write_file_name, "%X=%X", &addr, &data) == 2) {
			// printf("addr=0x%04X, data=0x%04X\n", addr, data);
			mqnic_reg_write32(dev->regs, addr, data);
		}
	}

	if (arg_switch) {
		fprintf(stderr, "\t Switch between 10G/25G \n");
		f_print_csr(drp_rb->regs, 0x00, 0x20);
		int cfg = 0;

		mqnic_reg_write32(drp_rb->regs, 0x14, 0x0001);  /* DRP: address */
		mqnic_reg_write32(drp_rb->regs, 0x10, 0x0001);  /* DRP: read enable */
		cfg = mqnic_reg_read32(drp_rb->regs, 0x1C);	  /* DRP: data out */
		printf("\nRead out pllclksel=0x%08X\n", cfg);
		cfg = cfg ^ 0x0002;
		mqnic_reg_write32(drp_rb->regs, 0x18, cfg);		/* DRP: data in */
		mqnic_reg_write32(drp_rb->regs, 0x10, 0x0002);	/* DRP: write enable */

		mqnic_reg_write32(drp_rb->regs, 0x14, 0x1001);  /* DRP: address */
		mqnic_reg_write32(drp_rb->regs, 0x10, 0x0001);  /* DRP: read enable */
		cfg = mqnic_reg_read32(drp_rb->regs, 0x1C);	  /* DRP: data out */
		cfg = cfg ^ 0x0002;
		mqnic_reg_write32(drp_rb->regs, 0x18, cfg);	  /* DRP: data in */
		mqnic_reg_write32(drp_rb->regs, 0x10, 0x0002);  /* DRP: write enable */
		f_print_csr(drp_rb->regs, 0x00, 0x20);

		sleep(0.1);
		mqnic_reg_write32(drp_rb->regs, 0x14, 0x0001); /* DRP: address */
		mqnic_reg_write32(drp_rb->regs, 0x10, 0x0001); /* DRP: read enable */
		sleep(0.1);
		cfg = mqnic_reg_read32(drp_rb->regs, 0x1C); /* DRP: data out */
		printf("\nWrite in pllclksel=0x%08X\n", cfg);
	}

#ifndef DEBUG
err:
	mqnic_close(dev);
#endif
	return rtn;
}
