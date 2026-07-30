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
    set prehelp "$prehelp will override the defaults."
    set parser [clop::Parser new altkey 1.1.0 1-2 $prehelp $::POSTHELP \
        "The input %bINFILE%! with lines of menu options or dialog labels.
        The output %gOUTFILE%! is where the result is written \[default
        %ystdout%!\]."]
    $parser set_positional_line "%b<INFILE>%! %g\[OUTFILE\]%!"
    $parser set_posthelp_wrap 0
    if {$filename ne ""} {
        $parser set_configured_values [read_ini $filename]
    }
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
    set filenames [dict get $opts %]
    set infile [lindex $filenames 0]
    set outfile [expr {[llength $filenames] > 1 ? [lindex $filenames 1] \
                                                : "stdout"}]
    process_input [readFile $infile] $outfile $show_quality $show_indexes
}

proc read_ini filename {
    set configured_values [dict create]
    foreach line [split [readFile $filename] \n] {
        switch $line {
            -i - --index { dict set configured_values index 1 }
            -q - --quality { dict set configured_values quality 1 }
        }
    }
    return $configured_values
}

proc process_input {text outfile show_quality show_indexes} {
    if {$outfile eq "stdout"} {
        set out stdout
    } else {
        set out [open $outfile w]
        chan configure $out -encoding utf-8
    }
    try {
        set lines [list]
        foreach line [split $text \n] {
            set line [string trim $line]
            if {$line eq ""} {
                process_lines $out $lines $show_quality $show_indexes
                set lines [list]
            } elseif {![string match "#*" $line]} {
                lappend lines $line
            }
        }
        process_lines $out $lines $show_quality $show_indexes
    } finally {
        if {$outfile ne "stdout"} { close $out }
    }
}

proc process_lines {out lines show_quality show_indexes} {
    if {[llength $lines] == 0} { return }
    set result [::altkey::altkey $lines]
    set unused [print_result $out $result $show_indexes]
    if {$show_quality} { print_quality $out $result $show_indexes $unused }
    puts $out ""
}

proc print_result {out result show_indexes} {
    set unused [dict create]
    foreach c [split $::altkey::ALPHABET ""] { dict set unused $c {} }
    foreach line $result {
        if {[set i [string first & $line]] >= 0} {
            set c [string toupper [string index $line $i+1]]
            set unused [dict remove $unused $c]
        }
        if {$show_indexes} {
            print_line $out [expr {$i >= 0 ? [format "%2d %s" $i $line] \
                                      : "   $line"}] 1
        } else {
            print_line $out $line
        }
    }
    return $unused
}

proc print_line {out line {drop_ampersand 0}} {
    if {$out eq "stdout"} {
        const H $::clop::BOLD$::clop::BLUE
        const R $::clop::RESET
        set replacement [expr {$drop_ampersand ? "${H}\\1$R" \
                                               : "\\&${H}\\1$R"}]
        puts $out [expr {$::TTY ? [regsub {&(.)} $line $replacement] \
                                : $line}]
    } else {
        if {$drop_ampersand} { set line [regsub & $line ""] }
        puts $out $line
    }
}

proc print_quality {out result show_indexes unused} {
    set quality [::altkey::quality $result]
    set prefix [expr {$show_indexes ? "" : "# "}]
    puts $out [format "${prefix}Quality: %.0f%%" [expr {$quality * 100}]]
    if {$quality < 1} {
        set unused [join [lsort -dictionary [dict keys $unused]] "" ]
        if {[set i [regexp -indices -inline {[A-Z]} $unused]] ne {}} {
            set i [lindex [lindex $i 0] 0]
            set unused "[string range $unused 0 $i-1] [string range \
                    $unused $i end]"
        }
        puts $out "${prefix}Unused:  $unused"
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

const PREHELP {The input %bINFILE%! is just plain text lines with one menu
    option or dialog label per line and with any preset accelerators
    preceded by an ampersand. The output is written to the %gOUTFILE%!
    if given, otherwise to %ystdout%!. If you want to have multiple
    lists (e.g., File menu, Edit menu, a dialog, etc.), just separate
    each list with a blank line. Comments may be included on lines that
    begin with %y#%!. The %g-i%! or %g--index%! and %g-q%! or
    %g--quality%! options may be specified one per line in the file}

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
