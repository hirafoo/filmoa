package Filmoa::Twitter;
use Filmoa::Config;
use Filmoa::Utils;
use Net::Twitter;

sub setup_nt {
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
