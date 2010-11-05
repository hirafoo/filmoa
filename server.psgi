package Filmoa;
use parent qw/Class::Accessor::Fast/;
use strict;
use warnings;
use Data::Dumper qw/Dumper/;
use Config::Pit;
use Encode qw/find_encoding/;
use HTML::Entities qw/encode_entities decode_entities/;
use Net::Twitter;
use Path::Class;
use Plack::Request;
use Text::Xslate;
use Time::Piece;

__PACKAGE__->mk_accessors(qw/nt xt user/);

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
    for my $token (split m{(http://[0-9A-Za-z_\-\.\%\?\#\@/]+|\@[0-9A-Za-z]+)}, $tweet) {
        if ($token =~ m{^http://}) {
            $html .= '<a href="' . encode_entities($token) . '">'
            . encode_entities($token) . '</a>';
        } elsif ($token =~ m{^\@(.*)$}) {
            my $user = $1;
            $html .= '<a href="http://twitter.com/' . encode_entities($user) . '">'
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
    );

    $self->xt(
        Text::Xslate->new(
            syntax     => 'TTerse',
            tag_start  => '[%',
            tag_end    => '%]',
            path => ["./template/"],
            cache => 0,
            function => \%funcs,
            #type => "text",
        )
    );
}

#my $root = file(__FILE__)->dir->absolute->stringify;

sub gen_app {
    my ($self, $action_uri) = @_;

    my $app = sub {
        my $env = shift;
        my $req = Plack::Request->new($env);
        my $params = $req->parameters->as_hashref;
        my $html = "$action_uri.html";
        my %stash = (%{$self->$action_uri($params)}, action_uri => $action_uri, params => $params, user => $self->user);
        my $body = utf->encode($self->xt->render($html, \%stash));
        return [
            '200',
            [ 'Content-Type' => 'text/html; charset=utf-8' ],
            [ $body ],
        ];
    };
}

sub index {
    my ($self, $params) = @_;
    my $page = $params->{page} ||= 1;
    my $max_id = $params->{max_id} ||= 0;
    my %opt = (page => $page, ($max_id ? (max_id => $max_id) : ()));
    +{tweets => $self->fix_tweets($self->nt->home_timeline(\%opt))}
}
sub mentions {
    my ($self, $params) = @_;
    my $page = $params->{page} ||= 1;
    my $max_id = $params->{max_id} ||= 0;
    my %opt = (page => $page, ($max_id ? (max_id => $max_id) : ()));
    +{tweets => $self->fix_tweets($self->nt->mentions(\%opt))}
}
sub retweets {
    my ($self, $params) = @_;
    my $page = $params->{page} ||= 1;
    my $max_id = $params->{max_id} ||= 0;
    my %opt = (page => $page, ($max_id ? (max_id => $max_id) : ()));
    +{tweets => $self->fix_tweets($self->nt->retweets_of_me(\%opt))}
}
sub messages {
    my ($self, $params) = @_;
    +{tweets => $self->fix_tweets($self->nt->direct_messages, "direct_messages")}
}
sub update {
    my ($self, $params) = @_;
    my $status_id = $params->{in_reply_to_status_id};
    my %post_params = (
        status => $utf->decode($params->{tweet}),
        ($status_id ? (in_reply_to_status_id => $status_id) : ()),
    );
    $self->nt->update(\%post_params);
}

sub fix_tweets {
    my ($self, $tweets) = @_;
    my @fixed;
    for my $t (@$tweets) {
        $t->{text_linked} = decode_entities(add_link($t->{text}));
        $t->{text} = decode_entities($t->{text});
        $t->{created_at} = parse_time($t->{created_at});
        $t->{source} = decode_entities($t->{source} || "");
        $t->{by} = ($t->{user}{screen_name} or $t->{sender}{screen_name} or $t->{from_user});
        push @fixed, $t;
    }
    \@fixed;
}

sub reply {
    my ($self, $params) = @_;
    my $parent_tweet;
    if (my $res_to = $params->{in_reply_to_status_id}) {
        $parent_tweet = $self->nt->show_status({id => $res_to});
        $parent_tweet = $self->fix_tweets([$parent_tweet])->[0];
    }
    +{parent_tweet => $parent_tweet}
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
