package Filmoa::Config;
use parent qw/Exporter/;
use Filmoa::Utils;
use Config::Pit qw/pit_get/;

our @EXPORT = qw/config/;

sub config { pit_get("filmoa") }

1;
