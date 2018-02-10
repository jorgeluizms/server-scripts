#!/bin/bash
        for i in `seq 0 1000`;
        do
        if (( i < 10)); then
             EXTRA='00'
        elif (( i < 100)); then
             EXTRA='0'
        else
             EXTRA=''
        fi
         echo ${EXTRA}$i
        pdftk crypted.pdf input_pw $EXTRA$i output decrypted.pdf
        if [ $? -eq 0 ]; then
           sleep 5s
        fi
        done
