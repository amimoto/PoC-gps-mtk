package GPS::MTK::IO;

use strict;
use bytes;
use IO::File;
use IO::Select;
use GPS::MTK::Base
    MTK_ATTRIBS => {
        comm_port_fpath  => '',
        buffer           => '',
        io_handle        => undef,
        io_timeout       => 5,
    };

sub connect {
# --------------------------------------------------
# Open up a port to the io source
#
    my ( $self, $source ) = @_;
    $source ||= $self->{comm_port_fpath};
    my $io_handle = IO::File->new( $source, "+<" ) or return die $!; # TODO: ERROR MESSAGE
    $self->{io_handle} = $io_handle;
    return $io_handle;
}

sub send {
# --------------------------------------------------
# Dump a single line to the user
#
}

sub blocking {
# --------------------------------------------------
# Switch between blocking and non-blocking mode
#
    my ( $self, $blocking ) = @_;
    my $io_handle = $self->{io_handle} or return;
    $self->{blocking} = $blocking;
    return $io_handle->blocking($blocking);
}

sub pending_io {
# --------------------------------------------------
# Returns a true value if there's IO that's awaiting
# servicing
#
    my $self = shift;
    my $io_handle = $self->{io_handle} or return;
}

sub getline {
# --------------------------------------------------
# Return a single line of output if there is no
# data pending or only a partial line in the buffer
# return undef. This function should not block
#
    my $self = shift;
    my $io_handle = $self->{io_handle} or return;

# If blocking mode is on, we wait till we have
# something to read
    if ( $self->{blocking} ) {
        IO::Select->new($io_handle)->can_read($self->{io_timeout});
    }

    my $l = $io_handle->getline || '';

# We found a carriage return, let's get it and move on
    if ( $l =~ /\n/ ) {
        my $line = $self->{buffer} . $l;
        $line =~ s/\r?\n(.*)$//;
        $self->{buffer} = $1 || '';
        return $line;
    }

    $self->{buffer} .= $l;
    return '';
}

sub printflush {
# --------------------------------------------------
# Send a single line of data to the device
#
    my ( $self, $line ) = @_;
    my $io_handle = $self->{io_handle} or return;
    return $io_handle->printflush($line);
}

1;
