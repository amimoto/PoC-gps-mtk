package GPS::MTK;

use strict;
use GPS::MTK::Base
    MTK_ATTRIBS => {

# Driver based handling of IO and parsing
        io_class         => 'GPS::MTK::IO',
        downloader_class => 'GPS::MTK::Downloader',
        parser_class     => 'GPS::MTK::Parser',

# The files users will generally be paying with
        comm_port_fpath  => '',
        track_dump_fpath => '',
    };


####################################################
# The core interface functions
####################################################

sub config {
# --------------------------------------------------
# Returns the current configuration parameters for
# the device
#
    my $self = shift;
    my $opts = {@_};
    $opts->{io_obj} ||= $self->io_obj;
    my $downloader = $self->download_obj;
    my $download   = $downloader->download($opts);
    return $download;
}

sub download {
# --------------------------------------------------
# Downloads the device's current memory
#
    my $self = shift;
    my $opts = {@_};
    $opts->{io_obj} ||= $self->io_obj;
    my $downloader = $self->download_obj;
    my $download   = $downloader->download($opts);
    return $download;
}

sub parse {
# --------------------------------------------------
# Parses the device's dumped data file
#
    my $self = shift;
    my $opts = {@_};
    $opts->{io_obj} ||= $self->io_obj;
    my $parseer = $self->parse_obj;
    my $parse   = $parseer->parse($opts);
    return $parse;
}

####################################################
# Object instantiation code
####################################################

sub io_obj {
# --------------------------------------------------
    my $self = shift;
    my $io_class = $self->{io_class};
    return unless $io_class =~ /^\w+(?:::\w+)*$/; # TODO ERROR MESSAGE
    eval "require $io_class";
    my $io_obj = $io_class->new;
    return $io_obj;
}

sub download_obj {
# --------------------------------------------------
    my $self = shift;
    my $download_class = $self->{download_class};
    return unless $download_class =~ /^\w+(?:::\w+)*$/; # TODO ERROR MESSAGE
    eval "require $download_class";
    my $download_obj = $download_class->new;
    return $download_obj;
}


sub parser_obj {
# --------------------------------------------------
    my $self = shift;
    my $parser_class = $self->{parser_class};
    return unless $parser_class =~ /^\w+(?:::\w+)*$/; # TODO ERROR MESSAGE
    eval "require $parser_class";
    my $parser_obj = $parser_class->new;
    return $parser_obj;
}

1;
