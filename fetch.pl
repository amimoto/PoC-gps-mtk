#!/usr/bin/perl

use strict;
use lib 'lib';
use Getopt::Long;
use GPS::MTK;

main();

sub main {
# --------------------------------------------------
    my $gps = GPS::MTK->new();
    $gps->fetch;
}


