# Copyright © 2026 Mark Summerfield. All rights reserved.

package require lambda 1
package require textutil::adjust

namespace eval clop {
    variable OnExit exit ;# Override for testing
    const NOT_SET "\uFFFD"

    if {[dict exists [chan configure stdout] -mode]} { ;# tty
        const BOLD "\x1B\[1m"
        const ITALIC "\x1B\[3m"
        const RED "\x1B\[31m"
        const GREEN "\x1B\[32m"
        const BLUE "\x1B\[34m"
        const CYAN "\x1B\[36m"
        const MAGENTA "\x1B\[35m"
        const YELLOW "\x1B\[33m"
        const RESET "\x1B\[;0m"
    } else {
        const BOLD ""
        const ITALIC ""
        const RED ""
        const GREEN ""
        const BLUE ""
        const CYAN ""
        const MAGENTA ""
        const YELLOW ""
        const RESET ""
    }
}

# Kind: B=bool D=debug h=help H=full help (subcommand only) N=normal
#       S=subcommand V=version
# Validate: a function that accepts a single arg (the given Value) and
#   which must return either an error message or "".
#   If there's no given Validate function or if Value (i.e., the default
#   is used), the validate method returns "". Only used for N options.
oo::class create clop::Opt { ;# "private" class for use by Parser class
    variable ShortName
    variable LongName
    variable ArgName    ;# subcommand always empty
    variable Kind
    variable DefValue   ;# subcommand: holds a (sub)parser
    variable Value      ;# subcommand: always unset
    variable Help
    variable Hidden     ;# subcommand: always 0
    variable Repeatable ;# subcommand: always 0
    variable Validate   ;# subcommand: always {}
}

oo::define clop::Opt constructor {{shortname ""} {longname ""} {kind N} \
        {defvalue ""} {help ""} {repeatable 0} {hidden 0} {argname ""} \
        {validate {}}} {
    set ShortName $shortname
    set LongName $longname
    set ArgName $argname
    set Kind $kind
    set DefValue [expr {$kind eq "B" && $defvalue eq "" ? 0 : $defvalue}]
    set Value $::clop::NOT_SET
    set Help $help
    set Repeatable $repeatable
    set Hidden $hidden
    set Validate $validate
}

oo::define clop::Opt method shortname {} { return $ShortName }

oo::define clop::Opt method longname {} { return $LongName }

oo::define clop::Opt method argname {} {
    expr {$ArgName eq "" ? [string toupper $LongName] : $ArgName}
}
oo::define clop::Opt method set_argname argname { set ArgName $argname }

oo::define clop::Opt method kind {} { return $Kind }

oo::define clop::Opt method defvalue {} { return $DefValue }

oo::define clop::Opt method repeatable {} { return $Repeatable }

oo::define clop::Opt method get {} {
    expr {$Value eq $::clop::NOT_SET ? $DefValue : $Value}
}
oo::define clop::Opt method value {} { return $Value }
oo::define clop::Opt method set_value value { set Value $value }

oo::define clop::Opt method help {} { return $Help }

oo::define clop::Opt method is_hidden {} { return $Hidden }

oo::define clop::Opt method is_subcommand {} { expr {$Kind in {H S}} }

oo::define clop::Opt method validate value {
    if {$Validate eq {}} { return "" }
    {*}$Validate $value
}

oo::define clop::Opt method to_string {} {
    set validate [expr {$Validate eq {} ? "" : " \[has validator\]"}]
    if {[my is_subcommand]} {
        set short [expr {$ShortName ne "" ? "$ShortName " : ""}]
        set long [expr {$LongName ne "" ? "$LongName " : ""}]
        return "clop::Opt ${short}${long}kind=$Kind help=«$Help»\
                parser=$DefValue"
    } else {
        set short [expr {$ShortName ne "" ? "-$ShortName " : ""}]
        set long [expr {$LongName ne "" ? "--$LongName " : ""}]
        return "clop::Opt ${short}${long}kind=$Kind defvalue=$DefValue\
                value=«$Value» get=«[my get]» help=«$Help»\
                repeatable=$Repeatable hidden=$Hidden\
                argname=$ArgName$validate"
    }
}

oo::class create clop::Parser {
    variable AppName
    variable AppVersion
    variable PreHelp
    variable PostHelp
    variable PostHelpWrap
    variable PositionalName1
    variable PositionalNameN
    variable PositionalHelp
    variable MinPos
    variable MaxPos
    variable PositionalLine
    variable Opts
    variable ShortNames
    variable LongNames
    variable SubparserName
    variable ConfiguredValues
}

