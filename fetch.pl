#!/usr/bin/perl

use strict;
use lib 'lib';
use Getopt::Long;
use GPS::MTK;

main();

sub main {
# --------------------------------------------------

    my $gps = GPS::MTK->new( 
#                    comm_port_fpath => '/dev/ttyUSB0',
                    comm_port_fpath => '/dev/rfcomm4',
                    log_dump_fpath  => '/tmp/gps.log',
                );
    $gps->nmea_string_log("--------------------- Saving new session -------------------------");
    my $buf = $gps->log_download(
                        progress => sub {
                            my ( $self, $dl_bytes, $all_bytes ) = @_;
                            return unless $all_bytes;
                            printf "\r%.02f%% %i/%i               ", 100*$dl_bytes/$all_bytes, $dl_bytes, $all_bytes;
                        }
                    );
    open F, ">gpsdata.bin";
    binmode F;
    print F $buf;
    close F;
}


