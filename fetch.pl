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
    my $buf = $gps->log_download(
                        progress => sub {
                            my ( $self, $dl_bytes, $all_bytes ) = @_;
                            return unless $all_bytes;
                            printf "%.02f%% %i/%i\n", 100*$dl_bytes/$all_bytes, $dl_bytes, $all_bytes;
                        }
                    );
    open F, ">gpsdata.bin";
    binmode F;
    print F $buf;
    close F;
#    while (1) {
#        $gps->loop(1);
#    }
}


