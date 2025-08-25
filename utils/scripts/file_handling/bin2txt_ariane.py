#!/usr/bin/python

import string
import sys

#if len(sys.argv) != 2:
#    print("usage: python3 bin2txt.py cpu_arch")

cpu_arch = int(sys.argv[1])

source_file = sys.argv[2]
binfile = [source_file[:-3] + "bin"]
print("Hi", binfile, "\n")

arch_bits = cpu_arch // 2
print(arch_bits, "\n")

#binfile = ["soft-build/ariane/systest.bin"]
#binfile = ["soft-build/ariane/baremetal/fft_stratus.bin"]
if cpu_arch == 64:
	txtfile = ["soft-build/ariane/ram.vhx"]
else:
	txtfile = ["soft-build/ibex/ram.vhx"]
print("bye", txtfile, "\n")

count = 0
for i in range(len(binfile)):

    hexlist = []

    print("Read binary file " + binfile[i])
    with open(binfile[i], "rb") as f:
        hexword = f.read(int(arch_bits / 8)).hex()
        while hexword:
            hexlist.append(hexword)
            hexword = f.read(int(arch_bits / 8)).hex()

    print("Write text file " + txtfile[i])
    with open(txtfile[i], "w") as f:
        #f.write(str(format(len(hexlist), 'x')).zfill(int(arch_bits / 4)) + '\n')
        for word in hexlist:
            f.write(word.zfill(int(arch_bits / 4)))
            count = count + 1
            if count%2 == 0:
                f.write('\n')
