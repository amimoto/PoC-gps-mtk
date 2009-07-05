package GPS::MTK::Parser;

use strict;
use bytes;
use Symbol;
use GPS::MTK;
use GPS::MTK::Constants qw/:all/;
use GPS::MTK::Base
    MTK_ATTRIBS => {
        fpath_out => '%Y-%M-%D_%h:%m:%s.csv',
        fh_out    => undef,
    };

###################################################
# Main code follows
###################################################

sub parse {
# --------------------------------------------------
    my $self = shift;
    ref $self or $self = $self->new;
    my $fpath = shift || $self->{fpath_out} or die "No data file provided!";
    -f $fpath or die "Require path to data file";

# Get a fix on the data file
    my $fh = Symbol::gensym();
    open $fh, "<$fpath";
    my $fh_size = -s $fpath;

# Go in block chunks
    my $fh_read = 0;
    my $state = {
        fpath_current => undef,
        fpath_fh      => undef,
    };

    while ( $fh_read < $fh_size ) {

# Load a block in
        read $fh, my $block_buf, LOG_BLOCK_SIZE;
        my $b_i    = 0;

# Parse out the header
        my $header_info_buf = substr $block_buf, $b_i, LOG_HEADER_INFO_SIZE; $b_i += LOG_HEADER_INFO_SIZE;
        my $header_info = $self->log_parse_header( $header_info_buf );

# Sector status: we don't know how to handle so this is just a stub.
        my $sector_info_buf = substr $block_buf, $b_i, LOG_SECTOR_INFO_SIZE; $b_i += LOG_SECTOR_INFO_SIZE;
        my $sector_info = $self->log_parse_sector( $sector_info_buf );

# Handle the padding. We really don't need any information from here
        my $padding     = substr $block_buf, $b_i, LOG_HEADER_PADDING_SIZE; $b_i += LOG_HEADER_PADDING_SIZE;

# At this point, we can trim the fat from the end of this buffer. While each block is 0x10000 
# bytes long, the unused portions are merely blanked out with 0xFF. We need to find out
# where that ends.
        my $block_buf_len = length($block_buf);
        while ($block_buf_len) {
            unless ( ord(substr($block_buf,$block_buf_len-1,1)) == 0xff ) {
                last;
            };
            $block_buf_len--;
        }

# Now we can handle the data from the header. The log chunk can be
# either a single point or a record of a log attribute being changed.
# In the logs, each track is separated by an event such as power cycling
# or changing the logging parameters. After every separator we encounter, we
# see if we end up with a new filepath. Every new filepath corresponds to a 
# new file  This allows us to create a new file for every new track
# or consolidate all tracks into a single file. It's just a matter of how
# the subclass behaves... yay!
        while ( $b_i < $block_buf_len ) {
            if ( my $entry_separator = $self->log_parse_entry_separator(\$block_buf,\$b_i,$header_info) ) {
                $state->{fpath_fh} = $self->log_separator_handler($state,$entry_separator,$header_info);
                $self->log_fpath_close($state,$entry_separator,$header_info);
            }
            else {
                my $entry_info = $self->log_parse_entry(\$block_buf,\$b_i,$header_info);
                if ( not $state->{fpath_fh} ) {
                    my $fpath_new = $state->{fpath_current} = $self->log_fpath($state,$entry_info,$header_info) or return;
                    $state->{fpath_fh} = $self->log_fpath_open($fpath_new,$state,$entry_info,$header_info);
                }
                $self->log_entry_handler($state,$entry_info,$header_info);
            }
        }

# Setup for next chunk
        $fh_read += LOG_BLOCK_SIZE;
    }

# We will ensure that the log file is closed. Note that the
# $entry_separator value is undef'd to indicate that there really is no more
# data.
    $self->log_fpath_close($state,undef,undef);

    close $fh;
}

###################################################
# Log file managers
###################################################

