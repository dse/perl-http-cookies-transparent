package HTTP::Cookies::Transparent;
use warnings;
use strict;

our $VERSION = "0.0";

=head1 NAME

HTTP::Cookies::Transparent - Transparent HTTP cookies for LWP::UserAgent

=head1 SYNOPSIS

    use LWP::UserAgent;
    use HTTP::Cookies::Transparent;

    # An empty, temporary cookie jar.
    HTTP::Cookies::Transparent::init();

    my $agent = LWP::UserAgent->new();
    my $request = HTTP::Request->new("GET", "http://www.sn.no/");
    my $response = $agent->request($request);

To specify a cookie jar with or without HTTP::Cookies arguments:

    HTTP::Cookies::Transparent::init(@arguments);

    # A persistent cookie jar, for example:
    HTTP::Cookies::Transparent::init(
        file     => "$ENV{'HOME'}/.cookies.dat",
        autosave => 1
    );

To stop providing a cookie jar to new LWP::UserAgent objects:

    HTTP::Cookies::Transparent::init("none");

=head1 DESCRIPTION

If you need to use a module that uses LWP::UserAgent but does not
provide access to the underlying object (WebService::Pandora is an
example), this module will at least allow you to specify an
HTTP::Cookies cookie jar object for it.

=head1 INITIALIZING

HTTP::Cookies::Transparent monkey-patches LWP::UserAgent's constructor
by "wrapping" it inside a method that assigns a cookie_jar to newly
created LWP::UserAgent objects if one is not already specified in its
constructor's arguments.

To turn on this behavior, call HTTP::Cookies::Transparent::init()
before creating LWP::UserAgent objects or objects of whatever class
uses it:

    HTTP::Cookies::Transparent::init(
        # specify any HTTP::Cookies arguments, or none, here
    );

and an HTTP::Cookies object will be created with the arguments you've
specified, and it will be used by subsequently created LWP::UserAgent
objects.

For example, to create a persistent cookie jar that gets automatically
saved to and read from a disk file:

    HTTP::Cookies::Transparent::init(
        file     => "$ENV{'HOME'}/.cookies.dat",
        autosave => 1
    );

To create an empty, temporary cookie jar, pass no arguments:

    HTTP::Cookies::Transparent::init();

For convenience, you may also pass an array reference:

    HTTP::Cookies::Transparent::init([
        file     => "$ENV{'HOME'}/.cookies.dat",
        autosave => 1
    ]);

    # same as no arguments
    HTTP::Cookies::Transparent::init([]);

or a hash reference as the sole argument to init:

    HTTP::Cookies::Transparent::init({
        file     => "$ENV{'HOME'}/.cookies.dat",
        autosave => 1
    });

    # same as no arguments
    HTTP::Cookies::Transparent::init({});

To stop assigning a cookie jar to subsequently created LWP::UserAgent
objects, call init() with a single argument, the string C<"none">:

    HTTP::Cookies::Transparent::init("none");

You may also create an HTTP::Cookies object and pass it to init():

    my $cookie_jar = HTTP::Cookies->new(...);
    # ...

    HTTP::Cookies::Transparent::init($cookie_jar);

=head1 SUBSEQUENT INIT() CALLS

Once init() is called, the same HTTP::Cookies object will be used by
all subsequently created LWP::UserAgent objects until init() is called
again.

After init() is called a second (or third, fourth, etc.) time,
previously created LWP::UserAgent objects will continue to use the
HTTP::Cookies objects they were initialized with while new ones will
use the new HTTP::Cookies object.

    HTTP::Cookies::Transparent::init(@args1); # creates cookie jar #1

    $ua1 = LWP::UserAgent->new();             # uses cookie jar #1
    # ...
    $ua2 = LWP::UserAgent->new();             # uses cookie jar #1
    # ...

    HTTP::Cookies::Transparent::init(@args2); # creates cookie jar #2

    $ua3 = LWP::UserAgent->new();             # uses cookie jar #2
    # ...
    $ua4 = LWP::UserAgent->new();             # uses cookie jar #2
    # ...

    # at this point, $ua1 and $ua2 will continue to use cookie jar #1.

    HTTP::Cookies::Transparent::init("none");

    $ua5 = LWP::UserAgent->new();             # no cookie jar
    # ...
    $ua6 = LWP::UserAgent->new();             # no cookie jar
    # ...

    # at this point, $ua1 and $ua2 will continue to use cookie jar #1,
    # and $ua3 and $ua4 will continue to use cookie jar #2.

=head1 AUTHOR

Darren Embry, C<dse at webonastick dot com>.

=head1 GIT REPOSITORY

    https://github.com/dse/perl-http-cookies-transparent

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2004-2007 by Darren Embry.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.4 or,
at your option, any later version of Perl 5 you may have available.

=cut

our $initialized = 0;
our $orig_lwp_useragent_new;
our $cookie_jar;

use Scalar::Util qw(blessed);

sub init {
    my (@args) = @_;            # cookie jar options

    if (!$initialized) {
        $orig_lwp_useragent_new = \&LWP::UserAgent::new;
        no warnings;
        *LWP::UserAgent::new = \&_lwp_useragent_new;
        $initialized = 1;
    }

    if (scalar @args == 1 && $args[0] eq "none") {
        $cookie_jar = undef;
    } elsif (scalar @args == 1 && ref $args[0] eq "HASH") {
        $cookie_jar = HTTP::Cookies->new(%{$args[0]});
    } elsif (scalar @args == 1 && ref $args[0] eq "ARRAY") {
        $cookie_jar = HTTP::Cookies->new(@{$args[0]});
    } elsif (scalar @args == 1 &&
                 blessed $args[0] && $args[0]->isa("HTTP::Cookies")) {
        $cookie_jar = $args[0];
    } else {
        $cookie_jar = HTTP::Cookies->new(@args);
    }
}

sub _lwp_useragent_new {
    my (@args) = @_;            # constructor arguments
    my $self = &$orig_lwp_useragent_new(@args);
    if (defined $cookie_jar && !$self->cookie_jar) {
        $self->cookie_jar($cookie_jar);
    }
    return $self;
}

1;
