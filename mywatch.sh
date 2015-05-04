#! /bin/bash

function mywatch() {
    if test -d "/home/core/share"
    then
        . "$AD_NIMBUS_DIR"/.coreosProfile
    else
        . "$AD_NIMBUS_DIR/".hostProfile
    fi

    $* 
}


