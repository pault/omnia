package Everything::HTTP::ResponseFactory;

use strict;


use base 'Class::Factory';


__PACKAGE__->add_factory_type('htmlpage' => 'Everything::HTTP::Response::Htmlpage');

=head1 Everything::HTTP::ResponseFactory

ResponseFactory - Creating a response to an Everything request

=head1 SYNOPSIS

Everything::HTTP::ResponseFactory->register_factory_type('type' => 'Name::of::package');

Everything::HTTP::ResponseFactory->add_factory_type('anothertype' => 'Name::of::another::package');

my $response = Everything::HTTP::ResponseFactory->new(<response type>, [@args]);

$response->create_http_body;

my $html = $response->get_http_body;

my $mime_type = $response->get_mime_type;

my $header = $response->create_http_header;



=head1 DESCRIPTION

This is a factory class, that is, the constructor returns instances that are blessed into other classes, not this one.

This class inherits from C<Class::Factory>, so the rules for adding types and the rules instanciation are the same as they are in C<Class::Factory>. In essense, if you want to customise the way your classes are instanciated you should use the C<init> method.

In addition, the instances that this class provides must support the following methods:

=over 4

=item get_http_body set_http_body

Getters and setters for the http_body attribute.

=item get_http_header set_http_header

Getters and setters for the http_header attribute.

=item get_mime_type set_mime_type

Getters and setters for the mime_type attribute.

=back

In addition, the followimg methods must be supported:

=over 4

=item create_http_header

Conjures a conforming http header and sets the http_header attribute.

=item create_http_body

Conjures up a conforming http body and sets the http_body attribute.

=item create_mime_type

Conjures up a  mime type (from where is not important) and sets the mime_type attribute.

=back

=cut

1;
