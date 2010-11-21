package Filmoa::Controller::Root;
use Filmoa::Utils;

sub index    { +{tweets => get_tweets($_[1])} }
sub mentions { +{tweets => get_tweets($_[1])} }
sub retweets { +{tweets => get_tweets($_[1])} }
sub messages { +{tweets => get_tweets($_[1])} }

sub update {
    my ($class, $params) = @_;
    my $status_id = $params->{in_reply_to_status_id};
    my %post_params = (
        status => utf->decode($params->{tweet} || ""),
        ($status_id ? (in_reply_to_status_id => $status_id) : ()),
    );
    nt->update(\%post_params) if $post_params{status};
    +{tweets => get_tweets($params)};
}

sub reply {
    my ($class, $params) = @_;
    my ($parent_tweet, $grand_parent_tweet);
    ($parent_tweet, $params) = get_parent($params);
    ($grand_parent_tweet, $params) = get_parent($params);
    +{parent_tweet => $parent_tweet, grand_parent_tweet => $grand_parent_tweet}
}

1;
