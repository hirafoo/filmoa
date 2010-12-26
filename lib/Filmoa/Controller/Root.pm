package Filmoa::Controller::Root;
use Filmoa::Utils;

sub index     { +{tweets   => get_tweets(params)} }
sub mentions  { +{tweets   => get_tweets(params), title => "mentions"} }
sub retweets  { +{tweets   => get_tweets(params), title => "retweets"} }
sub messages  { +{tweets   => get_tweets(params), title => "messages"} }
sub favorated { +{statuses => get_favorated(), title => "favorated"} }

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

sub create_friend {
    nt->create_friend(params->{id});
    +{template => '_done'};
}
sub destroy_friend {
    nt->destroy_friend(params->{id});
    +{template => '_done'};
}

1;
