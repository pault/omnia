print "1..1\n";
print ( eval { require Bundle::Everything } ? 'ok ' : 'not ok ' ),;
	"1 - used Bundle::Everything successfully\n";
