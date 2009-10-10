package Everything::Template::Provider;

use strict;
use Time::Local;
use Template;
use Template::Constants qw(:all);
use base qw(Template::Provider);

sub _init {
    my ( $self, $args ) = @_;


    $self->{nodebase} = $$args{nodebase};
    $self->SUPER::_init( $args );
    return $self;
}

sub get_nodebase {
    my $self = shift;
    return $self->{nodebase};

}

sub fetch {
        my($self, $text) = @_;
        my($name, $data, $error, $slot, $size, $compname, $compfile);

        $size = $self->{ SIZE };

	return ($text->{data}, undef) if ref $text eq "HASH";

        # if reference, then get a unique name to cache by
        if (ref $text eq 'SCALAR') {
                $text = $$text;
                #print STDERR "fetch text : $text\n" if $DEBUG > 2;
                $name = "inline func";
                $compname = $name if $self->{COMPILE_DIR};

        # if regular scalar, get proper template ID ("name") from DB
        }

        if ($self->{COMPILE_DIR}) {
                my $ext = $self->{COMPILE_EXT} || '.ttc';
                $compfile = catfile($self->{COMPILE_DIR}, $compname . $ext);
                #warn "compiled output: $compfile\n" if $DEBUG;
        }

        # caching disabled so load and compile but don't cache
        if (defined $size && !$size) {
                #print STDERR "fetch($name) [nocache]\n" if $DEBUG;
                ($data, $error) = $self->_load($name, $text);
                ($data, $error) = $self->_compile($data, $compfile) unless $error;
                $data = $data->{ data } unless $error;

        } else {
                #print STDERR "fetch($name) [uncached:$size]\n" if $DEBUG;

                ($data, $error) = $self->_load($name, $text);
                ($data, $error) = $self->_compile($data) unless $error;

		$name ||= $data->{name};

                $data = $self->_store($name, $data) unless $error;
        }

	
        return($data, $error);
}

sub _load {
        my($self, $name, $text) = @_;
        my($data, $error, $now, $time);
        $now = time();
        $time = 0;

        #print STDERR "_load(@_[1 .. $#_])\n" if $DEBUG;

	if(ref $name eq "SCALAR")
	{
		$text = $$name;
		$name = "inline func";
	}

        if (! defined $name) {

                my $temp = $self->{nodebase}->getNode($text, "template");

		if($temp){
                	$text = $temp->{doctext};
			if($Everything::HTML::USER->{inside_workspace})
			{
				$name = $temp->{title}."_".$Everything::HTML::USER->{inside_workspace};
			}else{
				$name = $temp->{title};
			}

			my ($year, $mon, $day, $hour, $min, $sec) = split(/[\-\s\:]/, $temp->{modified});

			$sec = int($sec) || 0;
			$min = int($min) || 0;
			$hour = int($hour) || 0;
			$day = int($day) ||  1;
			$mon = int($mon) || 1;
			$year = int($year) || 1900;

                	$time = timelocal($sec, $min, $hour, $day, $mon-1, $year-1900);
		}else
		{
			return (undef, STATUS_DECLINED);
		}
        }

        # just in case ... most data from DB will be in CRLF, doesn't
        # hurt to do this quick s///
        $text =~ s/\015\012/\n/g;

        $data = {
                name    => $name,
                text    => $text,
                'time'  => $time,
                load    => $now,
        };

        return($data, $error);
}


1;
