#!/usr/bin/perl

# All the work related to the format of the bin dumps can be credited here:
# 
# http://spreadsheets.google.com/pub?key=pyCLH-0TdNe-5N-5tBokuOA&gid=5
#
# Thanks to you guys I can actually use my GPS the way I wanted to!

use strict;
use lib 'lib';
use GPS::MTK::Parser;
use Symbol;

###################################################
# Main code follows
###################################################

main(@ARGV);

sub main {
# --------------------------------------------------
    my $fpath = shift or die "No data file provided!";
    -f $fpath or die "Require path to data file";

    GPS::MTK::Parser->parse( $fpath );
}

