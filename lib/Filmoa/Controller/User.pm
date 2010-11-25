package Filmoa::Controller::User;
use Filmoa::Utils;

sub index {
    my $user = nt->show_user(params->{user});
    +{user => $user, tweets => get_tweets(params)}
}

sub status {
    my $target_tweet = get_tweet(params->{id});
    my $parent_tweet = get_parent($target_tweet);
    +{target_tweet => $target_tweet, parent_tweet => $parent_tweet};
}

sub profile {
    my $user = nt->show_user(params->{user});
    +{user => $user};
}

sub following {
    my $cursor = params->{cursor} || -1;
    my $following = nt->friends({id => params->{user}, count => 40, cursor => $cursor});
    +{data => $following, current_cursor => $cursor}
}

sub followers {
    my $cursor = params->{cursor} || -1;
    my $followers = nt->followers({id => params->{user}, count => 40, cursor => $cursor});
    +{data => $followers, current_cursor => $cursor}
}

1;
