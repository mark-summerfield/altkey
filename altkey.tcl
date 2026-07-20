#!/usr/bin/env tclsh9
# Copyright © 2026 Mark Summerfield. All rights reserved.

if {![catch {file readlink [info script]} name]} {
    const APPPATH [file dirname $name]
} else {
    const APPPATH [file normalize [file dirname [info script]]]
}
tcl::tm::path add $APPPATH

package require altkey
package require clop

proc main {} {
    set parser [clop::Parser new altkey 1.0.0 1 $::PREHELP $::POSTHELP \
        "The input %bFILE%! with lines of menu options or dialog labels."]
    $parser set_posthelp_wrap 0
    $parser new_bool i index "Precede each line with the index position\
        of the character to be accelerated \[default precede with %y&%!\]."
    $parser new_bool q quality "Add an extra line indicating the quality\
        and if <100%% show any unused characters."
    $parser new_version
    $parser new_help
    if {![llength $::argv]} { $parser on_help }
    set opts [$parser parse $::argv]
    set show_quality [dict get $opts quality]
    set show_indexes [dict get $opts index]
    foreach filename [dict get $opts %] {
        process_text [readFile $filename] $show_quality $show_indexes
    }
}

proc process_text {text show_quality show_indexes} {
    set lines [list]
    foreach line [split $text \n] {
        set line [string trim $line]
        if {$line eq ""} {
            process_list $lines $show_quality $show_indexes
            set lines [list]
        } elseif {![string match "#*" $line]} {
            lappend lines $line
        }
    }
    process_list $lines $show_quality $show_indexes
}

proc process_list {lines show_quality show_indexes} {
    if {[llength $lines] == 0} { return }
    set result [::altkey::altkey $lines]
    set unused [dict create]
    foreach c [split $::altkey::ALPHABET ""] { dict set unused $c {} }
    foreach line $result {
        if {[set i [string first & $line]] >= 0} {
            set c [string toupper [string index $line $i+1]]
            set unused [dict remove $unused $c]
        }
        if {$show_indexes} {
            if {$i >= 0} {
                puts [format "%2d %s" $i [regsub & $line ""]]
            } else {
                puts $line
            }
        } else {
            puts $line
        }
    }
    if {$show_quality} {
        set quality [::altkey::quality $result]
        set prefix [expr {$show_indexes ? "" : "# "}]
        puts [format "${prefix}Quality: %.0f%%" [expr {$quality * 100}]]
        if {$quality < 1} {
            puts "${prefix}Unused:  [join [lsort -dictionary \
                    [dict keys $unused]] ""]"
        }
    }
    puts ""
}

const PREHELP {The input %bFILE%! is just plain text lines with one menu
    option or dialog label per line and with any preset accelerators
    preceded by an ampersand. If you want to have multiple lists (e.g.,
    File menu, Edit menu, a dialog, etc.), just separate each list with
    a blank line. Comments may be included on lines that begin with %y#%!.}

const POSTHELP {%mExample:%!

%IInput       | Default output | Output with %g-i%!
------------+----------------+---------------
# Edit menu |                |
Undo        | %y&%!Undo          |%y0%! Undo       
Redo        | %y&%!Redo          |%y0%! Redo       
Copy        | %y&%!Copy          |%y0%! Copy       
Cu%y&%!t        | Cu%y&%!t           |%y2%! Cut       
Paste       | %y&%!Paste         |%y0%! Paste      
Find        | %y&%!Find          |%y0%! Find       
Find Again  | Find %y&%!Again    |%y5%! Find Again}


main
