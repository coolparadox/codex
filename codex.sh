#!/bin/env bash

set -e -u -f -o pipefail

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
            echo "$ME: //include error: inclusion loop detected" >&2
            echo "inclusion stack is:$STACK $PATH" >&2
            exit 1
        } || :
    done
    test -r "$PATH" || {
        echo "$ME: //include error: cannot read file '$PATH'" >&2
        exit 1
    }
    local STATE=0
    local INCLUDE=''
    while IFS='' read -r LINE ; do
        case $STATE in
        0)
            case $LINE in
            ////)
                STATE=1
                ;;
            *)
                echo -E "$LINE"
                ;;
            esac
            ;;
        1)
            case $LINE in
            //include)
                STATE=2
                ;;
            *)
                STATE=4
                echo ////
                echo -E "$LINE"
                ;;
            esac
            ;;
        2)
            case "$LINE" in
            /*)
                STATE=4
                echo ////
                echo //include
                echo -E "$LINE"
                ;;
            *)
                STATE=3
                INCLUDE="$LINE"
                ;;
            esac
            ;;
        3)
            case $LINE in
            ////)
                STATE=0
                expand "$INCLUDE" "$STACK $PATH"
                ;;
            *)
                STATE=4
                echo ////
                echo //include
                echo -E "$INCLUDE"
                echo -E "$LINE"
                ;;
            esac
            ;;
        4)
            case $LINE in
            ////)
                STATE=0
                ;;
            esac
            echo -E "$LINE"
            ;;
        esac
    done <"$PATH"
}

WD=.codex
rm -rf $WD
mkdir -p $WD

fail() {
    echo "${ME}: error: $*"
    exit 1
}

bump_file_part() {
    local NAME=$1
    COUNT_FILE="$WD/files/$NAME/part_count"
    local PART
    if test -e "$COUNT_FILE" ; then
        PART=$(cat "$COUNT_FILE")
    else
        PART=0
        mkdir -p "$WD/files/$NAME"
    fi
    PART=$(($PART + 1))
    echo $PART >"$COUNT_FILE"
    echo $PART
}

get_chunk_current_form() {
    local NAME=$1
    COUNT_FILE="$WD/chunks/$NAME/form_count"
    local FORM
    if test -e "$COUNT_FILE" ; then
        FORM=$(cat "$COUNT_FILE")
    else
        FORM=1
        mkdir -p "$WD/chunks/$NAME"
    fi
    echo $FORM >"$COUNT_FILE"
    echo $FORM
}

bump_chunk_form() {
    local NAME=$1
    COUNT_FILE="$WD/chunks/$NAME/form_count"
    local FORM
    if test -e "$COUNT_FILE" ; then
        FORM=$(cat "$COUNT_FILE")
    else
        mkdir -p "$WD/chunks/$NAME"
        FORM=1
    fi
    if test -s "$WD/chunks/$NAME/forms/$FORM/parts/1/content" ; then
        FORM=$(($FORM + 1))
    else
        :
    fi
    echo $FORM >"$COUNT_FILE"
    echo $FORM
}

bump_chunk_part() {
    local NAME=$1
    local FORM=$2
    COUNT_FILE="$WD/chunks/$NAME/forms/$FORM/part_count"
    local PART
    if test -e "$COUNT_FILE" ; then
        PART=$(cat "$COUNT_FILE")
    else
        mkdir -p "$WD/chunks/$NAME/forms/$FORM"
        PART=0
    fi
    PART=$(($PART + 1))
    echo $PART >"$COUNT_FILE"
    echo $PART
}

parse_chunk_line() {
    local LINE=$1
    case $LINE in

    /\\//*)
        # Code line starting with slash, no line feed.
        echo -E "c+${LINE:3}"
        ;;

    /\\/*)
        # Chunk reference, no line feed.
        echo -E "r+${LINE:3}"
        ;;

    /\\*)
        # Code line not starting with slash, no line feed.
        echo -E "c+${LINE:2}"
        ;;

    //*)
        # Code line starting with slash, with line feed.
        echo -E "c.${LINE:1}"
        ;;

    /*)
        # Chunk reference, with line feed.
        echo -E "r.${LINE:1}"
        ;;

    *)
        # Code line not starting with slash, with line feed.
        echo -E "c.${LINE:0}"
        ;;

    esac

}

parse() {
    local STATE=adoc
    local NAME=''
    local PART=0
    local PART_DIR=''
    local FORM=0
    while IFS='' read -r LINE ; do
        case $STATE in

        adoc)
            # I'm parsing regular asciidoc text.
            case $LINE in

            ////)
                # A comment block started.
                STATE=block
                ;;

            *)
                # The line is part of the regular ascidoc content.
                echo -E "a$LINE"
                ;;

            esac
            ;;

        block)
            # I'm parsing the first line of a comment block.
            case $LINE in

            ////)
                # The comment block ended.
                STATE=adoc
                ;;

            ///*)
                # The line does not tell if the block is one of the expected codex constructs.
                fail "unexpected slash heading at '$LINE'"
                ;;

            //*)
                # The block is a codex special.
                SPECIAL=${LINE:2}
                case $SPECIAL in

                reset)
                    # The codex special is a reset directive.
                    STATE=reset
                    ;;

                *)
                    # FIXME: temporary fallback while all specials are not yet covered.
                    STATE=special
                    ;;

                esac
                ;;

            /*)
                # The block is another part of a codex file.
                NAME=$(realpath -m --relative-to=/ "$LINE")
                PART=$(bump_file_part "$NAME")
                PART_DIR="$WD/files/$NAME/parts/$PART"
                mkdir -p "$PART_DIR"
                STATE=file
                ;;

            *)
                # The block is another part of the current form of a codex chunk.
                NAME=$LINE
                FORM=$(get_chunk_current_form "$NAME")
                PART=$(bump_chunk_part "$NAME" $FORM)
                PART_DIR="$WD/chunks/$NAME/forms/$FORM/parts/$PART"
                mkdir -p "$PART_DIR"
                STATE=chunk
                ;;

            esac
            ;;

        special)
            # I'm parsing a codex special.
            # FIXME: remove this state when all specials are covered by the state machine.
            case $LINE in

                ////)
                    STATE=adoc
                    echo "s$SPECIAL"
                    ;;

            esac
            ;;

        file)
            # I'm parsing part $PART of file $NAME.
            case $LINE in

                ////)
                    # Part $PART of file $NAME ended.
                    test -s "$PART_DIR/content" || {
                        fail "file '$NAME': empty definition."
                    }
                    echo "f$PART,$NAME"
                    STATE=adoc
                    ;;

                *)
                    # Line is part of the definition of the file.
                    parse_chunk_line "$LINE" >>"$PART_DIR/content"
                    ;;

            esac
            ;;

        chunk)
            # I'm parsing part $PART of form $FORM of chunk $NAME.
            case $LINE in

                ////)
                    # Part $PART of form $FORM of chunk $NAME ended.
                    test -s "$PART_DIR/content" || {
                        fail "chunk '$NAME': empty definition."
                    }
                    echo "c$NAME"
                    STATE=adoc
                    ;;

                *)
                    # Line is part of the definition of the chunk.
                    parse_chunk_line "$LINE" >>"$PART_DIR/content"
                    ;;

            esac
            ;;

        reset)
            # I'm parsing a reset directive.
            case $LINE in

                ////)
                    # End or reset directive.
                    STATE=adoc
                    ;;

                *)
                    # Line is the name of a chunk to be reset.
                    bump_chunk_form "$LINE"
                    ;;

            esac
            ;;

        *)
            fail "internal error: unknown state '$STATE'."
            ;;

        esac
    done
}

expand "$TARGET" '' | \
parse
