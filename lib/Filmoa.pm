package Filmoa;
use Filmoa::Utils;
use Filmoa::Loader;
use Config::Pit qw/pit_get/;
use Net::Twitter;

our ($config, $nt, $params);

sub setup {
    my $class = shift;
    $class->init;
}

sub init {
    my $class = shift;
    $config = pit_get("filmoa"),
    $params = +{};
    $class->init_nt;
}

sub init_nt {
    my $traits = [qw/API::Lists API::REST API::Search OAuth/];
    my %c = (
        consumer_key => config->{consumer_key},
        consumer_secret => config->{consumer_secret},
        traits => $traits,
    );
    $nt = Net::Twitter->new(\%c);
    $nt->access_token(config->{access_token});
    $nt->access_token_secret(config->{access_token_secret});
    $nt;
}


1;
