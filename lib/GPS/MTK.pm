package GPS::MTK;

use strict;
use GPS::MTK::Base
    MTK_ATTRIBS => {

# Driver based handling of IO and parsing
        io_class         => 'GPS::MTK::IO',
        downloader_class => 'GPS::MTK::Downloader',
        parser_class     => 'GPS::MTK::Parser',
        event_class      => 'GPS::MTK::Event',

# The files users will generally be paying with
        comm_port_fpath  => '',
        track_dump_fpath => '',
    };


####################################################
# The core interface functions
####################################################

sub loop {
# --------------------------------------------------
# Just iterate and keep downloading NMEA strings
# from the GPS unit
#
    my ( $self, $blocking ) = @_;
    my $opts = {@_};
    my $io_obj    = $opts->{io_obj}    ||= $self->io_obj or return;
    my $event_obj = $opts->{event_obj} ||= $self->event_obj or return;
    my $l;

    FETCH_DATA: {
        $io_obj->blocking($blocking);
        do {
            $l = $io_obj->getline();
            $l =~ s/[\n\r]*$//;

# If there is an event, we just send it to the event 
# engine as required.
            if ( $l ) {
		print $l;
                $event_obj->event($l);
            }
            elsif ( not $blocking ) {
                last;
            }

        } while ( defined $l );
    };

    return;
}

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
    return $self->{io_obj} ||= do {
        my $io_class = $self->{io_class};
        return unless $io_class =~ /^\w+(?:::\w+)*$/; # TODO ERROR MESSAGE
        eval "require $io_class";
        my $io_obj = $io_class->new({ comm_port_fpath => $self->{comm_port_fpath} });
        $io_obj->connect;
        $io_obj;
    };
}

sub download_obj {
# --------------------------------------------------
    my $self = shift;
    return $self->{download_obj} ||= do {
        my $download_class = $self->{download_class};
        return unless $download_class =~ /^\w+(?:::\w+)*$/; # TODO ERROR MESSAGE
        eval "require $download_class";
        my $download_obj = $download_class->new;
        $download_obj;
    };
}


sub parser_obj {
# --------------------------------------------------
    my $self = shift;
    return $self->{parser_obj} ||= do {
        my $parser_class = $self->{parser_class};
        return unless $parser_class =~ /^\w+(?:::\w+)*$/; # TODO ERROR MESSAGE
        eval "require $parser_class";
        my $parser_obj = $parser_class->new;
        $parser_obj;
    };
}

sub event_obj {
# --------------------------------------------------
    my $self = shift;
    return $self->{event_obj} ||= do {
        my $event_class = $self->{event_class};
        return unless $event_class =~ /^\w+(?:::\w+)*$/; # TODO ERROR MESSAGE
        eval "require $event_class";
        my $event_obj = $event_class->new;
        $event_obj;
    };
}

1;
