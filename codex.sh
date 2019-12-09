#!/bin/env bash

set -e -u -o pipefail

ME=$( basename $0 )

usage() {
    echo "usage: codex.sh file.adoc" 1>&2
    exit 1
}

test $# -gt 0 || usage
TARGET=$1
test -n "$TARGET" || usage
shift
test $# -eq 0 || usage
test -r "$TARGET" || TARGET="${TARGET}.adoc"

expand() {
    local PATH="$1"
    local STACK="$2"
    for F in $STACK ; do
        test "$F" = "$PATH" && {
            echo "$ME: ///include error: inclusion loop detected" >&2
            echo "inclusion stack is:$STACK $PATH" >&2
            exit 1
        } || :
    done
    test -r "$PATH" || {
        echo "$ME: ///include error: cannot read file '$PATH'" >&2
        exit 1
    }
    local RANK=0
    local INCLUDE=''
    while IFS='' read -r LINE ; do
        case $RANK in
            0)
                if test "$LINE" = '////' ; then
                    RANK=1
                else
                    echo -E "$LINE"
                fi
                ;;
            1)
                if test "$LINE" = '///include' ; then
                    RANK=2
                else
                    RANK=4
                    echo '////'
                    echo -E "$LINE"
                fi
                ;;
            2)
                case "$LINE" in
                    /*)
                        RANK=4
                        echo '////'
                        echo '///include'
                        echo -E "$LINE"
                        ;;
                    *)
                        RANK=3
                        INCLUDE="$LINE"
                        ;;
                esac
                ;;
            3)
                if test "$LINE" = '////' ; then
                    RANK=0
                    expand "$INCLUDE" "$STACK $PATH"
                else
                    RANK=4
                    echo '////'
                    echo '///include'
                    echo -E "$INCLUDE"
                    echo -E "$LINE"
                fi
                ;;
            4)
                if test "$LINE" = '////' ; then
                    RANK=0
                fi
                echo -E "$LINE"
                ;;
        esac
    done <"$PATH"
}

expand "$TARGET" ''
