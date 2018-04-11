# Copyright (c) 2018  Timm Murray
# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without 
# modification, are permitted provided that the following conditions are met:
# 
#     * Redistributions of source code must retain the above copyright notice, 
#       this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above copyright 
#       notice, this list of conditions and the following disclaimer in the 
#       documentation and/or other materials provided with the distribution.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" 
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE 
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE 
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE 
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF 
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS 
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN 
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) 
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
# POSSIBILITY OF SUCH DAMAGE.
package Device::WebIO::MQTT;

# ABSTRACT: Glue Device::WebIO into MQTT
use v5.12;
use warnings;
use Moo;
use namespace::clean;
use AnyEvent;
use Device::WebIO;


has 'mqtt' => (
    is => 'ro',
);
has 'webio' => (
    is => 'ro',
);
has 'topic_prefix' => (
    is => 'ro',
    default => sub {''},
);
has 'event_checks' => (
    is => 'ro',
    default => sub {{}},
);
has '_condvars' => (
    is => 'ro',
    default => sub {{}},
);
has '_condvar_cleanout_timer' => (
    is => 'rw',
);


sub BUILD
{
    my ($self) = @_;
    my $event_checks = $self->event_checks;

    foreach my $dev_name (keys %$event_checks) {
        foreach my $pin_num (@{ $event_checks->{$dev_name} }) {
            my $topic = $self->_topic_name( $dev_name, $pin_num );
            $self->_set_input_callback( $topic, $dev_name, $pin_num );
        }
    }

    return $self;
}

sub _set_input_callback
{
    my ($self, $topic, $dev_name, $pin_num) = @_;
    my $mqtt = $self->mqtt;
    my $webio = $self->webio;

    my $cv = AnyEvent->condvar;
    $cv->cb( sub {
        my ($cv) = @_;
        my ($pin, $setting) = $cv->recv;
        my $mqtt_cv = $mqtt->publish(
            message => $setting,
            topic => $topic,
        );
    });
    $webio->set_anyevent_condvar( $dev_name, $pin_num, $cv );

    return $cv;
}

sub _topic_name
{
    my ($self, $dev_name, $pin_num) = @_;
    my $topic_prefix = $self->topic_prefix;
    my $topic = join '/',
        $topic_prefix,
        $dev_name,
        'gpio',
        $pin_num;
    return $topic;
}


1;
__END__

