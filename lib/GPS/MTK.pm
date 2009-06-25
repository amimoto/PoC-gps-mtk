package GPS::MTK;

use strict;
use GPS::MTK::Base
    MTK_ATTRIBS => {

# Driver based handling of IO and parsing
        io_class         => 'GPS::MTK::IO',
        downloader_class => 'GPS::MTK::Downloader',
        parser_class     => 'GPS::MTK::Parser',
        event_class      => 'GPS::MTK::Event',

# Basic configuration
        io_timeout       => 4,
        io_send_reattempts => 3,

# Some internal variables to track state
        gps_state        => {
            time_current => undef, # in localtime format
            data_status  => undef,
            latitude     => undef,
            longitude    => undef,
        },

# The files users will generally be paying with
        comm_port_fpath  => '',
        track_dump_fpath => '',
        log_dump_fpath   => '',

# This key will never be used. This is entirely for you to mess with
        my_data          => {},

    };


####################################################
# The core interface functions
####################################################

sub gps_info {
# --------------------------------------------------
# Queries the GPS for its hardware implementation
# information
#
    my ( $self ) = @_;

# clear out any pending data
    $self->loop; 

# This might be a reset?
    $self->gps_send( 'PTSI1000,TSI' );

# Figure out what type of device this is. NB the event
# handler located atGPS::MTK::Event::_event_gps_pmtk705 
# takes care of the actual data processing
    $self->gps_send_wait( 'PMTK605', 'PMTK705' );

# What's the log format
    $self->gps_send_wait( 'PMTK182,2,2','PMTK182' );

# What's the time interval
    $self->gps_send_wait( 'PMTK182,2,3','PMTK182' );

# What's the distance interval
    $self->gps_send_wait( 'PMTK182,2,4','PMTK182' );

# What's the speed interval
    $self->gps_send_wait( 'PMTK182,2,5','PMTK182' );

# What's the recording method
    $self->gps_send_wait( 'PMTK182,2,6','PMTK182' );

# What's the log's status
    $self->gps_send_wait( 'PMTK182,2,7','PMTK182' );

# How much memory do we have we filled?
    $self->gps_send_wait( 'PMTK182,2,8','PMTK182' );

# How many trackpoints have we got filled?
    $self->gps_send_wait( 'PMTK182,2,10','PMTK182' );
    use Data::Dumper; die Dumper $self->{gps_state};
}

sub loop {
# --------------------------------------------------
# Just iterate and keep downloading NMEA strings
# from the GPS unit
#
    my ( $self, $blocking ) = @_;
    my $opts = {@_};
    my $io_obj    = $opts->{io_obj}    ||= $self->io_obj or return;
    my $event_obj = $opts->{event_obj} ||= $self->event_obj or return;
    my $line;

    FETCH_DATA: {
        $io_obj->blocking($blocking);
        do {
            $line = $io_obj->getline();
            $line =~ s/[\n\r]*$//;

# If there is an event, we just send it to the event 
# engine as required.
            if ( $line ) {
                $self->nmea_string_log($line);
                $event_obj->event($line,$self);
            }
            elsif ( not $blocking ) {
                last;
            }

        } while ( defined $line );
    };

    return;
}

sub gps_send {
# --------------------------------------------------
# sends a single query to the GPS
#
    my ( $self, $elements ) = @_;
    require GPS::MTK::NMEA;
    unless ( ref $elements ) { $elements = [ split /,/, $elements] }
    my $code        = shift @$elements;
    my $base_string = join ",", uc($code), @$elements;
    my $checksum    = GPS::MTK::NMEA->checksum($base_string);
    my $nmea_string = '$' . $base_string . "*$checksum\r\n";
    my $io_obj      = $self->io_obj or return;
    return $io_obj->printflush($nmea_string);
}

sub gps_wait {
# --------------------------------------------------
# This will block until the requested code is found
#
    my ( $self, $code_wait ) = @_;

    my $io_obj    = $self->io_obj or return;
    my $event_obj = $self->event_obj or return;
    $code_wait    = uc($code_wait);
    my $line;

    $io_obj->blocking(1);
    while (1) {
        $line = $io_obj->getline();
        defined $line or last;
        $line =~ s/[\n\r]*$//;
        $line or next;

# If there is an event, we just send it to the event 
# engine as required.
        $self->nmea_string_log($line);
        $event_obj->event($line,$self);

# Now check to see if the event matches our wait code
        my @e = split /,/, $line;
        my $code = shift @e;
        $code =~ s/^\$//;
        if ( $code eq $code_wait ) {
            last;
        };
    };

    return 1;
}

sub gps_send_wait {
# --------------------------------------------------
# This will send a string to the GPS then wait for 
# for a particular code and trigger the appropriate
# callback if defined
#
    my ( $self, $elements, $code_wait, $callback ) = @_;
    my $event_obj = $self->event_obj or return;
    $self->gps_send( $elements );
    $callback and $event_obj->hook_register( $code_wait, $callback );
    $self->gps_wait($code_wait);
    $callback and $event_obj->hook_unregister( $code_wait );
    return 1;
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
# Need to load the class. Okedoke
        my $event_class = $self->{event_class};
        return unless $event_class =~ /^\w+(?:::\w+)*$/; # TODO ERROR MESSAGE
        eval "require $event_class";
        $@ and die "Could not compile $event_class because '$@'";
        my $event_obj = $event_class->new;
        $event_obj;
    };
}

sub nmea_string_log {
# --------------------------------------------------
# Log a single NMEA string to the output file
#
    my ( $self, $line ) = @_;
    return unless $self->{log_dump_fpath};
    require Symbol;
    my $fh = Symbol::gensym();
    open $fh, ">>$self->{log_dump_fpath}";
    print $fh "$line\n";
    close $fh;
}


1;
