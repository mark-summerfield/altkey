# Copyright © 2025-26 Mark Summerfield. All rights reserved.

package require inifile
package require util

# Also handles tk scaling
oo::singleton create Config {
    variable Filename
    variable Blinking
    variable Geometry
    variable FontFamily
    variable FontSize
    variable LastFilename
}

oo::define Config constructor {} {
    set Filename [util::get_ini_filename [tk appname]]
    set Blinking 1
    set Geometry ""
    set FontFamily [font configure TkDefaultFont -family]
    set FontSize [font configure TkDefaultFont -size]
    set LastFilename ""
    if {[file exists $Filename] && [file size $Filename]} {
        set ini [ini::open $Filename -encoding utf-8 r]
        try {
            tk scaling [ini::value $ini General Scale [tk scaling]]
            if {![set Blinking [ini::value $ini General Blinking \
                    $Blinking]]} {
                option add *insertOffTime 0
                ttk::style configure . -insertofftime 0
            }
            set Geometry [ini::value $ini General Geometry $Geometry]
            set FontFamily [ini::value $ini General FontFamily $FontFamily]
            set FontSize [ini::value $ini General FontSize $FontSize]
            set LastFilename [ini::value $ini General LastFilename \
                $LastFilename]
        } on error err {
            puts "invalid config in '$Filename'; using defaults: $err"
        } finally {
            ini::close $ini
        }
    }
}

oo::define Config method save {} {
    set ini [ini::open $Filename -encoding utf-8 w]
    try {
        ini::set $ini General Scale [tk scaling]
        ini::set $ini General Blinking [my blinking]
        ini::set $ini General Geometry [wm geometry .]
        ini::set $ini General FontFamily [my family]
        ini::set $ini General FontSize [my size]
        ini::set $ini General LastFilename $LastFilename
        ini::commit $ini
    } finally {
        ini::close $ini
    }
}

oo::define Config method filename {} { set Filename }
oo::define Config method set_filename filename { set Filename $filename }

oo::define Config method blinking {} { set Blinking }
oo::define Config method set_blinking blinking { set Blinking $blinking }

oo::define Config method geometry {} { set Geometry }
oo::define Config method set_geometry geometry { set Geometry $geometry }

oo::define Config method size {} { set FontSize }
oo::define Config method set_size size { set FontSize $size }

oo::define Config method family {} { set FontFamily }
oo::define Config method set_family family { set FontFamily $family }

oo::define Config method last_filename {} { set LastFilename }
oo::define Config method set_last_filename last_filename {
    set LastFilename $last_filename
}

oo::define Config method to_string {} {
    return "Config filename=$Filename blinking=$Blinking\
        scaling=[tk scaling] geometry=$Geometry fontfamily=$FontFamily\
        fontsize=$FontSize last_filename=[my last_filename]"
}