proc clop::subparser {name parser {positional_count ""} {shorthelp ""} \
        {longhelp ""} {positional_help ""}} {
    set subparser [Parser new [$parser appname] [$parser appversion] \
                    $positional_count $longhelp $shorthelp $positional_help]
    $subparser set_subparser_name $name
    return $subparser
}

oo::define clop::Parser constructor {appname appversion \
        {positional_count ""} {prehelp ""} {posthelp ""} \
        {positional_help ""}} {
    set AppName $appname
    set AppVersion $appversion
    set SubparserName ""
    my SetPositionalCounts $positional_count
    set PositionalName1 FILE
    set PositionalNameN FILE
    set PositionalLine ""
    set PreHelp $prehelp
    set PostHelp $posthelp
    set PostHelpWrap 1
    set PositionalHelp $positional_help
    set Opts [list]
    set ConfiguredValues [dict create]
}

oo::define clop::Parser method get_opts {} { return $Opts }

oo::define clop::Parser method SetPositionalCounts positional_count {
    if {$positional_count eq ""} {
        lassign {0 0} MinPos MaxPos
    } else {
        if {[regexp {^(\d+)(?:[-](\d+))?$} $positional_count _ m n]} {
            set MinPos [expr {[info exists m] ? $m : 0}]
            set MaxPos [expr {[info exists n] && $n ne "" ? $n : $MinPos}]
            if {$MinPos > $MaxPos} {
                error "invalid positional count $MinPos > $MaxPos"
            }
        } else {
            error "invalid positional count '$positional_count'"
        }
    }
}

oo::define clop::Parser method appname {} { return $AppName }

oo::define clop::Parser method appversion {} { return $AppVersion }

oo::define clop::Parser method HasSubcommand {} { 
    foreach opt $Opts { if {[$opt is_subcommand]} { return 1 } }
    return 0
}

oo::define clop::Parser method n_opts {} { llength $Opts }

oo::define clop::Parser method subparser_name {} { return $SubparserName }
oo::define clop::Parser method set_subparser_name name {
    set SubparserName $name
}

oo::define clop::Parser method configured_values {} {
    return $ConfiguredValues
}
oo::define clop::Parser method set_configured_values configured_values {
    set ConfiguredValues $configured_values
}

oo::define clop::Parser method prehelp {} { return $PreHelp }
oo::define clop::Parser method set_prehelp help { set PreHelp $help }

oo::define clop::Parser method posthelp {} { return $PostHelp }
oo::define clop::Parser method set_posthelp help { set PostHelp $help }

oo::define clop::Parser method posthelp_wrap {} { return $PostHelpWrap }
oo::define clop::Parser method set_posthelp_wrap wrap {
    set PostHelpWrap $wrap
}

oo::define clop::Parser method positional_help {} { return $PositionalHelp }
oo::define clop::Parser method set_positional_help help {
    set PositionalHelp $help
}

oo::define clop::Parser method positional_name1 {} {
    return $PositionalName1
}
oo::define clop::Parser method positional_name_n {} {
    return $PositionalNameN
}
oo::define clop::Parser method set_positional_names \
        {{positional_name1 FILE} {positional_name_n FILE}} {
    set PositionalName1 $positional_name1
    set PositionalNameN $positional_name_n
}

oo::define clop::Parser method minpos {} { return $MinPos }
oo::define clop::Parser method maxpos {} { return $MaxPos }

oo::define clop::Parser method positional_line {} { return $PositionalLine }
oo::define clop::Parser method set_positional_line line {
    set PositionalLine $line
}

oo::define clop::Parser method to_string {} {
    set opts [list]
    foreach opt $Opts { lappend opts [$opt to_string] }
    if {$PositionalLine ne ""} {
        set positionals "positionals=$PositionalLine"
    } else {
        set positionals "positional_name1=$PositionalName1\
            positional_name_n=$PositionalNameN"
    }
    return "clop::Parser appname=$AppName appversion=$AppVersion\
        $positionals minpos=$MinPos maxpos=$MaxPos\
        positional_help=$PositionalHelp prehelp=$PreHelp\
        posthelp=$PostHelp\n[join $opts \n]"
}

oo::define clop::Parser method new_opt {{shortname ""} {longname ""} \
        {defvalue ""} {help ""} {repeatable 0} {argname ""} \
        {validate {}}} {
    if {$shortname eq "" && $longname eq ""} { error "unnamed option" }
    lappend Opts [clop::Opt new $shortname $longname N $defvalue $help \
            $repeatable 0 $argname $validate]
}

