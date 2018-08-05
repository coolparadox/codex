#!/bin/bash
set -e -u -o pipefail

SOURCE_FILE='tangling_test.adoc'

tangle() {
    local CHUNK_NAME=$1
    local LITERAL_SECTION=0
    local CURRENT_CHUNK=''
    while read LINE ; do
        test "$LINE" = '----' && {
            if test $LITERAL_SECTION -eq 0 ; then
                LITERAL_SECTION=1
            else
                LITERAL_SECTION=0
                CURRENT_CHUNK=''
            fi
            continue
        }
        test $LITERAL_SECTION -ne 0 || continue
        test -n "$CURRENT_CHUNK" || {
            CURRENT_CHUNK=$LINE
            continue
        }
        test "$CURRENT_CHUNK" = "$CHUNK_NAME" || continue
        case $LINE in
            "# "*)
                tangle "$LINE"
                ;;
            *)
                echo $LINE
                ;;
        esac
    done 0<$SOURCE_FILE
}

tangle '# /tangle.cpp'
