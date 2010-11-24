package Filmoa::Handler;
use Filmoa::Utils;
use Filmoa::View;
use Plack::Request;

sub handler {
    my ($class, $env) = @_;

    my $req = Plack::Request->new($env);
    my $params = $req->parameters->as_hashref;
    my $match = router->match($env);
    $match = +{
        action => "index",
        %$match,
    };
    $params = +{ %$params, %$match };
    params($params);

    if ($match) {
        my $controller = "Filmoa::Controller::" . ucfirst $match->{controller};
        my $action = $match->{action};
        my $action_res = $controller->$action();
        
        my $template;
        my $xt = Filmoa::View->xt;
        $template  = lc $match->{controller};
        $template .= "/" . ($action_res->{template} || $action) . ".html";

        my %stash = (%$action_res, action => $action, params => $params, you => config->{you});
        my $content = utf->encode($xt->render($template, \%stash));

        my $res = $req->new_response(200);
        $res->content_type('text/html');
        $res->content($content);
        $res->finalize;
    }
}

1;
