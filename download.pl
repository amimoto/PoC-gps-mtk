#!/usr/bin/perl

use strict;
use lib 'lib';
use Getopt::Long;
use Pod::Usage;
use vars qw/ @OPTIONS %OPTS /;
$|++;

@OPTIONS = (
    'h|help'   => \$OPTS{help},
    'o|of=s'   => \$OPTS{out_fpath},
    'l|log=s'  => \$OPTS{log_fpath},
    'p|port=s' => \$OPTS{port},
    'q|quiet'  => \$OPTS{quiet},
    'man'      => \$OPTS{man},
);

my $ret = Getopt::Long::GetOptionsFromArray(\@ARGV,@OPTIONS) or pod2usage(2);
pod2usage() if $OPTS{help};
pod2usage(-exitstatus => 0, -verbose => 2) if $OPTS{man};

main(\%OPTS);

sub main {
# --------------------------------------------------
    my $opts = shift;

# Try and make the output file right away
    my $out_fpath = $opts->{out_fpath} || do {
                        my @d = localtime;
                        $d[4]++;
                        $d[5]+=1900;
                        my $fname = sprintf '%i-%02i-%02i_%02i:%02i:%02i.bin', reverse @d[0..5];
                        $fname;
                    };
    open F, ">$out_fpath" or die "Could not make output file '$out_fpath' because '$!'";
    binmode F;

# And download the data
    require GPS::MTK;
    my $gps = GPS::MTK->new( 
                    comm_port_fpath => $opts->{port} || '/dev/ttyUSB0',
                    log_dump_fpath  => $opts->{log_fpath},
                );
    $gps->nmea_string_log("--------------------- Saving new session -------------------------");
    my $buf = $gps->log_download(
                        progress => sub {
                            my ( $self, $dl_bytes, $all_bytes ) = @_;
                            return unless $all_bytes;
                            if ( not $opts->{quiet} ) {
                                printf "\r%.02f%% %i/%i               ", 100*$dl_bytes/$all_bytes, $dl_bytes, $all_bytes;
                            }
                        }
                    );

# And now we can dump the data
    print F $buf;
    close F;

# Done!
    print " - Done\n";
}

__END__

=head1 NAME

download.pl - Download the data from an MTK based GPS device

=head1 SYNOPSIS

 download.pl [options] 

 Options:

  -h, --help             brief help message
  --man                  full documentation
  -o FILE, --of FILE     dump file for data
  -l FILE, --log FILE    log path for IO
  -p PATH, --port PATH   path to port
  -q, --quiet            silence output except errors

=head1 OPTIONS

=over 8

=item B<--help>

Print a brief help message and exits.

=item B<--man>

Prints the manual page and exits.

=back

=head1 DESCRIPTION

B<This program> will read the given input file(s) and do something
useful with the contents thereof.

=cut


