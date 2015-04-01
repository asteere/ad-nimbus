#!/bin/bash

# Top man page: 
# 2c. SUMMARY Area Fields
#
# The summary area fields describing CPU statistics are abbreviated.
# They provide information about times spent in: 
#   us = user mode 
#   sy = system mode
#   ni = low priority user mode (nice)
#   id = idle task 
#   wa = I/O waiting
#   hi = servicing IRQs
#   si = servicing soft IRQs
#   st = steal (time given to other DomU instances)

# Get 3 seconds worth of data. TODO: Testing may be able to determine a better number
top -bn3 | grep '%Cpu' |sed -e 's/.*:  //' -e's/ ni, .* id, / ni,/' |awk '{lineSum=0; for(i=1; i<=    NF;i+=2){lineSum+=$i}; overallTotal+=lineSum} END {avg=overallTotal/NR; printf "%.0f\n", avg}'
