#!/usr/bin/env tclsh9
# Copyright © 2026 Mark Summerfield. All rights reserved.
# License: GPLv3
#
# Kuhn-Munkres (Hungarian) algorithm for the assignment problem.
# A faithful Tcl 9 port of the algorithm used by Brian Clapper's Python
# "munkres" package (itself the classic O(n^3) Munkres/Hungarian method),
# restricted to square matrices (which is all altkey needs).

namespace eval ::munkres {}

# ::munkres::compute cost_matrix
#
# cost_matrix is a list of n lists, each of n numbers (a square matrix).
# Returns a list of {row col} pairs describing the minimum-cost
# assignment (one column per row).
proc ::munkres::compute cost_matrix {
    if {![set n [llength $cost_matrix]]} { return }
    array set costs {}
    array set marked {}
    array set row_covered {}
    array set col_covered {}
    ::munkres::PrepareArrays $cost_matrix costs marked row_covered \
            col_covered $n
    ::munkres::Compute costs marked row_covered col_covered $n
    set results {}
    foreach i [lseq $n] {
        foreach j [lseq $n] {
            if {$marked($i,$j) == 1} { lappend results [list $i $j] }
        }
    }
    return $results
}

proc ::munkres::PrepareArrays {cost_matrix costs_ marked_ row_covered_ \
        col_covered_ n} {
    upvar 1 $costs_ costs
    upvar 1 $marked_ marked
    upvar 1 $row_covered_ row_covered
    upvar 1 $col_covered_ col_covered
    for {set i 0} {$i < $n} {incr i} {
        set row_list [lindex $cost_matrix $i]
        if {[llength $row_list] != $n} {
            error "munkres::compute requires a square matrix\
                   (row $i has [llength $row_list] columns, expected $n)"
        }
        set row_covered($i) 0
        set col_covered($i) 0
        for {set j 0} {$j < $n} {incr j} {
            set costs($i,$j) [lindex $row_list $j]
            set marked($i,$j) 0
        }
    }
}

proc ::munkres::Compute {costs_ marked_ row_covered_ col_covered_ n} {
    upvar 1 $costs_ costs
    upvar 1 $marked_ marked
    upvar 1 $row_covered_ row_covered
    upvar 1 $col_covered_ col_covered
    set z0r 0
    set z0c 0
    set step 1
    while {$step ne "done"} {
        switch -- $step {
            1 { set step [::munkres::Step1 costs $n] }
            2 {
                set step [::munkres::Step2 costs marked row_covered \
                        col_covered $n]
            }
            3 { set step [::munkres::Step3 marked col_covered $n] }
            4 {
                set step [::munkres::Step4 costs marked row_covered \
                        col_covered $n z0r z0c]
            }
            5 {
                set step [::munkres::Step5 marked row_covered col_covered \
                        $n $z0r $z0c]
            }
            6 {
                set step [::munkres::Step6 costs row_covered col_covered $n]
            }
            7 - done { set step done }
            default {
                error "munkres::compute: internal error, bad step '$step'"
            }
        }
    }
}

# For each row, find the smallest element and subtract it from every
# element in its row. Go to Step 2.
proc ::munkres::Step1 {costs_ n} {
    upvar 1 $costs_ costs
    foreach i [lseq $n] {
        set minval $costs($i,0)
        for {set j 1} {$j < $n} {incr j} {
            if {$costs($i,$j) < $minval} { set minval $costs($i,$j) }
        }
        foreach j [lseq $n] {
            set costs($i,$j) [expr {$costs($i,$j) - $minval}]
        }
    }
    return 2
}

# Find a zero (Z) in the resulting matrix. If there is no starred zero
# in its row or column, star Z. Repeat for each element in the matrix.
# Go to Step 3.
proc ::munkres::Step2 {costs_ marked_ row_covered_ col_covered_ n} {
    upvar 1 $costs_ costs
    upvar 1 $marked_ marked
    upvar 1 $row_covered_ row_covered
    upvar 1 $col_covered_ col_covered
    foreach i [lseq $n] {
        foreach j [lseq $n] {
            if {$costs($i,$j) == 0 && !$col_covered($j) && \
                    !$row_covered($i)} {
                set marked($i,$j) 1
                set col_covered($j) 1
                set row_covered($i) 1
                break
            }
        }
    }
    ::munkres::ClearCovers row_covered col_covered $n
    return 3
}

