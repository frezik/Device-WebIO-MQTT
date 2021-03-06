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
use MockDigitalOutput;


if( defined $ENV{MQTT_SERVER} ) {
    plan tests => 2;
}
else {
    plan skip_all => "Set env var 'MQTT_SERVER' to run these tests";
}
my $MQTT_SERVER = $ENV{MQTT_SERVER};


my $webio = Device::WebIO->new;
my $mock = MockDigitalOutput->new({
    output_pin_count => 5,
});
$webio->register( 'mock', $mock );
# Ensure pin 3 is set to zero for now
$mock->output_pin( 3, 0 );
cmp_ok( $mock->mock_get_output( 3 ), '==', 0, "Pin 3 set to 0" );

my $prefix = Data::UUID->new->create_str;
my $webio_mqtt = AnyEvent::MQTT->new(
    host => $MQTT_SERVER,
);
my $dev_mqtt = Device::WebIO::MQTT->new({
    mqtt => $webio_mqtt,
    webio => $webio,
    topic_prefix => $prefix,
    output_checks => {
        mock => [ 3 ],
    },
});


my $mqtt = AnyEvent::MQTT->new(
    host => $MQTT_SERVER,
    client_id => Data::UUID->new->create_str,
);
my $output_cv = $mqtt->publish(
    message => 1,
    topic => $prefix . '/mock/gpio/3',
);
$output_cv->recv;

my $cv = AE::cv;
# Timeout after a few seconds
my $timer; $timer = AnyEvent->timer(
    after => 2,
    cb => sub {
        $cv->send;
    },
);
$cv->recv;

cmp_ok( $mock->mock_get_output( 3 ), '==', 1, "Pin 3 set to 1 with MQTT" );
