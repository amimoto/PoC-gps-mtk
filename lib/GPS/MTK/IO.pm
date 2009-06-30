package GPS::MTK::IO;

use strict;
use bytes;
use IO::File;
use IO::Select;
use Device::SerialPort;
use GPS::MTK::Base
    MTK_ATTRIBS => {
        comm_port_fpath  => '',
        buffer           => '',
        io_handle        => undef,
        io_timeout       => 5,
        baudrate         => 115200,
    };

sub connect {
# --------------------------------------------------
# Open up a port to the io source
#
    my ( $self, $source ) = @_;
    $source ||= $self->{comm_port_fpath};
#    my $io_handle = IO::File->new( $source, "+<" ) or return die $!; # TODO: ERROR MESSAGE

    my $io_handle = Device::SerialPort->new($source);
    $io_handle->baudrate($self->{baudrate}) || die "fail setting baud rate";
    $io_handle->parity('none')      || die "fail setting parity";
    $io_handle->databits(8)         || die "fail setting databits";
    $io_handle->stopbits(1)         || die "fail setting stopbits";
    $io_handle->handshake('none')   || die "fail setting handshake";
    $io_handle->write_settings      || die "no settings";
    $io_handle->read_const_time(1000);

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
    return $self->{blocking} = $blocking;
#    return $io_handle->blocking($blocking);
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
    my ($n,$l);
    if ( $self->{blocking} ) {
        my $ch = $l = '';
        do {
            do {
                ($n,$ch) = $io_handle->read(1);
            } while ( $n == 0 );
            $l .= $ch;
        } while ( $ch ne "\n" );

    }
    else {
        ($n,$l) = $io_handle->read(1);
    }

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
    return $io_handle->write($line);
#    return $io_handle->printflush($line);
}

1;
