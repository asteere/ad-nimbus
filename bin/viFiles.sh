#!/bin/bash

#set -x

while read a;
do
    echo $a | grep -v -e Permission -e grep -e 'Is a directory' | sed 's/:.*//'
done | sort -u | xargs -o vi

