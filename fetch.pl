#!/usr/bin/perl

use strict;
use lib 'lib';
use Getopt::Long;
use GPS::MTK;

main();

sub main {
# --------------------------------------------------

    my $gps = GPS::MTK->new( 
                    comm_port_fpath => '/dev/rfcomm4',
                    log_dump_fpath  => '/tmp/gps.log',
                );
    while (1) {
        $gps->loop(1);
    }
}