sub log_fpath {
# --------------------------------------------------
# This returns a new filename if there is any
#
    my ( $self, $state, $entry_info, $header_info ) = @_;
    my $fpath = $self->{fpath_out} or return;

    my @d = localtime($entry_info->{utc});
    $d[5] += 1900;
    $d[4] += 1;

# The fpath can be of either a string format or a subroutine
# if it's a subroutine, the subroutine is expected to return the
# new filename. if it returns a non-true value, we assume
# that the function has failed
    $fpath = ref $fpath eq 'CODE' ? $fpath->($self,$header_info) : $fpath;
    my $replace = {
        h => sprintf( '%02i', $d[2] ),
        m => sprintf( '%02i', $d[1] ),
        s => sprintf( '%02i', $d[0] ),
        D => sprintf( '%02i', $d[3] ),
        M => sprintf( '%02i', $d[4] ),
        Y => sprintf( '%04i', $d[5] ),
      '%' => '%',
    };
    $fpath =~ s/\%(.)/$replace->{$1}/g;

    return $fpath;
}

sub log_fpath_open {
# --------------------------------------------------
# Given the filename and header informnation, this 
# function will open the path for writing, create the header 
# required for the upcoming data
#
    my ($self,$fpath_new,$state,$entry_info,$header_info) = @_;

# This will create a CSV for us to play with
    my $headers = $header_info->{log_format_elements};

    my $fh = Symbol::gensym();
    open $fh, ">$fpath_new";

    my $header_buf = join ",", @{$header_info->{log_format_elements}};
    print $fh $header_buf, "\n";

    return $fh;
}

sub log_fpath_close {
# --------------------------------------------------
# This will be called when the file is no longer
# required. At this point either the track or the
# track segment has completed. The footer can be added to the
# output at this point
#
    my ($self,$state,$entry_separator,$header_info) = @_;
}

###################################################
# Log handler hooks
###################################################

sub log_separator_handler {
# --------------------------------------------------
    my ( $self, $state, $entry_separator, $header_info ) = @_;
    return $state->{fpath_fh};
}

sub log_entry_handler {
# --------------------------------------------------
    my ( $self, $state, $entry_info, $header_info ) = @_;

    my $fh  = $state->{fpath_fh};
    my $entry_buf = join ",", @$entry_info{@{$header_info->{log_format_elements}}};
    print $fh $entry_buf, "\n";
}

###################################################
# Log parser code
###################################################

sub log_parse_header {
# --------------------------------------------------
# From: http://spreadsheets.google.com/pub?key=pyCLH-0TdNe-5N-5tBokuOA&gid=5
#
# Log info consist of 20 bytes, the log count is FFFF until 
# the entire 64kByte block has been filled. It will then represent 
# the number of log items in this block.
#
# 0    1        2    3    4    5    6    7
# FFFF BBBBBBBB MMMM PPPP 0000 DDDD 0000 SSSS 0000
# FFFF     -- log count, updated when entire 64kB block full.
# BBBBBBBB -- log format - LSB is first. In my case (reordered): 0x0020003F
# MMMM     -- Mode - 0401 --- ??? / also 0601 (second block in my case: what setting 
#                                           could that be? May be to indicate if the 
#                                           log period/distance/speed is active! 
#                                           (default=1s, my case: distance too)
# PPPP     -- Log period in 10:ths of seconds
# DDDD     -- Log distance in 10:ths of meters
# SSSS     -- Log speed in 10:ths of km/h
# 
    my ( $self, $header_buf ) = @_;

    my @h = unpack( "SLS*", $header_buf );
    my $header_info = {
        log_count    => $h[0],
        log_format   => $h[1],
        log_mode     => $h[2],
        log_period   => $h[3]/10,
        log_distance => $h[5]/10,
        log_speed    => $h[7]/10,
    };

# What's the log format look like?
    require GPS::MTK::NMEA;
    $header_info->{log_format_elements} = GPS::MTK::NMEA->log_format_parse($header_info->{log_format   });

    return $header_info;
}

sub log_parse_sector {
# --------------------------------------------------
# Stub.
#
    my $self = shift;
    return shift;
}

