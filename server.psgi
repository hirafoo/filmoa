use strict;
use warnings;
use lib qw/lib/;
use Filmoa;
use Filmoa::Utils;
use Filmoa::Loader;
use Filmoa::Handler;
use Plack::Builder;

Filmoa->setup;

my $app = sub {
    my $env = shift;
    Filmoa::Handler->handler($env);
};

builder {
    $app;
};
