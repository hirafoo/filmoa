package Filmoa::Controller::User;
use Filmoa::Utils;

sub index { +{tweets => get_tweets(params)} }

sub status {
    my $target_tweet = get_tweet(params->{id});
    my $parent_tweet = get_parent($target_tweet);
    +{target_tweet => $target_tweet, parent_tweet => $parent_tweet};
}

sub profile {
    my $user = nt->show_user(params->{user});
    +{user => $user};
}

1;