# Cover each column containing a starred zero. If all n columns are
# covered, the starred zeros describe a complete set of unique
# assignments: go to DONE (7). Otherwise go to Step 4.
proc ::munkres::Step3 {marked_ col_covered_ n} {
    upvar 1 $marked_ marked
    upvar 1 $col_covered_ col_covered
    set count 0
    foreach i [lseq $n] {
        foreach j [lseq $n] {
            if {$marked($i,$j) == 1 && !$col_covered($j)} {
                set col_covered($j) 1
                incr count
            }
        }
    }
    if {$count >= $n} { return 7 }
    return 4
}

# Find a noncovered zero and prime it. If there is no starred zero in
# the row containing this primed zero, go to Step 5. Otherwise, cover
# this row and uncover the column containing the starred zero. Continue
# until there are no uncovered zeros left; go to Step 6.
proc ::munkres::Step4 {costs_ marked_ row_covered_ col_covered_ n z0r_ \
        z0c_} {
    upvar 1 $costs_ costs
    upvar 1 $marked_ marked
    upvar 1 $row_covered_ row_covered
    upvar 1 $col_covered_ col_covered
    upvar 1 $z0r_ z0r
    upvar 1 $z0c_ z0c
    set row 0
    set col 0
    while {1} {
        lassign [::munkres::FindAZero costs row_covered col_covered $n \
                $row $col] row col
        if {$row < 0} { return 6 }
        set marked($row,$col) 2
        set star_col [::munkres::FindStarInRow marked $n $row]
        if {$star_col >= 0} {
            set col $star_col
            set row_covered($row) 1
            set col_covered($col) 0
        } else {
            set z0r $row
            set z0c $col
            return 5
        }
    }
}

# Construct a series of alternating primed and starred zeros as follows.
# Let Z0 be the uncovered primed zero found in Step 4. Let Z1 be the
# starred zero in the column of Z0 (if any). Let Z2 be the primed zero
# in the row of Z1 (there will always be one). Continue until the series
# terminates at a primed zero that has no starred zero in its column.
# Unstar each starred zero of the series, star each primed zero of the
# series, erase all primes, and uncover every line. Return to Step 3.
proc ::munkres::Step5 {marked_ row_covered_ col_covered_ n z0r z0c} {
    upvar 1 $marked_ marked
    upvar 1 $row_covered_ row_covered
    upvar 1 $col_covered_ col_covered
    array set path_r {}
    array set path_c {}
    set count 0
    set path_r($count) $z0r
    set path_c($count) $z0c
    while {1} {
        set row [::munkres::FindStarInColumn marked $n $path_c($count)]
        if {$row < 0} { break }
        incr count
        set path_r($count) $row
        set path_c($count) $path_c([expr {$count - 1}])

        set col [::munkres::FindPrimeInRow marked $n $path_r($count)]
        incr count
        set path_r($count) $path_r([expr {$count - 1}])
        set path_c($count) $col
    }
    ::munkres::ConvertPath marked path_r path_c $count
    ::munkres::ClearCovers row_covered col_covered $n
    ::munkres::ErasePrimes marked $n
    return 3
}

# Add the value found (the smallest uncovered value) to every element
# of each covered row, and subtract it from every element of each
# uncovered column. Return to Step 4 without altering stars, primes, or
# covered lines.
proc ::munkres::Step6 {costs_ row_covered_ col_covered_ n} {
    upvar 1 $costs_ costs
    upvar 1 $row_covered_ row_covered
    upvar 1 $col_covered_ col_covered
    set minval [::munkres::FindSmallest costs row_covered col_covered $n]
    foreach i [lseq $n] {
        foreach j [lseq $n] {
            if {$row_covered($i)} {
                set costs($i,$j) [expr {$costs($i,$j) + $minval}]
            }
            if {!$col_covered($j)} {
                set costs($i,$j) [expr {$costs($i,$j) - $minval}]
            }
        }
    }
    return 4
}

