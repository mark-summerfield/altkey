# Copyright © 2026 Mark Summerfield. All rights reserved.

package require about_form
package require basic_text_edit
package require config
package require config_form
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
    my on_unhinted
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
    ttk::frame .mf
    ttk::frame .mf.cf
    ttk::frame .mf.cf.ctrl_frame
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
    ttk::label .mf.cf.unhinted_label -text Unhinted -underline 0
    ttk::label .mf.cf.hinted_label -text Hinted -underline 0
    set UnhintedText [BasicTextEdit new .mf.cf]
    my add_tags [$UnhintedText tk_text]
    set HintedText [BasicTextEdit new .mf.cf]
    my add_tags [$HintedText tk_text]
    ttk::frame .mf.status_frame
    ttk::label .mf.status_frame.unused_label_label -text Unused
    ttk::label .mf.status_frame.unused_label -relief sunken
    ttk::label .mf.status_frame.done_label_label -text Done 
    ttk::label .mf.status_frame.done_label -text 0/0 -relief sunken
}

oo::define Gui method make_layout {} {
    const opts "-pady 3 -padx 3"
    pack .mf.status_frame -fill x -anchor n -side bottom
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
    grid .mf.cf.ctrl_frame -row 0 -column 0 -rowspan 2 -sticky ns
    grid .mf.cf.unhinted_label -row 0 -column 1
    grid .mf.cf.hinted_label -row 0 -column 2
    grid [$UnhintedText ttk_frame] -row 1 -column 1 -sticky news {*}$opts
    grid [$HintedText ttk_frame] -row 1 -column 2 -sticky news {*}$opts
    grid rowconfigure .mf.cf 1 -weight 1
    grid columnconfigure .mf.cf 1 -weight 1 -uniform 1
    grid columnconfigure .mf.cf 2 -weight 1 -uniform 1
    pack .mf.cf -fill both -expand 1 -anchor n -side top
    pack .mf.status_frame.unused_label_label -side left {*}$opts
    pack .mf.status_frame.unused_label -side left -fill x -expand 1 {*}$opts
    pack .mf.status_frame.done_label -side right -fill x {*}$opts
    pack .mf.status_frame.done_label_label -side right {*}$opts
    pack .mf -fill both -expand 1
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

oo::define Gui method on_unhinted {} { $UnhintedText focus }

oo::define Gui method on_hinted {} { $HintedText focus }

oo::define Gui method on_new {} {
    my maybe_save
    set TheFilename ""
    wm title . "Unsaved — [tk appname]"
    puts on_new ;# TODO
}

oo::define Gui method on_open {} {
    my maybe_save
    puts on_open ;# TODO
    #wm title . "[file tail $TheFilename] — [tk appname]"
}

oo::define Gui method on_save {} {
    if {$TheFilename eq ""} {
        my on_saveas
    } else {
        puts on_save ;# TODO
    }
}

oo::define Gui method on_saveas {} {
    puts on_saveas ;# TODO
    #wm title . "[file tail $TheFilename] — [tk appname]"
    # TODO once i've got a filename set TheFilename & call my on_save
}

oo::define Gui method on_run {} {
    puts on_run ;# TODO
}

oo::define Gui method on_config {} { ConfigForm new }

oo::define Gui method on_about {} {
    AboutForm new "An Alt+Key Keyboard accelerator helper" \
        https://github.com/mark-summerfield/altkey
}

oo::define Gui method on_quit {} {
    my maybe_save
    set config [Config new]
    $config set_last_filename $TheFilename
    $config save
    exit
}

oo::define Gui method maybe_save {} {
    if {[$UnhintedText edit modified]} {
        # TODO prompt to save unsaved changes & if yes, call on_save
        puts maybe_save
        $UnhintedText edit modified 0
    }
}

oo::define Gui method add_tags text_edit {
    $text_edit tag configure ul -foreground blue -underline 1
    $text_edit tag configure green -foreground darkgreen
    $text_edit tag configure gray -foreground gray
}
