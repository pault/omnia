=head1 Everything::CacheQueue

A module for maintaining a queue in which you can easily pull items from the
middle of the queue and put them at the end again.  This is useful for caching
purposes.  Every time you use an item, pull it out from the queue and put it at
the end again.  The result is the least used items end up at the head of the
queue.

The queue is implemented as a double-linked list and a data field.

=cut

package Everything::CacheQueue;

use strict;
use Everything;

sub BEGIN
{
	use Exporter();
	use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
	@ISA=qw(Exporter);
	@EXPORT = qw(
		queueItem
		getNextItem
		getItem
		removeItem
		getSize
		listItems); 
}

=cut

=head2 C<new>

Constructs a new CacheQueue

Returns the newly constructed module object constructor

=cut

sub new
{
	my $class = shift;
	my $this = {};
	
	bless ($this, $class);
	
	$this->{queueHead} = $this->createQueueData("HEAD");
	$this->{queueTail} = $this->createQueueData("TAIL");

	# Hook them up
	$this->{queueHead}{prev} = $this->{queueTail};
	$this->{queueTail}{next} = $this->{queueHead};
	
	$this->{queueSize} = 0;

	# Keep track of how many permanent items we have in the cache.
	$this->{numPermanent} = 0;

	return $this;
}

=cut

=head2 C<queueItem>

Put the given data item at the end of the queue

=over 4

=item * $item

The data to put in the queue

=item * $permanent

True if this item should never be returned from getNextItem.  An item marked
permanent can still be removed manually using the removeItem function.

=back

Returns a reference to the queue data that represents the item.  Hold on to
this, you will need it for calls to getItem.  You should not modify any data
within this "object".

=cut

sub queueItem
{
	my ($this, $item, $permanent) = @_;
	my $data = $this->createQueueData($item, $permanent);

	$this->queueData($data);	
	
	return $data;
}

=cut

=head2 C<getItem>

Given the reference to the queue data (returned from queueItem()), return the
user's item.  This also pulls this item out of the queue and reinserts it at
the end.  This way the least used items are at the head of the queue.

=over 4

=item * $data

the queue data representing a user's item.  This is returned from queueItem().

=back

Returns the user's item

=cut

sub getItem
{
	my ($this, $data) = @_;

	# Since we used this item, put it back at the end (the least used will
	# work their way to head of the queue).
	$this->removeData($data);
	$this->queueData($data);
	
	return $$data{item};
}

=cut

=head2 C<getNextItem>

This pulls the "oldest" item off the head of the queue.  This removes the item
from the queue.  Any queue data references (returned from queueItem()) that you
are holding for this item should be deleted.  If the "oldest" item is
permanent, we will re-queue that item and find one that is not permanent.

Returns the user's item

=cut

sub getNextItem
{
	my ($this) = @_;
	my $firstData = $this->{queueHead}{prev};

	while($$firstData{permanent})
	{
		# The oldest thing in the queue is permanent.  Put it at the end.
		$this->removeData($firstData);
		$this->queueData($firstData);

		$firstData = $this->{queueHead}{prev};
	}

	$this->removeData($firstData);

	return $$firstData{item};
}

=cut

=head2 C<getSize>

Get the size of the queue

Returns the number of items in the queue

=cut

sub getSize
{
	my ($this) = @_;

	return $this->{queueSize};
}

=cut

=head2 C<removeItem>

Remove an item from the queue.  This should only be used when the associated
item is deleted and should no longer be in the queue.

=over 4

=item * $data

the queue data ref (as returned from queueItem()) to remove

=back

Returns the removed data item.

=cut

sub removeItem
{
	my ($this, $data) = @_;

	return undef if(not defined $data);

	$this->removeData($data);
	return $$data{item};
}

=cut

=head2 C<listItems>

Return an array of each item in the queue.  Useful for checking what's in there
(mostly for debugging purposes).

Returns a reference to an array that contains all of the items in the queue

=cut

sub listItems
{
	my ($this) = @_;
	my $data = $this->{queueTail}{next};
	my @list;

	while($$data{item} ne "HEAD")
	{
		push @list, $$data{item};
		$data = $$data{next};
	}

	return \@list;
}


#############################################################################
# "Private" module subroutines - users of this module should never call these
#############################################################################

#############################################################################
sub queueData
{
	my ($this, $data) = @_;

	$this->{numPermanent}++ if($$data{permanent});
	$this->insertData($data, $this->{queueTail});
}


#############################################################################
sub insertData
{
	my ($this, $data, $before) = @_;
	my $after = $$before{next};

	$$data{next} = $after;
	$$data{prev} = $before;
	
	$$before{next} = $data;
	$$after{prev} = $data;

	# Increment the queue size since we just added one
	$this->{queueSize}++;
}


#############################################################################
sub removeData
{
	my ($this, $data) = @_;
	my $next = $$data{next};
	my $prev = $$data{prev};

	return if($this->{queueSize} == 0);
	return if($next == 0 && $prev == 0);  # It has already been removed

	# Remove us from the list
	$$next{prev} = $prev;
	$$prev{next} = $next;
	
	# Null out our next and prev pointers
	$$data{next} = 0;
	$$data{prev} = 0;
	
	$this->{numPermanent}-- if($$data{permanent});
	$this->{queueSize}--;
}

=cut

=begin private

=head2 C<createQueueData>

This creates a link, in our linked list.

=end private

=cut

sub createQueueData
{
	my ($this, $item, $permanent) = @_;
	my $data;
	
	$permanent ||= 0;
	$data = { "item" => $item, "next" => 0, "prev" => 0,
		"permanent" => $permanent};

	return $data;
}


#############################################################################
#	End of Package Everything::CacheQueue
#############################################################################

1;
