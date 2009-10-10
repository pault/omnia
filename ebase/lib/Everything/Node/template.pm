package Everything::Node::template;

use Template;
use Everything::Template::Provider;
use Moose::Policy 'Moose::Policy::FollowPBP';
use Moose;

extends 'Everything::Node::document';

sub process{ 
    my ( $self, $vars, $nodebase, $tt ) = @_;

    $tt ||= Template->new( { LOAD_TEMPLATES => [ Everything::Template::Provider->new( {  nodebase => $nodebase }  ) ]} );
    my $output;
    my $input_text = $self->get_doctext;
    $tt->process( \$input_text, $vars, \$output );

    return $output;
};
