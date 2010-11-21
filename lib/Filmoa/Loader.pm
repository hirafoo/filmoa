package Filmoa::Loader;
use Filmoa::Utils;
use Module::Pluggable::Fast
    name    => 'components',
    require => 1,
    search  => [qw/Filmoa::Controller/];

sub import {
    for (__PACKAGE__->components) {
        $_->use;
    }
}

1;
