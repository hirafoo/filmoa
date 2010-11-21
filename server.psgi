package Filmoa;
use parent qw/Class::Accessor::Fast/;
use strict;
use warnings;
use Config::Pit qw/pit_get/;
use Data::Dumper qw/Dumper/;
use Encode qw/find_encoding/;
use HTML::Entities qw/encode_entities decode_entities/;
use Net::Twitter;
use Path::Class;
use Plack::Request;
use Text::Xslate;
use Time::Piece;

__PACKAGE__->mk_accessors(qw/nt xt user action/);

sub p {
    warn Dumper @_;
    my @c = caller;
    print STDERR "  at $c[1]:$c[2]\n\n"
}

my ($sjis, $utf) = (find_encoding('shiftjis'), find_encoding('utf-8'));
sub utf { $utf }

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
            $html .= '<a href="http://twitter.com/' . encode_entities($user) . '" target="_blank">'
            . encode_entities($token) . '</a>';
        } else {
            $html .= encode_entities($token);
        }
    }
    $html;
}

sub init {
    my ($self) = @_;
    my $config = pit_get("filmoa");
    $self->user($config->{user});
    my $traits = [qw/API::Lists API::REST API::Search OAuth/];
    my %c = (
        consumer_key => $config->{consumer_key},
        consumer_secret => $config->{consumer_secret},
        traits => $traits,
    );
    $self->nt(Net::Twitter->new(\%c));
    #$self->nt(Net::Twitter::Lite->new(\%c));
    $self->nt->access_token($config->{access_token});
    $self->nt->access_token_secret($config->{access_token_secret});

    my %funcs = (
        tw_link => sub {
            my ($name, $text) = @_;
            $text ||= $name;
            qq{<a href="http://twitter.com/$name" target="_blank">$text</a>}
        },
        ago => sub {
            my $created_at = shift;
            my $now = localtime;
            $now += 32400;

            my $diff = $now->epoch - $created_at->epoch;

            if ($diff < 5) {
                "less than 5 seconds ago"
            }
            elsif ($diff < 10) {
                "less than 10 seconds ago"
            }
            elsif ($diff < 60) {
                "less than a minute ago"
            }
            elsif ($diff < 3600) {
                $diff = int($diff / 60);
                my $min = $diff == 1 ? "minute" : "minutes";
                "$diff $min ago"
            }
            elsif ($diff < 86400) {
                $diff = int($diff / 3600);
                my $hour = $diff == 1 ? "hour" : "hours";
                "about $diff $hour ago"
            }
            else {
                $created_at->ymd('/') . " " . $created_at->hms
            }
        },
    );

    $self->xt(
        Text::Xslate->new(
            syntax => 'TTerse',
            path => ["./template/"],
            cache => 0,
            function => \%funcs,
        )
    );
}

#my $root = file(__FILE__)->dir->absolute->stringify;

sub gen_app {
    my ($self, $action) = @_;

    my $app = sub {
        my $env = shift;
        my $req = Plack::Request->new($env);
        my $params = $req->parameters->as_hashref;
        my $html = "$action.html";
        $self->action($action);
        my %stash = (%{$self->$action($params)}, action => $action, params => $params, user => $self->user);
        my $body = utf->encode($self->xt->render($html, \%stash));
        return [
            '200',
            [ 'Content-Type' => 'text/html; charset=utf-8' ],
            [ $body ],
        ];
    };
}

my %api_table = (
    index    => "home_timeline",
    mentions => "mentions",
    retweets => "retweets_of_me",
    messages => "direct_messages",
    update   => "home_timeline",
);
sub get_tweets {
    my ($self, $params) = @_;
    my $page = $params->{page} ||= 1;
    my $max_id = $params->{max_id} ||= 0;
    my $meth = $api_table{$self->action};
    my %opt = (page => $page, ($max_id ? (max_id => $max_id) : ()));
    $self->fix_tweets($self->nt->$meth(\%opt));
}
sub index {
    my ($self, $params) = @_;
    +{tweets => $self->get_tweets($params)};
}
sub mentions {
    my ($self, $params) = @_;
    +{tweets => $self->get_tweets($params)};
}
sub retweets {
    my ($self, $params) = @_;
    +{tweets => $self->get_tweets($params)};
}
sub messages {
    my ($self, $params) = @_;
    +{tweets => $self->get_tweets($params)};
}
sub update {
    my ($self, $params) = @_;
    my $status_id = $params->{in_reply_to_status_id};
    my %post_params = (
        status => $utf->decode($params->{tweet} || ""),
        ($status_id ? (in_reply_to_status_id => $status_id) : ()),
    );
    $self->nt->update(\%post_params) if $post_params{status};
    +{tweets => $self->get_tweets($params)};
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
    my ($self, $tweets) = @_;
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
    my ($self, $params) = @_;
    my $parent_id = $params->{in_reply_to_status_id} or return;
    my $parent = $self->nt->show_status({id => $parent_id});
    my $grand_parent_id = $parent->{in_reply_to_status_id};
    $params = $grand_parent_id ? +{in_reply_to_status_id => $grand_parent_id} : +{};
    ($self->fix_tweets([$parent])->[0], $params);
}

sub reply {
    my ($self, $params) = @_;
    my ($parent_tweet, $grand_parent_tweet);
    ($parent_tweet, $params) = $self->get_parent($params);
    ($grand_parent_tweet, $params) = $self->get_parent($params);
    +{parent_tweet => $parent_tweet, grand_parent_tweet => $grand_parent_tweet}
}

package main;
use strict;
use warnings;
use Plack::Builder;

my $filmoa = Filmoa->new;
$filmoa->init;

builder {
    mount "/"         => builder { $filmoa->gen_app("index") };
    mount "/mentions" => builder { $filmoa->gen_app("mentions") };
    mount "/retweets" => builder { $filmoa->gen_app("retweets") };
    mount "/messages" => builder { $filmoa->gen_app("messages") };
    mount "/update"   => builder { $filmoa->gen_app("update") };
    mount "/reply"    => builder { $filmoa->gen_app("reply") };
};
