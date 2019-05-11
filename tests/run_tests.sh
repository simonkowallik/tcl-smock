#!/usr/bin/env bash

_tclsh84=$(command -v tclsh8.4)
_tclsh85=$(command -v tclsh8.5)
_tclsh86=$(command -v tclsh8.6)

set -ev

$_tclsh84 tests/test.tcl

$_tclsh85 tests/test.tcl

$_tclsh86 tests/test.tcl
