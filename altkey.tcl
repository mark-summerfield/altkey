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
    set prehelp $::PREHELP
    if {[set filename [get_ini_filename]] ne ""} {
        set prehelp "$prehelp %y$filename%!; this"
    } else {
        set prehelp "$prehelp %yaltkey.cfg%! in the user’s\
            configuration folder and"
    }
    set prehelp "$prehelp will override the command line."
    set parser [clop::Parser new altkey 1.1.0 1 $prehelp $::POSTHELP \
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
    if {$filename ne ""} { read_ini $filename show_quality show_indexes }
    foreach filename [dict get $opts %] {
        process_input [readFile $filename] $show_quality $show_indexes
    }
}

proc read_ini {filename show_quality_ show_indexes_} {
    upvar 1 $show_quality_ show_quality
    upvar 1 $show_indexes_ show_indexes
    foreach line [split [readFile $filename] \n] {
        switch $line {
            -i - --index { set show_indexes 1 }
            -q - --quality { set show_quality 1 }
        }
    }
}

proc process_input {text show_quality show_indexes} {
    set lines [list]
    foreach line [split $text \n] {
        set line [string trim $line]
        if {$line eq ""} {
            process_lines $lines $show_quality $show_indexes
            set lines [list]
        } elseif {![string match "#*" $line]} {
            lappend lines $line
        }
    }
    process_lines $lines $show_quality $show_indexes
}

proc process_lines {lines show_quality show_indexes} {
    if {[llength $lines] == 0} { return }
    set result [::altkey::altkey $lines]
    set unused [print_result $result $show_indexes]
    if {$show_quality} { print_quality $result $show_indexes $unused }
    puts ""
}

proc print_result {result show_indexes} {
    set unused [dict create]
    foreach c [split $::altkey::ALPHABET ""] { dict set unused $c {} }
    foreach line $result {
        if {[set i [string first & $line]] >= 0} {
            set c [string toupper [string index $line $i+1]]
            set unused [dict remove $unused $c]
        }
        if {$show_indexes} {
            print_line [expr {$i >= 0 ? [format "%2d %s" $i $line] \
                                      : "   $line"}] 1
        } else {
            print_line $line
        }
    }
    return $unused
}

proc print_line {line {drop_ampersand 0}} {
    const H $::clop::BOLD$::clop::BLUE
    const R $::clop::RESET
    set replacement [expr {$drop_ampersand ? "${H}\\1$R" : "\\&${H}\\1$R"}]
    puts [expr {$::TTY ? [regsub {&(.)} $line $replacement] : $line}]
}

proc print_quality {result show_indexes unused} {
    set quality [::altkey::quality $result]
    set prefix [expr {$show_indexes ? "" : "# "}]
    puts [format "${prefix}Quality: %.0f%%" [expr {$quality * 100}]]
    if {$quality < 1} {
        set unused [join [lsort -dictionary [dict keys $unused]] "" ]
        if {[set i [regexp -indices -inline {[A-Z]} $unused]] ne {}} {
            set i [lindex [lindex $i 0] 0]
            set unused "[string range $unused 0 $i-1] [string range \
                    $unused $i end]"
        }
        puts "${prefix}Unused:  $unused"
    }
}

proc get_ini_filename {} {
    set name altkey.cfg
    set home [file home]
    set names [list [file join $home .config/$name] \
                    [file join $home .$name] $::APPPATH/$name]
    set index [expr {[file isdirectory [file join $home .config]] ? 0 : 1}]
    foreach name $names {
        set name [file normalize $name]
        if {[file exists $name]} { return $name }
    }
}

const PREHELP {The input %bFILE%! is just plain text lines with one menu
    option or dialog label per line and with any preset accelerators
    preceded by an ampersand. If you want to have multiple lists (e.g.,
    File menu, Edit menu, a dialog, etc.), just separate each list with
    a blank line. Comments may be included on lines that begin with
    %y#%!. The %g-i%! or %g--index%! and %g-q%! or %g--quality%! options
    may be specified one per line in the file}

const POSTHELP {%mExample:%!

%IInput       | Default output | Output with %g-i%!
------------+----------------+---------------
# Edit menu |                |
Undo        | &%B%bU%!ndo          |0 %B%bU%!ndo       
Redo        | &%B%bR%!edo          |0 %B%bR%!edo       
Copy        | &%B%bC%!opy          |0 %B%bC%!opy       
Cu%y&%!t        | Cu&%B%bt%!           |2 Cu%B%bt%!
Paste       | &%B%bP%!aste         |0 %B%bP%!aste      
Find        | &%B%bF%!ind          |0 %B%bF%!ind       
Find Again  | Find &%B%bA%!gain    |5 Find %B%bA%!gain}

const TTY [dict exists [chan configure stdout] -mode]

main
