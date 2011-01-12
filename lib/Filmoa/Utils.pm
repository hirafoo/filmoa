package Filmoa::Utils;
use parent qw/Exporter/;
use strict;
use warnings;
use Data::Dumper qw/Dumper/;
use Encode qw/find_encoding/;
use Filmoa::Config;
use Filmoa::Router;
use Filmoa::Twitter;
use HTML::Entities qw/encode_entities decode_entities/;
use Time::Piece;
use LWP::UserAgent;
use XML::RSS;

our @EXPORT = qw/
    p say utf router nt params ymd_hms
    get_tweet get_tweets get_parent get_tweet_tree fix_tweets get_favorated
/;

sub import {
    strict->import;
    warnings->import;
    __PACKAGE__->export_to_level(1, @_);
}

sub say { print @_, "\n" }

sub p {
    local $Data::Dumper::Indent = 1;
    local $Data::Dumper::Terse  = 1;
    warn Dumper @_;
    my @c = caller;
    print STDERR "  at $c[1]:$c[2]\n\n"
}

my ($utf, $router, $nt, $params) = (
    find_encoding('utf-8'),
    Filmoa::Router->routing,
    Filmoa::Twitter->setup_nt,
    +{},
);

config->{you} = $nt->verify_credentials->{screen_name};

sub utf { $utf }
sub router { $router }
sub nt { $nt }
sub params {
    my $p = shift;
    $p ? ($params = $p) : $params;
}

sub parse_time {
    my ($created_at, $opt) = @_;

    $opt ? (Time::Piece->strptime($created_at, '%a, %d %b %Y %H:%M:%S +0000') + 32400)
         : (Time::Piece->strptime($created_at, '%a %b %d %H:%M:%S +0000 %Y')  + 32400);
}

sub add_link {
    my $tweet = shift;
    my $html = '';
    for my $token (split m{(http://[A-Za-z0-9_=%@&/~\!\-\.\?\#\+]+|\@[0-9A-Za-z_]+)}, $tweet) {
        if ($token =~ m{^http://}) {
            $html .= '<a href="' . encode_entities($token) . '" target="_blank">'
            . encode_entities($token) . '</a>';
        } elsif ($token =~ m{^\@(.*)$}) {
            my $user = $1;
            $html .= '<a href="/user/' . encode_entities($user) . '" target="_blank">'
            . encode_entities($token) . '</a>';
        } else {
            $html .= encode_entities($token);
        }
    }
    $html;
}

my %api_table = (
    Root => {
        index    => "home_timeline",
        mentions => "mentions",
        retweets => "retweets_of_me",
        messages => "direct_messages",
        update   => "home_timeline",
    },
    User => {
        index    => "user_timeline",
    },
);
sub get_tweets {
    my ($params) = @_;
    my $page   = $params->{page} ||= 1;
    my $max_id = $params->{max_id} ||= 0;
    my $meth   = $api_table{$params->{controller}}->{$params->{action}};
    my $user   = $params->{user};
    my %opt    = (
        page => $page,
        count => 10,
        ($max_id ? (max_id => $max_id) : ()),
        ($user ? (screen_name => $user) : ()),
    );
    fix_tweets(nt->$meth(\%opt));
}

sub _fix_tweet {
    my ($t, $is_rt) = @_;
    $t->{text_linked} = decode_entities(add_link($t->{text}));
    $t->{text}        = decode_entities($t->{text});
    $t->{created_at}  = parse_time($t->{created_at});
    $t->{source}      = decode_entities($t->{source} || "");
    $t->{by}          = ($t->{user}{screen_name} or $t->{sender}{screen_name} or $t->{from_user});
    if ($is_rt) {
        $t->{text_linked} =~ s/^RT //;
        $t->{text} =~ s/^RT //;
    }
}
sub fix_tweets {
    my ($tweets) = @_;
    my @fixed;
    for my $t (@$tweets) {
        _fix_tweet($t);
        if (my $rt = $t->{retweeted_status}) {
            _fix_tweet($rt, 1);
        }
        push @fixed, $t;
    }
    \@fixed;
}

sub get_tweet {
    my $id = shift or return;
    my $tweet = nt->show_status({id => $id});
    fix_tweets([$tweet])->[0];
}
sub get_parent {
    my $tweet = shift or return;
    get_tweet($tweet->{in_reply_to_status_id});
}
sub get_tweet_tree {
    my $tweet = shift or return;
    my @tree;
    while (my $t = get_parent($tweet)) {
        push @tree, $t;
        $tweet = $t;
    }
    \@tree;
}

sub get_favorated {
    my $user = shift || config->{you};

    my @statuses;
    my $ua = LWP::UserAgent->new;
    my $rss = XML::RSS->new;
    my $body = $rss->parse($ua->get("http://ja.favstar.fm/users/$user/rss")->decoded_content);
    for my $i (@{$body->{items}}) {
        my $content = $i->{title};
        $content =~ s/stars?/favs/;
        my $link = $i->{link};
        $link =~ s{http://favstar.fm/users/}{http://twitter.com/};
        push @statuses, +{content => $content, link => $link};
    }
    \@statuses;
}

sub ymd_hms {
    my $created_at = shift;
    $created_at->ymd('/') . " " . $created_at->hms;
}

1;
