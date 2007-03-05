#!/usr/bin/env perl
use warnings;
use strict;

package Test::OpenID::Consumer;
use Net::OpenID::Consumer;
use LWPx::ParanoidAgent;
use Cache::FileCache;
use base qw/Test::HTTP::Server::Simple HTTP::Server::Simple::CGI/;

our $VERSION = '0.01';

=head1 NAME

Test::OpenID::Consumer - setup a simulated OpenID consumer

=head1 SYNOPSIS

Test::OpenID::Consumer will provide a consumer to test your OpenID server
against.  To use it, do something like this:

   use Test::More tests => 1;
   use Test::OpenID::Consumer;
   my $consumer = Test::OpenID::Consumer->new;
   my $url_root = $consumer->started_ok("server started ok");

   $consumer->verify('http://server/identity/openid');

=cut

use Test::Builder;
my $Tester = Test::Builder->new;

=head1 METHODS

=head2 new

Create a new test OpenID consumer

=cut

sub new {
    my $self = shift;
    my $port = shift;

    $port = int(rand(5000) + 10000) if not defined $port;
    return $self->SUPER::new( $port );
}

=head2 started_ok

Test whether the consumer's server started, and if it did, return the URL
it's at.

=head1 METHODS

=head2 verify_openid URL

Attempts to verify the given OpenID.  At the moment, the verification MUST
NOT require any logging in or setup, but it may be supported in the future.

=cut

sub verify_openid {
    my $self   = shift;
    my $openid = shift;
    my $text   = shift;

    $text = 'verified OpenID' if not defined $text;

    my $baseurl = 'http://'
                  . ($self->host || 'localhost')
                  . ($self->port || '80');

    my $csr = Net::OpenID::Consumer->new(
        ua    => LWPx::ParanoidAgent->new,
        cache => Cache::FileCache->new,
        args  => { },
        consumer_secret => 'secret',
        required_root   => $baseurl
    );

    my $claimed = $csr->claimed_identity( $openid );

    if ( not defined $claimed ) {
        $Tester->ok( 0, $text );
        $Tester->diag( "OpenID: '$openid'\nError code: " . $csr->errcode );
        return;
    }

    $openid = $claimed->claimed_url;

    my $check_url = $claimed->check_url(
        return_to  => "$baseurl/return",
        trust_root => $baseurl
    );

    my $ua = LWPx::ParanoidAgent->new;
    $ua->get( $check_url );
}

=head1 INTERAL METHODS

These methods implement the HTTP server (see L<HTTP::Server::Simple>)
that the consumer uses.  You shouldn't call them.

=head2 handle_request

=cut

sub handle_request {
    my $self = shift;
    my $cgi = shift;

    if ( $ENV{'PATH_INFO'} eq '/return' ) {
        # We're dealing with the return path
        
        my $csr = Net::OpenID::Consumer->new(
            ua    => LWPx::ParanoidAgent->new,
            cache => Cache::FileCache->new,
            args  => $cgi,
            consumer_secret => 'secret'
        );

        if ( my $setup = $csr->user_setup_url ) {
            $Tester->ok( 0, 'verified OpenID' );
            $Tester->diag( 'verification required setup' );
            return;
        }
        elsif ( $csr->user_cancel ) {
            $Tester->ok( 0, 'verified OpenID' );
            $Tester->diag( 'verification canceled' );
            return;
        }

        my $ident = $csr->verified_identity;

        if ( not defined $ident ) {
            $Tester->ok( 0, 'verified OpenID' );
            $Tester->diag( 'verification failed: ' . $csr->err );
            return;
        }

        $Tester->ok( 1, 'verified OpenID' );
    }
    else {
        print "HTTP/1.0 200 OK\r\n";
        print "Content-Type: text/html\r\n\r\n";
        print <<"        END";
<html>
  <body>
    <p>This is an OpenID consumer.  It needs an HTTP server for testing.</p>
  </body>
</html>
        END
    }
}

=head1 AUTHORS

Thomas Sibley <trs@bestpractical.com>

=head1 COPYRIGHT

Copyright (c) 2007, Best Practical Solutions, LLC. All rights reserved.

=head1 LICENSE

You may distribute this module under the same terms as Perl 5.8 itself.

=cut

1;
