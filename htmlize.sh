#!/bin/bash
set -v
exec asciidoctor --backend html5 --failure-level WARN --verbose codedoc.adoc 
