package Filmoa::Config;
use parent qw/Exporter/;
use Filmoa::Utils;
use Config::Pit qw/pit_get/;

our @EXPORT = qw/config/;

my $config = pit_get("filmoa");
sub config { $config }

1;
