#!/usr/bin/perl

use Test::More 'skip_all' => 'Tests not ready';

require ( 'bin/install_esite' );

ok ( main() );
