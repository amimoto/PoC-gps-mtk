package GPS::MTK::Event;

use strict;
use GPS::MTK::NMEA;
use GPS::MTK::Base
    MTK_ATTRIBS => {
        event_hooks => {
            _default => [],
            _error   => [],
        },
    };

sub event {
# --------------------------------------------------
# Triggers a single event based upon the NMEA
# string
#
    my ( $self, $line, $cb_args ) = @_;

# Trim, ensure we have something to work with then arguments are actually
# comma delimited
    $line =~ s/^\s*|\s*$//g;
    return unless $line;

# Handle the checksum
    my $checksum_str = $line;
    $checksum_str  =~ s/\*([0-9a-f]{2})$//i or return $self->event_error($line,$cb_args,"NOCHECKSUM");
    my $checksum = $1;
    my @e = split /,/, $checksum_str;

# Now handle the event code
    my $code = shift @e;
    return $self->event_error($line,$cb_args,"NOTNMEA") unless $code and $code =~ s/^\$//;

    my $checksum_calc = GPS::MTK::NMEA->checksum($checksum_str);
    if ( $checksum_calc ne $checksum ) {
        $self->event_error($line,$cb_args,"CHECKSUMFAIL : $checksum_calc vs $checksum");
    }

# Not an error, we hand off to the trigger event
    return $self->event_trigger($line,$code,\@e,$cb_args);
}

sub event_error {
# --------------------------------------------------
# Throw an error event if we can
#
    my ( $self, $line, $cb_args, $error_msg ) = @_;
    my $func = $self->hook_current('_error') or return;
    return $func->($line,$cb_args,$error_msg);
}

sub event_trigger {
# --------------------------------------------------
# This will send the event to the proper handler as required
#
    my ( $self, $line, $code, $elements, $cb_args ) = @_;
    my $events = $self->{events};
    $code = lc $code;
    my $func = $self->hook_current($code) || $self->hook_current('_default');
    return unless $func;
    return $func->($line,$cb_args,$code,$elements);
}

sub hook_current {
# --------------------------------------------------
# This will return the currently active hook function
# for the hook code requested
#
    my ( $self, $code ) = @_;


    my $hooks = $self->{events}{lc $code};

    $hooks and @$hooks or return;

    return $hooks->[-1];
};

sub hook_register {
# --------------------------------------------------
# This will register a single hook on the event queue
# for a particular type of event
#
    my ( $self, $code, $callback ) = @_;
    push @{$self->{events}{lc $code}||=[]}, $callback;
}

sub hook_unregister {
# --------------------------------------------------
# This will remove a single hook on the event queue
# for a particular type of event. Basically, it will
# take events off the list and cause the "default"
# handler to be triggered when this event comes up
# again.
#
    my ( $self, $code ) = @_;
    pop @{$self->{events}{lc $code}};
}

1;
