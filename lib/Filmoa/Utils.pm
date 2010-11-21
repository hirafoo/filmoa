package Filmoa::Utils;
use parent qw/Exporter/;
use strict;
use warnings;
use Data::Dumper qw/Dumper/;
use Encode qw/find_encoding/;
use Filmoa;
use Filmoa::Router;
use HTML::Entities qw/encode_entities decode_entities/;
use Time::Piece;

our @EXPORT = qw/p say utf router config nt
                 get_tweet get_tweets fix_tweets get_parent/;

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

my ($utf, $router) = (
    find_encoding('utf-8'),
    Filmoa::Router->routing,
);

sub config { $Filmoa::config }
sub utf { $utf }
sub router { $router }
sub nt { $Filmoa::nt }

sub parse_time {
    my ($created_at, $opt) = @_;

    $opt ? (Time::Piece->strptime($created_at, '%a, %d %b %Y %H:%M:%S +0000') + 32400)
         : (Time::Piece->strptime($created_at, '%a %b %d %H:%M:%S +0000 %Y')  + 32400);
}

sub add_link {
    my $tweet = shift;
    my $html = '';
    for my $token (split m{(http://[A-Za-z0-9_%@/~\-\.\?\#]+|\@[0-9A-Za-z_]+)}, $tweet) {
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

sub get_tweet {
    my $id = shift;
    my $tweet = nt->show_status({id => $id});
    fix_tweets([$tweet])->[0];
}

my %api_table = (
    index    => "home_timeline",
    mentions => "mentions",
    retweets => "retweets_of_me",
    messages => "direct_messages",
    update   => "home_timeline",
    user     => "user_timeline",
);
sub get_tweets {
    my ($params) = @_;
    my $page   = $params->{page} ||= 1;
    my $max_id = $params->{max_id} ||= 0;
    my $meth   = $api_table{$params->{action}};
    my $user   = $params->{user};
    my %opt    = (
        page => $page,
        ($max_id ? (max_id => $max_id) : ()),
        ($user ? (screen_name => $user) : ()),
    );
    fix_tweets(nt->$meth(\%opt));
}

sub _fix_tweet {
    my ($t, $is_rt) = @_;
    $t->{text_linked} = decode_entities(add_link($t->{text}));
    $t->{text} = decode_entities($t->{text});
    $t->{created_at} = parse_time($t->{created_at});
    $t->{source} = decode_entities($t->{source} || "");
    $t->{by} = ($t->{user}{screen_name} or $t->{sender}{screen_name} or $t->{from_user});
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

sub get_parent {
    my ($params) = @_;
    my $parent_id = $params->{in_reply_to_status_id} or return;
    my $parent = nt->show_status({id => $parent_id});
    my $grand_parent_id = $parent->{in_reply_to_status_id};
    $params = $grand_parent_id ? +{in_reply_to_status_id => $grand_parent_id} : +{};
    (fix_tweets([$parent])->[0], $params);
}

1;