oo::define clop::Parser method new_hidden {{shortname ""} \
        {longname ""} {defvalue ""} {help ""} {repeatable 0} {argname ""} \
        {validate {}}} {
    if {$shortname eq "" && $longname eq ""} { error "unnamed option" }
    lappend Opts [clop::Opt new $shortname $longname N $defvalue $help \
            $repeatable 1 $argname $validate]
}

oo::define clop::Parser method new_number {{shortname ""} {longname ""} \
        {defvalue 0} {help ""} {repeatable 0} {argname ""} \
        {minimum 0} {maximum 100}} {
    if {$shortname eq "" && $longname eq ""} { error "unnamed option" }
    set name [expr {$longname ne "" ? $longname : $shortname}]
    lappend Opts [clop::Opt new $shortname $longname N $defvalue $help \
            $repeatable 0 $argname \
            [clop::make_number_validator $name $minimum $maximum]]
}

oo::define clop::Parser method new_choice {{shortname ""} {longname ""} \
        {defvalue 0} {help ""} {repeatable 0} {argname ""} \
        {choices {}}} {
    if {$shortname eq "" && $longname eq ""} { error "unnamed option" }
    set name [expr {$longname ne "" ? $longname : $shortname}]
    lappend Opts [clop::Opt new $shortname $longname N $defvalue $help \
            $repeatable 0 $argname \
            [clop::make_choice_validator $name $choices]]
}

oo::define clop::Parser method new_bool {{shortname ""} {longname ""} \
        {help ""}} {
    if {$shortname eq "" && $longname eq ""} { error "unnamed bool option" }
    lappend Opts [clop::Opt new $shortname $longname B 0 $help]
}

oo::define clop::Parser method new_debug {{shortname D} {longname debug}} {
    if {$shortname eq "" && $longname eq ""} {
        error "unnamed debug option"
    }
    lappend Opts [clop::Opt new $shortname $longname D 0 "" 1 1]
}

oo::define clop::Parser method new_version {{shortname v} \
        {longname version} {help "Show version and quit."}} {
    if {$shortname eq "" && $longname eq ""} {
        error "unnamed version option"
    }
    lappend Opts [clop::Opt new $shortname $longname V "" $help]
        
}

oo::define clop::Parser method new_help {{shortname h} {longname help} \
        {help "Show this help and quit."}} {
    if {$shortname eq "" && $longname eq ""} { error "unnamed help option" }
    lappend Opts [clop::Opt new $shortname $longname h "" $help]
}

# parser stored in DefValue
oo::define clop::Parser method new_subcommand {{shortname ""} \
        {longname ""} {subparser ""} {help ""}} {
    if {$shortname eq "" && $longname eq ""} { error "unnamed subcommand" }
    lappend Opts [clop::Opt new $shortname $longname S $subparser $help]
}

oo::define clop::Parser method new_help_subcommand {{shortname h} \
        {longname help} {subparser ""} {help "Show full help."}} {
    if {$shortname eq "" && $longname eq ""} { error "unnamed subcommand" }
    lappend Opts [clop::Opt new $shortname $longname H $subparser $help]
}

oo::define clop::Parser method on_help {{full 0}} {
    const B $::clop::BOLD
    const I $::clop::ITALIC
    const G $::clop::GREEN
    const L $::clop::BLUE
    const R $::clop::RESET
    const WIDTH [clop::term_width]
    const INDENT "  "
    const IWIDTH [expr {$WIDTH - [string length $INDENT]}]
    set prehelp $PreHelp
    set S ""
    set has_subcmd [my HasSubcommand]
    if {$has_subcmd} {
        set S "${L}SUBCOMMAND$R "
    } elseif {[set subcmd [my subparser_name]] ne ""} {
        set S "${L}$subcmd$R "
        if {$prehelp eq ""} { set prehelp $PostHelp }
    }
    puts -nonewline "${I}usage:${R} ${B}${L}$AppName$R $S$I$G\[OPTIONS\]$R "
    puts [my GetPositionals]
    if {$prehelp ne ""} {
        puts \n[clop::Unescape [textutil::adjust::adjust $prehelp \
                -strictlength 1 -length $WIDTH]]
    }
    if {$has_subcmd} {
        my ShowSubcommands $WIDTH $IWIDTH $full
    } else {
        if {$MaxPos > 0} {
            set subparser [expr {$SubparserName eq "" ? {} : [self]}]
            my ShowPositionals $WIDTH $INDENT $IWIDTH $MinPos \
                $PositionalHelp $subparser $SubparserName
        }
    }
    my ShowOptions $WIDTH $IWIDTH
    if {$PostHelp ne "" && $SubparserName eq ""} {
        set posthelp [expr {$PostHelpWrap \
            ? [textutil::adjust::adjust $PostHelp -strictlength 1 -length \
                $WIDTH] : $PostHelp}]
        puts \n[clop::Unescape $posthelp]
    }
    {*}$::clop::OnExit
}

