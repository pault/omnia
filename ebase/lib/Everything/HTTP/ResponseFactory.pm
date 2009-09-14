package Everything::HTTP::ResponseFactory;

use strict;


use base 'Class::Factory';


__PACKAGE__->add_factory_type('htmlpage' => 'Everything::HTTP::Response::Htmlpage');
__PACKAGE__->add_factory_type('nodeball' => 'Everything::HTTP::Response::Nodeball');
__PACKAGE__->add_factory_type('stylesheet' => 'Everything::HTTP::Response::stylesheet');
__PACKAGE__->add_factory_type('javascript' => 'Everything::HTTP::Response::javascript');

=head1 Everything::HTTP::ResponseFactory

ResponseFactory - Creating a response to an Everything request

=head1 SYNOPSIS

Everything::HTTP::ResponseFactory->register_factory_type('type' => 'Name::of::package');

Everything::HTTP::ResponseFactory->add_factory_type('anothertype' => 'Name::of::another::package');

my $response = Everything::HTTP::ResponseFactory->new(<response type>, { args } );

my $html = $response->content;

my $content_type = $response->content_type;



=head1 DESCRIPTION

This is a factory class, that is, the constructor returns instances that are blessed into other classes, not this one.

This class inherits from C<Class::Factory>, so the rules for adding types and the rules instanciation are the same as they are in C<Class::Factory>. In essense, if you want to customise the way your classes are instanciated you should use the C<init> method.

The objects created by this class must return values that allow a
response be sent back to the client browser.

=over 4

=item C<new>

This is the constructor. It takes two arguments:

=over

=item

The first is a string that determines the type of object return.

=item

The second is a hash ref that is passed straight to the created objects.  Attributes may include:

=over

=item config

An Everything::Config object.

=item request

An Everything::HTTP::Request object.

=back

=back

=back

In addition, the instances that this class provides must support the following methods:

=over 4

=item content_type

Returns the data for the Content-Type header.

=item headers

Returns a hash of headers.  By default does not return the Content-Type header.

=item content

Returns the message body

=item status_code

Returns the HTTP status code.

=back

=cut

1;
