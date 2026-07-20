#!/usr/bin/env tclsh9
# Copyright © 2026 Mark Summerfield. All rights reserved.
# License: GPLv3
#
# test_altkey.tcl -- mirrors test_altkey.py: reads input.txt /
# expected.txt as blank-line separated paragraphs, runs altkey on
# each, and checks both the exact output and the quality score.

if {![catch {file readlink [info script]} name]} {
    const APPPATH [file dirname $name]
} else {
    const APPPATH [file normalize [file dirname [info script]]]
}
tcl::tm::path add $APPPATH

package require altkey
package require munkres

proc read_lists filename {
    set lists {}
    set current {}
    foreach line [split [readFile $filename] "\n"] {
        set trimmed [string trim $line]
        if {$trimmed eq ""} {
            lappend lists $current
            set current {}
        } elseif {![string match "#*" $trimmed]} {
            lappend current $trimmed
        }
    }
    lappend lists $current
}

set qualities {
    0.75 0.75 0.71 0.33 0.58 0.62 0.72 1 1 0.81 0.65
    0.48 0.62 0.64 0.55 0.61 0.49 0.55 0.63 0.55 0.63
    0.81 0.53 0.57 0.67 0.75 0.62 0.56 0.57 0.57 0.49
    0.0
}

set inputs [read_lists $::APPPATH/input.txt]
set expecteds [read_lists $::APPPATH/expected.txt]

if {[llength $inputs] != [llength $expecteds]} {
    puts "FAIL: input.txt has [llength $inputs] lists but expected.txt has\
          [llength $expecteds]"
    exit 1
}

set fails 0
set total 0
foreach i [lseq [llength $inputs]] {
    set lines [lindex $inputs $i]
    if {[llength $lines] == 0} continue
    incr total
    set actual [altkey::altkey $lines]
    set expected [lindex $expecteds $i]
    set ok 1
    if {$actual ne $expected} {
        set ok 0
        puts "FAIL list #[expr {$i + 1}]:"
        puts "  A=$actual"
        puts "  E=$expected"
    }
    set expected_quality [lindex $qualities $i]
    set actual_quality [altkey::quality $actual]
    if {abs($actual_quality - $expected_quality) > 0.01} {
        set ok 0
        puts "FAIL list #[expr {$i + 1}] quality: got\
              [format %.2f $actual_quality], want\
              [format %.2f $expected_quality]"
    }

    if {!$ok} { incr fails }
}

set outcome [expr {$fails ? "FAIL" : "OK"}]
puts "[expr {$total - $fails}]/$total $outcome." 
