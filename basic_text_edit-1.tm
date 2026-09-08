# Copyright © 2026 Mark Summerfield. All rights reserved.

package require ntext 1
package require scrollutil_tile 2

oo::class create BasicTextEdit {
    variable Frame
    variable Text
}

oo::define BasicTextEdit constructor parent {
    classvariable N
    if {![string match *. $parent]} { set parent $parent. }
    set Frame ${parent}tf#[incr N] ;# unique
    ttk::frame $Frame
    set sa [scrollutil::scrollarea $Frame.sa -xscrollbarmode none]
    set Text [text $Frame.sa.txt -undo 1 -wrap word]
    $sa setwidget $Text
    pack $sa -fill both -expand 1
    $Text configure -font TkDefaultFont
    my MakeBindings
}

oo::define BasicTextEdit method MakeBindings {} {
    set ::ntext::tabColor ""
    bindtags $Text [list $Text Ntext [winfo toplevel $Text] all]
    bind $Text <Control-Prior> [callback on_ctrl_prior]
    bind $Text <Control-Next> [callback on_ctrl_next]
    bind $Text <Control-Delete> [callback on_ctrl_del]
    bind $Text <Control-BackSpace> [callback on_ctrl_bs]
    bind $Text <Control-a> [callback on_ctrl_a]
    bind $Text <Control-'> [callback on_ctrl_single_quote]
    bind $Text <'> [callback on_single_quote]
}

oo::define BasicTextEdit method unknown {the_method args} {
    $Text $the_method {*}$args
}

oo::define BasicTextEdit method focus {} { focus $Text }

oo::define BasicTextEdit method ttk_frame {} { return $Frame }

oo::define BasicTextEdit method tk_text {} { return $Text }

oo::define BasicTextEdit method isempty {} {
    expr {[string trim [$Text get 1.0 end]] eq ""}
}

oo::define BasicTextEdit method clear {} {
    $Text delete 1.0 end
    $Text edit reset
    $Text edit modified 0
}

oo::define BasicTextEdit method all {} { string trim [$Text get 1.0 end] }

oo::define BasicTextEdit method first_line {} {
    string trim [$Text get 1.0 2.0]
}

oo::define BasicTextEdit method selected {} {
    if {[set indexes [$Text tag ranges sel]] ne ""} {
        return $indexes
    }
    return "[$Text index "insert wordstart"] [$Text index "insert wordend"]"
}

oo::define BasicTextEdit method get_whole_word {} {
    set a [$Text index "insert linestart"]
    set b [$Text index "insert lineend"]
    set c [$Text index "insert wordstart"]
    set i [$Text search -backwards -exact " " $c "$a -1 char"]
    if {$i eq ""} { set i $a }
    set j [$Text search -exact " " insert "$b +1 char"]
    if {$j eq ""} { set j [$Text index $b] }
    string trim [string trimright [$Text get $i $j] ",;:!?."]
}

oo::define BasicTextEdit method on_undo {} {
    if {[$Text edit canundo]} { $Text edit undo }
}

oo::define BasicTextEdit method on_redo {} {
    if {[$Text edit canredo]} { $Text edit redo }
}

oo::define BasicTextEdit method on_copy {} { tk_textCopy $Text }

oo::define BasicTextEdit method on_cut {} { tk_textCut $Text }

oo::define BasicTextEdit method on_paste {} { tk_textPaste $Text }

oo::define BasicTextEdit method on_ctrl_prior {} {
    $Text mark set insert [$Text index @0,0]
}

oo::define BasicTextEdit method on_ctrl_next {} {
    $Text mark set insert \
        [$Text index "@0,[expr {[winfo height $Text] - 1}]"]
}

oo::define BasicTextEdit method on_ctrl_bs {} {
    set i [$Text index "insert -1c"]
    set x [$Text index "$i wordstart"]
    set y [$Text index "$x wordend"]
    $Text delete $x $y
    return -code break
}

oo::define BasicTextEdit method on_ctrl_del {} {
    set i [$Text index "insert +1c"]
    set x [$Text index "$i wordstart"]
    set y [$Text index "$x wordend"]
    $Text delete $x $y
    return -code break
}

oo::define BasicTextEdit method on_ctrl_a {} { $Text tag add sel 1.0 end }

oo::define BasicTextEdit method on_ctrl_single_quote {} {
    $Text insert insert '
    return -code break
}

oo::define BasicTextEdit method on_single_quote {} {
    $Text insert insert ’
    return -code break
}
