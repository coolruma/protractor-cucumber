#!/bin/bash

basedir=$(cd "$(dirname "${BASH_SOURCE[0]}" )" && pwd )

function apcEncrypt () {
    pubkey=${pubkey:-$basedir/apc/public_uat}
    input=$1
    echo -n $input | openssl rsautl -encrypt -pubin -inkey $pubkey | base64 -w0
}
