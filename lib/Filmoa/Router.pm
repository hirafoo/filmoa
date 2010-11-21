package Filmoa::Router;
use Filmoa::Utils;
use Router::Simple::Declare;

sub routing {
    router {
        connect '/',                             {controller => "Root"};
        connect '/{action:\w+}',                 {controller => "Root"};
        connect '/user/',                        {controller => "User"};
        connect '/user/{user:\w+}',              {controller => "User"};
        connect '/user/{user:\w+}/{action:\w+}', {controller => "User"};
    };
}

1;
