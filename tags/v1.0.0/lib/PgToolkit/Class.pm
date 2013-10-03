package PgToolkit::Class;

use strict;
use warnings;

=head1 NAME

B<PgToolkit::Class> - base class.

=head1 SYNOPSIS

	package Foo;

	use base qw(PgToolkit::Class);

	sub init {
		# some initialization
	}

	# some methoods

	1;

=head1 DESCRIPTION

B<PgToolkit::Class> is a base class encapsulating the instantiation
automation stuff.

=head1 METHODS

=head2 B<new()>

A constructor. It can be called both on the class and on the object.

=head3 Arguments

An arbitrary number of arguments which will be later passed to the
C<init()> method.

=head3 Returns

A new instance of the class that the method is being called on.

=cut

sub new {
	my $class = shift;

	my $self  = {};
	bless($self, (ref($class) or $class));

	# Calling init with the same @_
	$self->init(@_);

	return $self;
}

=head2 B<init()>

This method is called after an object has been instantiated using the
C<new()> method, all parameters that have been passed to the
constructor are passed to this method also.

=cut

sub init {
	# The init method stub
}

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2011-2013 Sergey Konoplev, Maxim Boguk

PgToolkit is released under the PostgreSQL License, read COPYRIGHT.md
for additional information.

=head1 AUTHOR

=over 4

=item L<Sergey Konoplev|mailto:gray.ru@gmail.com>

=back

=cut

1;
