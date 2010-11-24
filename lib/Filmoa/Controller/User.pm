package Filmoa::Controller::User;
use Filmoa::Utils;

sub index { +{tweets => get_tweets($_[1])} }
sub status {
    my ($class, $params) = @_;
    my $target_tweet = get_tweet($params->{id});
    my $parent_tweet = get_parent($target_tweet);
    +{target_tweet => $target_tweet, parent_tweet => $parent_tweet};
}

1;
