package DBTestUtil;

use base 'Exporter';
use Everything::Config;

our @EXPORT_OK = qw/config_file drop_database skip_cond nodebase/;


sub config_file {

    my $db_type = db_type();
    return "t/lib/db/$db_type.conf";

}

sub db_type {

   $0 =~ m|t/ecore/(.*?)/\d{3}\-[\w-]+\.t$|;
   return $1;

}

sub drop_database {

    my $config_file = config_file();
    my $config = Everything::Config->new(  file => $config_file );

    my $storage_class = 'Everything::DB::' . $config->database_type;

    ( my $file = $storage_class ) =~ s/::/\//g;
    $file .= '.pm';
    require $file;

    $storage_class->drop_database (
	$config->database_name,
        $config->database_superuser,
	$config->database_superpassword
				  );


}

sub skip_cond {
    my ( $class ) = @_;

    my $run_tests = 't/lib/db/run-tests';

    my $config_file = config_file();

    my $msg = '';


    if ( ! -e $run_tests  ) {

	return "Time consuming DB tests skipped by default.  Touch '$run_tests' to run.";

    } elsif ( ! -e $config_file ) {

	return "The config file '$config_file' must exist to run these tests.";
    }

    return;

}

sub nodebase {

    my $config = Everything::Config->new( file => config_file() );
    return $config->nodebase;


}
