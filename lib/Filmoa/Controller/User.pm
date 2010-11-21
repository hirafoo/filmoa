package Filmoa::Controller::User;
use Filmoa::Utils;

sub index { +{tweets => get_tweets($_[1])} }
sub status { +{tweet => get_tweet($_[1]->{id})} }

1;
