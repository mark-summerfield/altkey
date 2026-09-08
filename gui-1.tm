# Copyright © 2026 Mark Summerfield. All rights reserved.

package require about_form
package require altkey
package require basic_text_edit
package require config
package require config_form
package require maybe_save_form
package require ui

oo::singleton create Gui {
    variable UnhintedText
    variable HintedText
    variable TheFilename
}

oo::define Gui constructor {} {
    ui::wishinit
    tk appname AltKey
    set TheFilename ""
    Config new ;# we need tk scaling done early
    my make_ui
}

oo::define Gui method show {} {
    wm deiconify .
    wm minsize . 720 640
    wm geometry . [[Config new] geometry]
    raise .
    update
    my on_startup
}

oo::define Gui method make_ui {} {
    my prepare_ui
    my make_widgets
    my make_layout
    my make_bindings
}

oo::define Gui method prepare_ui {} {
    wm title . [tk appname]
    wm iconname . [tk appname]
    wm iconphoto . -default [ui::icon icon.svg]
}

oo::define Gui method make_widgets {} {
    my make_frames
    my make_buttons
    my make_central_area
    my make_statusbar
}

oo::define Gui method make_frames {} {
    ttk::frame .mf
    ttk::frame .mf.cf
    ttk::frame .mf.cf.ctrl_frame
}

oo::define Gui method make_buttons {} {
    set width 8
    ttk::button .mf.cf.ctrl_frame.new_button -text New -underline 0 \
            -command [callback on_new] -width $width -compound left \
            -image [ui::icon document-new.svg $::ICON_SIZE]
    ttk::button .mf.cf.ctrl_frame.open_button -text Open… -underline 0 \
            -command [callback on_open] -width $width -compound left \
            -image [ui::icon document-open.svg $::ICON_SIZE]
    ttk::button .mf.cf.ctrl_frame.save_button -text Save -underline 0 \
            -command [callback on_save] -width $width -compound left \
            -image [ui::icon document-save.svg $::ICON_SIZE]
    ttk::button .mf.cf.ctrl_frame.saveas_button -text "Save As…" \
            -underline 5 -command [callback on_saveas] -width $width \
            -compound left \
            -image [ui::icon document-save-as.svg $::ICON_SIZE]
    ttk::button .mf.cf.ctrl_frame.run_button -text Run -underline 0 \
            -command [callback on_run] -width $width \
            -compound left -image [ui::icon run.svg $::ICON_SIZE]
    ttk::button .mf.cf.ctrl_frame.config_button -text Config… -underline 0 \
            -command [callback on_config] -width $width -compound left \
            -image [ui::icon preferences-system.svg $::ICON_SIZE]
    ttk::button .mf.cf.ctrl_frame.about_button -text About -underline 1 \
            -command [callback on_about] -width $width -compound left \
            -image [ui::icon about.svg $::ICON_SIZE]
    ttk::button .mf.cf.ctrl_frame.quit_button -text Quit -underline 0 \
            -command [callback on_quit] -width $width -compound left \
            -image [ui::icon quit.svg $::ICON_SIZE]
}

oo::define Gui method make_central_area {} {
    ttk::label .mf.cf.unhinted_label -text Unhinted -underline 0
    ttk::label .mf.cf.hinted_label -text Hinted -underline 0
    set UnhintedText [BasicTextEdit new .mf.cf]
    my add_tags [$UnhintedText tk_text]
    set HintedText [BasicTextEdit new .mf.cf]
    $HintedText configure -undo 0
    my add_tags [$HintedText tk_text]
}

oo::define Gui method make_statusbar {} {
    ttk::frame .mf.status_frame
    ttk::label .mf.status_frame.unused_label_label -text Unused
    ttk::label .mf.status_frame.unused_label -relief sunken
    ttk::label .mf.status_frame.done_label_label -text Done 
    ttk::label .mf.status_frame.done_label -text "0/0 • 0%" -relief sunken
}

oo::define Gui method make_layout {} {
    const opts "-pady 3 -padx 3"
    pack .mf.status_frame -fill x -anchor n -side bottom
    my layout_buttons $opts
    my layout_central_area $opts
    pack .mf.cf -fill both -expand 1 -anchor n -side top
    my layout_statusbar $opts
    pack .mf -fill both -expand 1
}

oo::define Gui method layout_buttons opts {
    pack .mf.cf.ctrl_frame.new_button {*}$opts
    pack .mf.cf.ctrl_frame.open_button {*}$opts
    pack .mf.cf.ctrl_frame.save_button {*}$opts
    pack .mf.cf.ctrl_frame.saveas_button {*}$opts
    pack [ttk::label .mf.cf.ctrl_frame.pad1] {*}$opts
    pack .mf.cf.ctrl_frame.run_button {*}$opts
    pack .mf.cf.ctrl_frame.quit_button -side bottom -fill y -anchor s \
            {*}$opts
    pack [ttk::label .mf.cf.ctrl_frame.pad2] -side bottom -fill y \
            -anchor s {*}$opts
    pack .mf.cf.ctrl_frame.about_button -side bottom -fill y -anchor s \
            {*}$opts
    pack .mf.cf.ctrl_frame.config_button -side bottom -fill y -anchor s \
            {*}$opts
}