oo::define clop::Parser method GetPositionals {{subparser {}}} {
    if {[set positional_line [expr {$subparser eq {} ? $PositionalLine \
                                : [$subparser positional_line]}]] ne ""} {
        return [clop::Unescape $positional_line]
    }
    const I $::clop::ITALIC
    const G $::clop::GREEN
    const L $::clop::BLUE
    const M $::clop::MAGENTA
    const R $::clop::RESET
    if {$subparser ne {}} {
        set p1 [$subparser positional_name1]
        set pn [$subparser positional_name_n]
        set minpos [$subparser minpos]
        set maxpos [$subparser maxpos]
    } else {
        if {[my HasSubcommand]} { return $M…$R }
        set p1 $PositionalName1
        set pn $PositionalNameN
        set minpos $MinPos
        set maxpos $MaxPos
    }
    lassign {1 2} p q
    if {$p1 ne $pn} { lassign {"" 1} p q }
    set ENDPOS [expr {$maxpos == 255 ? "n" : $maxpos}]
    if {$minpos == $maxpos} {
        switch $minpos {
            0 { return "" }
            1 { return "$L<$p1>$R" }
            2 { return "$L<${p1}$p> <${pn}$q>$R" }
            3 {
                set r [expr {$q + 1}]
                return "$L<${p1}$p> <${pn}$q> <${pn}$r>$R"
            }
            default { return "$L<${p1}$p> <${pn}$q> … <${pn}$ENDPOS>$R" }
        }
    } else {
        switch $minpos {
            0 { 
                switch $maxpos {
                    1 { return "$G$I\[$p1\]$R" }
                    2 { return "$G$I\[${p1}$p \[${pn}$q\]\]$R" }
                    3 {
                        set r [expr {$q + 1}]
                        return "$G$I\[${p1}$p \[${pn}$q \[${pn}$r\]\]\]$R"
                    }
                    default {
                        return "$G$I\[${p1}$p \[${pn}$q …\
                                \[${pn}$ENDPOS\]\]\]$R"
                    }
                }
            }
            1 {
                switch $maxpos {
                    2 { return "$L<${p1}$p>$R $G$I\[${pn}$q\]$R" }
                    3 {
                        set r [expr {$q + 1}]
                        return "$L<${p1}$p>$R $G$I\[${pn}$q \[${pn}$r\]\]$R"
                    }
                    default {
                        return "$L<${p1}$p>$R $G$I\[${pn}$q\
                                … \[${pn}$ENDPOS\]\]$R"
                    }
                }
            }
            2 {
                set r [expr {$q + 1}]
                switch $maxpos {
                    3 { return "$L<${p1}$p> <${pn}$q>$R $G$I\[${pn}$r\]$R" }
                    default {
                        return "$L<${p1}$p> <${p1}$q>$R $G$I\[${pn}$r\
                            … \[${pn}$ENDPOS\]\]$R"
                    }
                }
            }
            3 {
                set r [expr {$q + 1}]
                set s [expr {$r + 1}]
                return "$L<${p1}$p> <${pn}$q> <${pn}$r>$R $G$I\[${pn}$s …\
                        \[${pn}$ENDPOS\]\]$R"
            }
            default {
                set n [expr {$minpos + 1}]
                switch $maxpos {
                    default {
                        return "$L<${p1}$p> <${pn}$q> … <${pn}$minpos>$R\
                                $G$I\[${pn}$n\] … \[${pn}$ENDPOS\]\]$R"
                    }
                }
            }
        }
    }
}

