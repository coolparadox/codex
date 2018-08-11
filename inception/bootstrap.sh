#!/bin/bash
set -e -u -o pipefail

tangle() {
    local INSIDE_LITERAL=0
    local CURRENT_CHUNK=''
    while read LINE ; do
        test "$LINE" = '////' && {
            if test $INSIDE_LITERAL -eq 0 ; then
                INSIDE_LITERAL=1
            else
                INSIDE_LITERAL=0
                CURRENT_CHUNK=''
            fi
            continue
        }
        test $INSIDE_LITERAL -ne 0 || continue
        test -n "$CURRENT_CHUNK" || {
            CURRENT_CHUNK=$LINE
            continue
        }
        test "$CURRENT_CHUNK" = "$1" || continue
        case $LINE in
            /*)
                tangle "$LINE"
                ;;
            *)
                echo $LINE
                ;;
        esac
    done 0<tangling_test.adoc
}

tangle '//yo.cpp'