oo::define Gui method layout_central_area opts {
    grid .mf.cf.ctrl_frame -row 0 -column 0 -rowspan 2 -sticky ns
    grid .mf.cf.unhinted_label -row 0 -column 1
    grid .mf.cf.hinted_label -row 0 -column 2
    grid [$UnhintedText ttk_frame] -row 1 -column 1 -sticky news {*}$opts
    grid [$HintedText ttk_frame] -row 1 -column 2 -sticky news {*}$opts
    grid rowconfigure .mf.cf 1 -weight 1
    grid columnconfigure .mf.cf 1 -weight 1 -uniform 1
    grid columnconfigure .mf.cf 2 -weight 1 -uniform 1
}

oo::define Gui method layout_statusbar opts {
    pack .mf.status_frame.unused_label_label -side left {*}$opts
    pack .mf.status_frame.unused_label -side left -fill x -expand 1 {*}$opts
    pack .mf.status_frame.done_label -side right -fill x {*}$opts
    pack .mf.status_frame.done_label_label -side right {*}$opts
}

oo::define Gui method make_bindings {} {
    bind . <F5> [callback on_run]
    bind . <Alt-a> [callback on_saveas]
    bind . <Alt-b> [callback on_about]
    bind . <Alt-c> [callback on_config]
    bind . <Alt-h> [callback on_hinted]
    bind . <Alt-n> [callback on_new]
    bind . <Control-n> [callback on_new]
    bind . <Alt-o> [callback on_open]
    bind . <Control-o> [callback on_open]
    bind . <Alt-q> [callback on_quit]
    bind . <Control-q> [callback on_quit]
    bind . <Alt-r> [callback on_run]
    bind . <Control-r> [callback on_run]
    bind . <Alt-s> [callback on_save]
    bind . <Control-s> [callback on_save]
    bind . <Alt-u> [callback on_unhinted]
    wm protocol . WM_DELETE_WINDOW [callback on_quit]
}

oo::define Gui method on_startup {} {
    if {$::argc} {
        set TheFilename [lindex $::argv 0]
        my read_file
    } elseif {[set TheFilename [[Config new] last_filename]] ne ""} {
        my read_file
    } else {
        my on_new
    }
}

oo::define Gui method on_unhinted {} { $UnhintedText focus }

oo::define Gui method on_hinted {} { $HintedText focus }

oo::define Gui method on_new {} {
    if {![my maybe_save]} return
    set TheFilename ""
    wm title . "Unsaved — [tk appname]"
    my clear
}

oo::define Gui method on_open {} {
    if {![my maybe_save]} return
    set dir [expr {$TheFilename eq "" ? "." : [file dirname $TheFilename]}]
    if {[set filename [tk_getOpenFile -initialdir $dir \
            -filetypes {{{AltKey files} {.key}} {{All files} {*}}} \
            -title "[tk appname] — Open" -parent .]] ne ""} {
        set TheFilename $filename
        my read_file
    }
}

oo::define Gui method on_save {} {
    if {$TheFilename eq ""} {
        my on_saveas
    } else {
        writeFile $TheFilename [$UnhintedText all]
        $UnhintedText edit modified 0
    }
}

oo::define Gui method on_saveas {} {
    set dir [expr {$TheFilename eq "" ? "." : [file dirname $TheFilename]}]
    if {[set filename [tk_getSaveFile -initialdir $dir \
            -filetypes {{{AltKey files} {.key}} {{All files} {*}}} \
            -title "[tk appname] — Save As" -parent .]] ne ""} {
        set TheFilename $filename
        wm title . "[file tail $TheFilename] — [tk appname]"
        my on_save
    }
}

oo::define Gui method on_run {} {
    if {[$UnhintedText isempty]} return
    $HintedText clear
    set comment ""
    set lines [list]
    foreach line [split [$UnhintedText all] \n] {
        set line [string trim $line]
        if {$line eq ""} {
            my process_lines $lines $comment
            set lines [list]
        } elseif {![string match "#*" $line]} {
            lappend lines $line
        } else {
            set comment $line
        }
    }
    my process_lines $lines $comment
    $HintedText mark set insert 1.0
}

oo::define Gui method on_config {} { ConfigForm new }

oo::define Gui method on_about {} {
    AboutForm new "An Alt+Key Keyboard accelerator helper" \
        https://github.com/mark-summerfield/altkey
}

oo::define Gui method on_quit {} {
    if {![my maybe_save]} return
    set config [Config new]
    $config set_last_filename [file normalize $TheFilename]
    $config save
    exit
}

oo::define Gui method clear {} {
    $HintedText clear
    $UnhintedText clear
    $UnhintedText focus
}

oo::define Gui method read_file {} {
    wm title . "[file tail $TheFilename] — [tk appname]"
    my clear
    $UnhintedText insert end [readFile $TheFilename]
    $UnhintedText mark set insert 1.0
    $UnhintedText edit modified 0
    my on_run
}

oo::define Gui method maybe_save {} {
    if {[$UnhintedText edit modified]} {
        set reply [MaybeSaveForm show "[tk appname] — Unsaved Changes" \
            "Save unsaved changes?"]
        switch $reply {
            cancel { return 0 }
            save { my on_save }
        }
    }
    return 1
}

oo::define Gui method add_tags text_edit {
    $text_edit tag configure ul -foreground blue -underline 1
    $text_edit tag configure green -foreground darkgreen
    $text_edit tag configure gray -foreground gray
}

oo::define Gui method process_lines {lines comment} {
    if {[llength $lines] == 0} { return }
    set hinted [::altkey::altkey $lines]
    if {![$HintedText isempty]} { $HintedText insert end \n }
    if {$comment ne ""} { $HintedText insert end $comment\n }
    foreach line $hinted { $HintedText insert end $line\n }
    puts process_lines ;# TODO update "n/m 0%" and display unused in HintedText
}
