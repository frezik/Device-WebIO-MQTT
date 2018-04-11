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
use Test::More;
use v5.12;
use warnings;
use lib 't/lib';
use AnyEvent::MQTT;
use Device::WebIO::MQTT;
use Data::UUID;
use MockDigitalInputAnyEvent;

if( defined $ENV{MQTT_SERVER} ) {
    plan tests => 2;
}
else {
    plan skip_all => "Set env var 'MQTT_SERVER' to run these tests";
}
my $MQTT_SERVER = $ENV{MQTT_SERVER};


my $webio = Device::WebIO->new;
my $mock = MockDigitalInputAnyEvent->new;
$webio->register( 'mock', $mock );

my $prefix = Data::UUID->new->create_str;
my $webio_mqtt = AnyEvent::MQTT->new(
    host => $MQTT_SERVER,
);
my $dev_mqtt = Device::WebIO::MQTT->new({
    mqtt => $webio_mqtt,
    webio => $webio,
    topic_prefix => $prefix,
    event_checks => {
        mock => [ 3 ],
    },
});


my $mqtt = AnyEvent::MQTT->new(
    host => $MQTT_SERVER,
    client_id => Data::UUID->new->create_str,
);
diag "Subscribing to $prefix/mock/gpio/3 and $prefix/mock/gpio/4";
my $subscribe1_cv = $mqtt->subscribe(
    topic => "$prefix/mock/gpio/3",
    callback => sub {
        my ($topic, $msg) = @_;
        pass( "Received message" );
        cmp_ok( $msg, '==', 1, "Message says pin is high" );
        return;
    },
);
my $subscribe2_cv = $mqtt->subscribe(
    topic => "$prefix/mock/gpio/4",
    callback => sub {
        my ($topic, $msg) = @_;
        fail( "Pin 4 was not set for event checks,"
            . " so this should never be called" );
        return;
    },
);
$_->recv for $subscribe1_cv, $subscribe2_cv;
diag "Done subscribing";

my $input_timer; $input_timer = AnyEvent->timer(
    after => 0.5,
    cb => sub {
        diag "Sending input on pin 3 and 4";
        $mock->mock_set_input( 3, 1 );
        $mock->mock_set_input( 4, 1 );
    },
);


my $cv = AE::cv;
# Timeout after a few seconds
my $timer; $timer = AnyEvent->timer(
    after => 2,
    cb => sub {
        $cv->send;
    },
);
$cv->recv;