oo::define clop::Parser method ShowPositionals {WIDTH INDENT IWIDTH minpos \
        positional_help {subparser {}} {name ""}} {
    const I $::clop::ITALIC
    const G $::clop::GREEN
    const L $::clop::BLUE
    const R $::clop::RESET
    set iwidth $IWIDTH
    set indent $INDENT
    set C [expr {$minpos > 0 ? $L : $G}]
    if {$subparser eq {}} {
        set prefix \n$I${C}POSITIONALS:$R
        set newline 0
    } else {
        set prefix [expr {$name ne "" ? "\n$I${C}POSITIONALS:$R " \
                : "  $I${C}positionals:$R [my GetPositionals $subparser]"}]
        set newline 1
    }
    set help_length [expr {[string length $positional_help] + 2}]
    if {!$newline && $help_length < $WIDTH} {
        set out "$prefix [clop::Unescape $positional_help]"
    } else {
        set help [textutil::adjust::adjust $positional_help \
                    -strictlength 1 -length $iwidth]
        set out [string cat "$prefix\n$indent" [clop::Unescape \
                    [textutil::adjust::indent $help $indent 1]]]
    }
    puts $out
}

oo::define clop::Parser method ShowSubcommands {WIDTH IWIDTH {full 0}} {
    const I $::clop::ITALIC
    const L $::clop::BLUE
    const R $::clop::RESET
    puts "\n$I${L}SUBCOMMANDS:$R"
    lassign [my GetSubItemsAndWidth] items max_opt_width
    incr max_opt_width 2
    set indent [string repeat " " $max_opt_width]
    set help_width [expr {$WIDTH - $max_opt_width}]
    foreach item $items {
        lassign $item opt line
        set subparser [$opt defvalue]
        puts -nonewline $line
        set width [string length [regsub -all {\x1B\[;?\d+m} $line ""]]
        if {$width < $max_opt_width} {
            puts -nonewline [string repeat " " \
                                [expr {$max_opt_width - $width}]]
        }
        if {[set help [my GetSubHelp $opt $subparser $full]] ne ""} {
            set width [string length [regsub -all {%.} $help ""]]
            if {$max_opt_width + $width < $WIDTH} {
                puts [clop::Unescape $help]
            } else {
                set wrapped [textutil::adjust::adjust $help \
                    -strictlength 1 -length $help_width]
                puts [clop::Unescape [textutil::adjust::indent \
                        $wrapped $indent 1]]
            }
        } else {
            puts ""
        }
        if {$full} {
            my ShowSubPositionalsAndOpts $subparser $WIDTH $IWIDTH $indent
        }
    }
}

oo::define clop::Parser method GetSubItemsAndWidth {} {
    const I $::clop::ITALIC
    const L $::clop::BLUE
    const R $::clop::RESET
    set max_opt_width 0
    set items [list]
    foreach opt $Opts {
        if {[$opt is_subcommand]} {
            if {[set shortname [$opt shortname]] ne ""} {
                set shortname "${L}$shortname${R}"
            } else {
                set shortname ""
            }
            if {[set longname [$opt longname]] ne ""} {
                set prefix [expr {$shortname ne "" ? " ${I}or${R} " : ""}]
                set longname "$prefix${L}$longname${R}"
            }
            set line "$shortname$longname"
            lappend items [list $opt $line]
            set width [string length [regsub -all {\x1B\[;?\d+m} $line ""]]
            if {$width > $max_opt_width} { set max_opt_width $width }
        }
    }
    list $items $max_opt_width
}

oo::define clop::Parser method GetSubHelp {opt subparser full} {
    set help [$opt help]
    if {$full || $help eq ""} {
        set full_help ""
        if {$full} { set full_help [$subparser prehelp] }
        if {$full_help eq ""} { set full_help [$subparser posthelp] }
        if {$full_help ne ""} { set help $full_help }
    }
    return $help
}

oo::define clop::Parser method ShowSubPositionalsAndOpts {subparser WIDTH \
        IWIDTH indent} {
    if {[$subparser maxpos]} {
        my ShowPositionals [expr {$WIDTH - 8}] $indent \
            [expr {$IWIDTH - 8}] [$subparser minpos] \
            [$subparser positional_help] $subparser
    }
    if {[$subparser n_opts]} {
        my ShowOptions $WIDTH $IWIDTH $subparser
    } else {
        puts ""
    }
}

oo::define clop::Parser method ShowOptions {WIDTH IWIDTH {subparser {}}} {
    const G $::clop::GREEN
    const I $::clop::ITALIC
    const R $::clop::RESET
    puts "$G${I}[expr {$subparser eq {} ? "\nOPTIONS" : "  suboptions"}]:$R"
    lassign [my GetOptionsAndWidth $subparser] items max_opt_width
    incr max_opt_width 2
    set indent [string repeat " " $max_opt_width]
    set help_width [expr {$WIDTH - $max_opt_width}]
    foreach item $items {
        lassign $item opt line
        if {![$opt is_hidden] && ![$opt is_subcommand]} {
            puts -nonewline $line
            set width [string length [regsub -all {\x1B\[;?\d+m} $line ""]]
            if {$width < $max_opt_width} {
                puts -nonewline [string repeat " " \
                                    [expr {$max_opt_width - $width}]]
            }
            if {[set help [$opt help]] ne ""} {
                set def_width [expr {[string match *%D* $help] \
                                ? [string length [$opt defvalue]] : 0}]
                set width [string length [regsub -all {%.} $help ""]]
                if {$max_opt_width + $width + $def_width < $WIDTH} {
                    puts [clop::Unescape $help [$opt defvalue]]
                } else {
                    set wrapped [textutil::adjust::adjust $help \
                        -strictlength 1 \
                        -length [expr {$help_width - $def_width}]]
                    puts [clop::Unescape [textutil::adjust::indent \
                            $wrapped $indent 1] [$opt defvalue]]
                }
            } else {
                puts ""
            }
        }
    }
}

oo::define clop::Parser method GetOptionsAndWidth {{subparser {}}} {
    const I $::clop::ITALIC
    const G $::clop::GREEN
    const L $::clop::BLUE
    const R $::clop::RESET
    set indent [expr {$subparser eq {} ? "  " : "    "}]
    set opts [expr {$subparser eq {} ? $Opts : [$subparser get_opts]}]
    set max_opt_width 0
    set items [list]
    foreach opt $opts {
        if {![$opt is_hidden] && ![$opt is_subcommand]} {
            if {[set shortname [$opt shortname]] ne ""} {
                set shortname "${G}-$shortname${R}"
            } else {
                set shortname "  "
            }
            if {[set longname [$opt longname]] ne ""} {
                set prefix [expr {[string trim $shortname] ne "" \
                                    ? " ${I}or${R} " : "    "}]
                set longname "$prefix${G}--$longname${R}"
            }
            set argname [expr {[$opt kind] ne "N" ? "" \
                                : " $I$L[$opt argname]$R"}]
            set line $indent$shortname$longname$argname
            lappend items [list $opt $line]
            set width [string length [regsub -all {\x1B\[;?\d+m} $line ""]]
            if {$width > $max_opt_width} { set max_opt_width $width }
        }
    }
    list $items $max_opt_width
}

oo::define clop::Parser method parse argv {
    my CheckNamesAreUnique
    if {[set pairs [my ParseSubcommand $argv]] ne {}} { return $pairs }
    set pairs [dict create % "" * ""]
    set in_options 1
    for {set i 0} {$i < [llength $argv]} {incr i} { ;# read given options
        set arg [lindex $argv $i]
        if {$in_options} {
            if {$arg eq "--"} {
                set in_options 0
            } elseif {[string match -* $arg]} {
                set i [my ReadOption pairs $arg $argv $i]
            } else {
                set in_options 0
                dict lappend pairs % $arg
            }
        } else {
            dict lappend pairs % $arg
        }
    }
    set opt_for_name [my SetValuesForUnspecifiedOptions pairs]
    my ValidateOptions $opt_for_name $pairs
    my CheckPositionalCount [llength [dict get $pairs %]]
    return $pairs
}

oo::define clop::Parser method ParseSubcommand argv {
    if {[my HasSubcommand] && [llength $argv]} {
        set subcmd [lindex $argv 0]
        if {![string match {-*} $subcmd]} {
            foreach opt $Opts {
                set longname [$opt longname]
                set shortname [$opt shortname]
                if {[$opt is_subcommand] && ($longname eq $subcmd || \
                                             $shortname eq $subcmd)} {
                    if {[$opt kind] eq "H"} { my on_help 1 ;# no return }
                    set name [expr {$longname ne "" ? $longname \
                                                    : $shortname}]
                    if {[set subparser [$opt defvalue]] ne {}} {
                        set pairs [$subparser parse [lrange $argv 1 end]]
                        dict set pairs * $name
                        return $pairs
                    } else {
                        clop::on_error \
                            "missing subparser for subcommand “$name”" 1
                    }
                }
            }
            clop::on_error "unrecognized subcommand “$subcmd”" 1
        }
    }
}

oo::define clop::Parser method ReadOption {pairs_ arg argv i} {
    upvar $pairs_ pairs
    set arg [string range $arg 1 end]
    set argv [lrange $argv $i+1 end]
    if {[dict exists $ShortNames $arg]} { ;# -x or -y Val
        set i [my ReadShortOption pairs $arg $argv $i]
    } else {
        if {[string match -* $arg]} { ;# --bool or --long Val or --long=Val
            set i [my ReadLongOption pairs $arg $argv $i]
        } else { ;# -vwx or -y=Val or -vwxyVal or -vwxy=Val
            set i [my ReadGroupedShortOptions pairs $arg $argv $i]
        }
    }
    return $i
}

oo::define clop::Parser method ReadShortOption {pairs_ arg argv i} {
    upvar $pairs_ pairs
    set opt [my MaybeOptionForName $arg] ;# may not return
    if {[set longname [$opt longname]] ne ""} { set arg $longname }
    if {[$opt kind] in {B D}} {
        set value 1
    } else {
        set value [lindex $argv 0]
        incr i
    }
    if {[$opt repeatable]} {
        dict lappend pairs $arg $value
    } else {
        dict set pairs $arg $value
    }
    return $i
}

oo::define clop::Parser method ReadLongOption {pairs_ arg argv i} {
    upvar $pairs_ pairs
    set arg [string range $arg 1 end]
    if {[dict exists $LongNames $arg]} { ;# --bool or --long Val
        set opt [my MaybeOptionForName $arg] ;# may not return
        if {[$opt kind] in {B D}} {
            set value 1
        } else {
            set value [lindex $argv 0]
            incr i
        }
        if {[$opt repeatable]} {
            dict lappend pairs $arg $value
        } else {
            dict set pairs $arg $value
        }
    } else { ;# --long=Val
        if {[set j [string first = $arg]] > -1} {
            set value [string range $arg $j+1 end]
            set arg [string range $arg 0 $j-1]
            if {[dict exists $LongNames $arg]} {
                set opt [my MaybeOptionForName $arg] ;# may not return
                if {[$opt repeatable]} {
                    dict lappend pairs $arg $value
                } else {
                    dict set pairs $arg $value
                }
            } else {
                clop::on_error "unrecognized long option name '$arg'" 1
            }
        } else {
            clop::on_error "unrecognized long option name '$arg'" 1
        }
    }
    return $i
}

oo::define clop::Parser method ReadGroupedShortOptions {pairs_ arg argv i} {
    upvar $pairs_ pairs
    for {set j 0} {$j < [string length $arg]} {incr j} {
        set a [string index $arg $j]
        if {[dict exists $ShortNames $a]} {
            set opt [my MaybeOptionForName $a] ;# may not return
            if {[set longname [$opt longname]] ne ""} { set a $longname }
            if {[$opt kind] in {B D}} {
                if {[$opt repeatable]} {
                    dict lappend pairs $a 1
                } else {
                    dict set pairs $a 1
                }
            } else {
                if {[set value [string range $arg $j+1 end]] eq ""} {
                    set value [lindex $argv 0]
                    incr i
                }
                if {[$opt repeatable]} {
                    dict lappend pairs $a $value
                } else {
                    dict set pairs $a $value
                }
                break
            }
        } else {
            clop::on_error "unrecognized short option name '$a'" 1
        }
    }
    return $i
}

oo::define clop::Parser method MaybeOptionForName name {
    foreach opt $Opts {
        if {[$opt shortname] eq $name || [$opt longname] eq $name} {
            if {[$opt kind] in {h H}} { my on_help }    ;# no return
            if {[$opt kind] eq "V"} { my Version }      ;# no return
            return $opt
        }
    }
}

oo::define clop::Parser method SetValuesForUnspecifiedOptions pairs_ {
    upvar $pairs_ pairs
    set opt_for_name [dict create]
    foreach opt $Opts {
        if {[$opt kind] ni {h H V}} {
            set name ""
            if {[set longname [$opt longname]] ne ""} {
                dict set opt_for_name $longname $opt
                if {![dict exists $pairs $longname]} {
                    set name $longname
                }
            } elseif {$name eq ""} {
                if {[set shortname [$opt shortname]] ne ""} {
                    dict set opt_for_name $shortname $opt
                    if {![dict exists $pairs $shortname]} {
                        set name $shortname
                    }
                }
            }
            if {$name ne ""} {
                dict set pairs $name \
                    [dict getdef $ConfiguredValues $name [$opt get]]
            }
        }
    }
    return $opt_for_name
}

oo::define clop::Parser method ValidateOptions {opt_for_name pairs} {
    dict for {name value} $pairs {
        if {[set opt [dict getdef $opt_for_name $name {}]] ne {}} {
            if {[set msg [$opt validate $value]] ne ""} {
                clop::on_error $msg ;# no return
            }
        }
    }
}

oo::define clop::Parser method CheckNamesAreUnique {} {
    set short_list [list]
    set ShortNames [dict create]
    set long_list [list]
    set LongNames [dict create]
    set short_subcmd_list [list]
    set long_subcmd_list [list]
    foreach opt $Opts {
        if {[set short [$opt shortname]] ne ""} {
            if {[$opt is_subcommand]} {
                lappend short_subcmd_list $short
            } else {
                lappend short_list $short
                dict set ShortNames $short ""
            }
        }
        if {[set long [$opt longname]] ne ""} {
            if {[$opt is_subcommand]} {
                lappend long_subcmd_list $short
            } else {
                lappend long_list $long
                dict set LongNames $long ""
            }
        }
    }
    if {[set dup [clop::FindDuplicate $short_list]] ne ""} {
        error "duplicate short option name '$dup'"
    }
    if {[set dup [clop::FindDuplicate $short_subcmd_list]] ne ""} {
        error "duplicate short subcommand name '$dup'"
    }
    if {[set dup [clop::FindDuplicate $long_list]] ne ""} {
        error "duplicate long option name '$dup'"
    }
    if {[set dup [clop::FindDuplicate $long_subcmd_list]] ne ""} {
        error "duplicate long subcommand name '$dup'"
    }
}

oo::define clop::Parser method CheckPositionalCount pos_count {
    if {$pos_count < $MinPos} {
        clop::on_error "too few positional arguments; expected $MinPos,\
            got $pos_count" 1
    } elseif {$MaxPos != 255 && $pos_count > $MaxPos} {
        clop::on_error "too many positional arguments; expected $MaxPos,\
            got $pos_count" 1
    }
}

oo::define clop::Parser method Version {} {
    puts $AppVersion
    {*}$::clop::OnExit
}

proc clop::dump {opts {print 1}} {
    set out [list]
    if {$print} { lappend out "opts=\n" }
    foreach key [lsort -dictionary [dict keys $opts]] {
        if {$key eq "%"} { continue }
        set value [dict get $opts $key]
        lappend out " $key: «$value»\n"
    }
    set positionals [dict get $opts %]
    if {[llength $positionals]} {
        set sep ""
        lappend line " %: \["
        foreach value $positionals {
            lappend line $sep«$value»
            set sep " "
        }
        lappend line "\]"
        lappend out [join $line ""]
    } else {
        lappend out " %: \[\]"
    }
    set out [join $out]
    if {$print} { puts $out } else { return $out }
}

proc clop::FindDuplicate lst {
    set lst_su [lsort -unique $lst]
    if {[llength $lst_su] < [llength $lst]} {
        set lst [lsort $lst]
        set prev [lindex $lst 0]
        foreach x [lrange $lst 1 end] {
            if {$x eq $prev} { return $x }
            set prev $x
        }
    }
} 

proc clop::Unescape {txt {defval ""}} {
    regsub -all -command {%.} $txt [lambda {defval pc} {
        switch $pc {
            %B { return $::clop::BOLD }
            %I { return $::clop::ITALIC }
            %r { return $::clop::RED }
            %g { return $::clop::GREEN }
            %b { return $::clop::BLUE }
            %c { return $::clop::CYAN }
            %m { return $::clop::MAGENTA }
            %y { return $::clop::YELLOW }
            %! { return $::clop::RESET }
            %D { return "$::clop::MAGENTA$defval$::clop::RESET" }
            %% { return % }
        }
    } $defval]
}

proc clop::on_warn msg {
    puts "${::clop::RED}warning: ${msg}$::clop::RESET"
}

proc clop::on_error {msg {ecode 2}} {
    puts "${::clop::RED}error: ${msg}$::clop::RESET"
    {*}$::clop::OnExit $ecode
}

proc clop::make_number_validator {name minimum maximum} {
    lambda {name minimum maximum value} {
        if {![string is double $value]} {
            return "expected a number for $name; got $value."
        }
        if {$value < $minimum || $value > $maximum} {
            return "expected a number \[$minimum,$maximum\] for $name;\
                got $value."
        }
    } $name $minimum $maximum
}

proc clop::make_choice_validator {name choices} {
    lambda {name choices value} {
        if {$value ni $choices} {
            return "expected $name to be one of: [join $choices];\
                got $value."
        }
    } $name $choices
}

proc clop::term_width {{defwidth 72}} {
    if {[dict exists [chan configure stdout] -mode]} { ;# tty
        return [lindex [chan configure stdout -winsize] 0]
    }
    set defwidth ;# redirected
}
