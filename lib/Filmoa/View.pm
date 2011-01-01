package Filmoa::View;
use Filmoa::Config;
use Filmoa::Utils;
use Text::Xslate;
use Time::Piece;

sub xt {
    Text::Xslate->new(
        syntax => 'TTerse',
        path => ["./template/"],
        cache => 0,
        function => funcs(),
    );
}

sub _link {
    my ($href, $text) = @_;
    qq{<a href="$href" target="_blank">$text</a>}
}

my $config = config;
sub funcs {
    +{ 
        config => $config,
        link => sub {
            my ($href, $text) = @_;
            $href or return;
            $text ||= $href;
            _link($href, $text);
        },
        user_link => sub {
            my ($name) = @_;
            _link("/user/$name", $name);
        },
        ago => \&ago,
        ago_or_date => sub {
            my $created_at = shift;
            my $ago = ago($created_at);
            my $ymd_hms = ymd_hms($created_at);
            $ago eq $ymd_hms ? $ymd_hms : $ago;
        },
    }
}

sub ago {
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
}

1;