sub log_parse_entry {
# --------------------------------------------------
# From: http://spreadsheets.google.com/pub?key=pyCLH-0TdNe-5N-5tBokuOA&gid=5
#
# utc_data ?!
# valid_data ?!
# latitude_data ?!
# longitude_data ?!
# height_data ?!
# speed_data ?!
# heading_data ?!
# dsta_data ?!
# dage_data ?!
# pdop_data ?!
# hdop_data ?!
# vdop_data ?!
# nsat_data ?!
# ( nosat_data
# | sat_data * ) ?!
# rcr_data ?!
# mili-second_data ?
# distance_data ?!
#
# This defines the order of the data logged. The '?' indicates that the 
# data is optional. The actual data logged depends on the settings of the 
# device at the moment of the log
# [A '!' after the '?' indicates that the position of this data in the 
# log has been confirmed.
# Some information concerning size catched on 
# http://pc11.2ch.net/test/read.cgi/mobile/1173306239
#
# If there is no satellite data and SID is being logged, then the number of sats will be set to 0 and there will be no ele, azi or snr data)
    my ( $self, $block_buf_ref, $b_i, $header_info ) = @_;

# Iterate through the header format now.
    my $fmt = LOG_STORAGE_FORMAT;
    my $entry_info = {};
    for my $type ( @{$header_info->{log_format_elements}} ) {
        my $type_data = $fmt->{$type};

# We handle NSAT information as an exception since it's of a variable length
        if ( $type eq 'NSAT' ) {
            die "NSAT";
        }

# We will handle the rest in standard format
        my $data_buf = substr $$block_buf_ref, $$b_i, $type_data->{numbytes};
        $entry_info->{lc $type} = unpack($type_data->{format},$data_buf);
        $$b_i += $type_data->{numbytes};
    }

# Then we get the trailing '*' and checksum
    my $star = substr $$block_buf_ref, $$b_i++, 1;
    my $checksum = substr $$block_buf_ref, $$b_i++, 1;

    return $entry_info;
}

sub log_parse_entry_separator {
# --------------------------------------------------
# Log separators look like:
#
# 0xAA AA AA AA AA AA AA
# 0xYY
# 0xXX XX XX XX
# 0xBB BB BB BB
#
# Switching the device on/off results in some synchronization ???
# The information record is 16 bytes long and contains a command (YY) 
# and an argument XXXXXXXX. The argument should be interpreted as a 
# word or long depending on the command byte. LSB is first byte of the 
# data XXXXXXXX. The following commands are known.
#
# 0x02 - Log bitmask change [long bitmask]
# 0x03 - Log period change [word period/10 sec]
# 0x04 - Log distance change [word distance/10 m]
# 0x05 - Log speed change [word speed/10 km/h]
# 0x06 - Log overwrite/log stop change - argument = same as log status (PMTK182,2,7 response)
# 0x07 - Log on/off change - argument = same as log status (PMTK182,2,7 response)
#
    my ( $self, $block_buf_ref, $b_i, $header_info ) = @_;

# We check to see if the prefix and suffix data match our expected
# pattern (or it's not a log separator!)
    unless (
        substr( $$block_buf_ref, $$b_i, LOG_ENTRY_SEPARATOR_PREFIX_LENGTH ) eq LOG_ENTRY_SEPARATOR_PREFIX
        and
            substr( 
                $$block_buf_ref, 
                LOG_ENTRY_SEPARATOR_PREFIX_LENGTH + 5 + $$b_i, 
                LOG_ENTRY_SEPARATOR_SUFFIX_LENGTH 
                ) eq LOG_ENTRY_SEPARATOR_SUFFIX

    ) {
        return;
    }

# Now we can figure out how the formatting changed
# TODO: this needs to be handled in the constants better
    my $entry_separator = {};
    my $mode = substr $$block_buf_ref, $$b_i+LOG_ENTRY_SEPARATOR_PREFIX_LENGTH, 1;

    if ($mode == LOG_ENTRY_SEPARATOR_BITMASK) {
        die "Bitmask Separator found";
    }

    $$b_i += 16;

    return $entry_separator;
}

sub print_hex_dump {
# --------------------------------------------------
    my ( $self, $buf_ref, $b_i, $bytes ) = @_;
    my $buf = substr $$buf_ref, $$b_i, $bytes;
    my @e   = map {sprintf "%02x", ord} split //, $buf;
    print join " ", @e;
    print "\n";
}

1;
