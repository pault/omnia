use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'	=> 'Bundle::Everything',
    'VERSION_FROM' => 'Everything.pm', # finds $VERSION
);
