eval "use Finance::Quote;";

if ($@) {
	print "
It looks like you don't have Finance::Quote installed.  This nodeball needs
it.  Go get it from CPAN, otherwise it won't work!

";
} else {
	print "
Oh, good.  You already have Finance::Quote installed!

";

}

print "
------------------------------------------------------------------------
Thanks for installing the Stock nodeball.

Caveats:

	don't let any users you don't trust turn the nodelet on.  For every
	new stock they add, your computer will do a HTTP get from your stock
	source.  The nodelet is not +x for Guest User;

	stocks currently only use NYSE and US Dollars -- Finance::Quote can
	use others.  Change [setupFQ] and the default [stock] 'market' field
	if you wanna.

	The default Finance::Quote source is Yahoo.  There might be legal
	issues if you're using this for some sort of commercial portal.
	Find another source or don't use it if you're paranoid.
	
Otherwise, have fun!  Now you too can see how much money you can lose
on NYSE!
									--[nate]
	

";
