package Filmoa::Controller::Root;
use Filmoa::Utils;

sub index    { +{tweets => get_tweets(params)} }
sub mentions { +{tweets => get_tweets(params)} }
sub retweets { +{tweets => get_tweets(params)} }
sub messages { +{tweets => get_tweets(params)} }
sub favs { +{favs => get_favs()} }

sub update {
    my $status_id = params->{in_reply_to_status_id};
    my %post_params = (
        status => utf->decode(params->{tweet} || ""),
        ($status_id ? (in_reply_to_status_id => $status_id) : ()),
    );
    nt->update(\%post_params) if $post_params{status};
    +{tweets => get_tweets(params)};
}

sub reply {
    my ($target_tweet, $parent_tweet);
    $target_tweet = get_tweet(params->{in_reply_to_status_id});
    $parent_tweet = get_parent($target_tweet);
    +{target_tweet => $target_tweet, parent_tweet => $parent_tweet}
}

1;