proc ::munkres::FindSmallest {costs_ row_covered_ col_covered_ n} {
    upvar 1 $costs_ costs
    upvar 1 $row_covered_ row_covered
    upvar 1 $col_covered_ col_covered
    set minval {}
    foreach i [lseq $n] {
        if {$row_covered($i)} continue
        foreach j [lseq $n] {
            if {$col_covered($j)} continue
            if {$minval eq {} || $costs($i,$j) < $minval} {
                set minval $costs($i,$j)
            }
        }
    }
    if {$minval eq {}} {
        error "munkres: matrix cannot be solved (no uncovered elements)"
    }
    return $minval
}

# Find the first uncovered zero, searching row-major starting at
# (i0, j0) and wrapping around -- matching the reference implementation.
proc ::munkres::FindAZero {costs_ row_covered_ col_covered_ n i0 j0} {
    upvar 1 $costs_ costs
    upvar 1 $row_covered_ row_covered
    upvar 1 $col_covered_ col_covered
    set row -1
    set col -1
    set i $i0
    set done 0
    while {!$done} {
        set j $j0
        while {1} {
            if {$costs($i,$j) == 0 && !$row_covered($i) && \
                    !$col_covered($j)} {
                set row $i
                set col $j
                set done 1
            }
            set j [expr {($j + 1) % $n}]
            if {$j == $j0} break
        }
        set i [expr {($i + 1) % $n}]
        if {$i == $i0} { set done 1 }
    }
    list $row $col
}

proc ::munkres::FindStarInRow {marked_ n row} {
    upvar 1 $marked_ marked
    foreach j [lseq $n] { if {$marked($row,$j) == 1} { return $j } }
    return -1
}

proc ::munkres::FindStarInColumn {marked_ n col} {
    upvar 1 $marked_ marked
    foreach i [lseq $n] { if {$marked($i,$col) == 1} { return $i } }
    return -1
}

proc ::munkres::FindPrimeInRow {marked_ n row} {
    upvar 1 $marked_ marked
    foreach j [lseq $n] { if {$marked($row,$j) == 2} { return $j } }
    return -1
}

proc ::munkres::ConvertPath {marked_ path_r_ path_c_ count} {
    upvar 1 $marked_ marked
    upvar 1 $path_r_ path_r
    upvar 1 $path_c_ path_c
    for {set i 0} {$i <= $count} {incr i} {
        set r $path_r($i)
        set c $path_c($i)
        set marked($r,$c) [expr {$marked($r,$c) == 1 ? 0 : 1}]
    }
}

proc ::munkres::ClearCovers {row_covered_ col_covered_ n} {
    upvar 1 $row_covered_ row_covered
    upvar 1 $col_covered_ col_covered
    foreach i [lseq $n] {
        set row_covered($i) 0
        set col_covered($i) 0
    }
}

proc ::munkres::ErasePrimes {marked_ n} {
    upvar 1 $marked_ marked
    foreach i [lseq $n] {
        foreach j [lseq $n] {
            if {$marked($i,$j) == 2} { set marked($i,$j) 0 }
        }
    }
}

# ::munkres::make_cost_matrix profit_matrix ?maximum?
#
# Converts a profit (weight) matrix into a cost matrix suitable for
# ::munkres::compute, using cost = maximum - profit for every cell.
# If maximum isn't supplied, it defaults to the largest value in the
# matrix (matching the Python munkres.make_cost_matrix default).
proc ::munkres::make_cost_matrix {profit_matrix {maximum {}}} {
    if {$maximum eq {}} {
        set maximum {}
        foreach row $profit_matrix {
            foreach value $row {
                if {$maximum eq {} || $value > $maximum} {
                    set maximum $value
                }
            }
        }
    }
    set cost_matrix {}
    foreach row $profit_matrix {
        set cost_row {}
        foreach value $row { lappend cost_row [expr {$maximum - $value}] }
        lappend cost_matrix $cost_row
    }
    return $cost_matrix
}
