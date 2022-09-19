# Corundum mqnic for F1000@ZU19EG

## Introduction

This design targets the RESNICS F1000@ZU19EG FPGA board.

FPGA: zu19eg-ffvc1760-2-e
PHY: 25G BASE-R PHY IP core and internal GTY transceiver

## How to build

Run make to build.  Ensure that the Xilinx Vivado toolchain components are in PATH. 

```sh
make SUBDIRS=fpga_l3fwd
```

Run make to build the driver.  Ensure the headers for the running kernel are installed, otherwise the driver cannot be compiled.

```sh
# Insert driver
cd ./src/moduels/
make
insmod mqnic.ko
```

## How to test

Use XSDB or Petalinux to program the F1000@ZU19EG board with Vivado.  Then load the driver with insmod mqnic.ko.  Check dmesg for output from driver initialization. Config tables using utilities, and sending TCP/UDP packets from the link partner. 

```sh
## Config tables
cd ./src/utils/
make
./l3fwd -i
```

Citation

This is the example project of paper below. 

Lin, Jiawei, Zhichuan Guo, and Xiao Chen. 2022. "MAToC: A Novel Match-Action Table Architecture on Corundum for 8 × 25G Networking" Applied Sciences 12, no. 17: 8734. https://doi.org/10.3390/app12178734 

If you use Corundum in your project, please cite one of the following papers and/or link to the project on GitHub:

```
@inproceedings{forencich2020fccm,
    author = {Alex Forencich and Alex C. Snoeren and George Porter and George Papen},
    title = {Corundum: An Open-Source {100-Gbps} {NIC}},
    booktitle = {28th IEEE International Symposium on Field-Programmable Custom Computing Machines},
    year = {2020},
}
```

这是基于2022年6月初刚玉最新工程移植在F1000后的三层转发实现, 在禁用时间戳后仍可以正常发包, 使用2×4×25G的连接模式, 时序性能得到较好的改善。

```
8月20日, 将BUF_FIFO的DEPTH增大为16384, 让其使用BRAM而非LUTRAM, 减少对离散的资源大量使用。
8月22日, 周一, 证明了1x4x25G, 35x1K TCAM 的配置时序收敛。
8月23日, 周二, 使用Vivado的实现策略, Performance_Explore, 能实现WNS=-0.148, TNS=-59.403ns, NFE=1204/693475。
9月19日, 周二, 完成时序收敛。
```
