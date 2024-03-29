package PgToolkit::DatabaseChooser;

use strict;
use warnings;

=head1 NAME

B<PgToolkit::DatabaseChooser> - database factory class.

=head1 SYNOPSIS

	my $database = PgToolkit::DatabaseChooser->new(
		constructor_list => [
			sub { SomeDatabase->new(...); },
			sub { AnotherDatabase->new(...); }]);

=head1 DESCRIPTION

B<PgToolkit::DatabaseChooser> a factory class for databases.

It accepts a database constructor list and sequentially tries to run
them. The first successfull adapter is returned.

=head3 Constructor arguments

=over 4

=item C<constructor_list>

=back

=head3 Throws

=over 4

=item C<DatabaseChooserError>

if can not find an adapter.

=back

=cut

sub new {
	my ($class, %arg_hash) = @_;

	my $self;
	my $errors = [];

	for my $constructor (@{$arg_hash{'constructor_list'}}) {
		eval {
			$self = $constructor->();
		};
		if ($@) {
			if ($@ !~ 'DatabaseError') {
				die($@);
			} else {
				push(@{$errors}, $@);
			}
		} else {
			last;
		}
	}

	if (not defined $self) {
		die('DatabaseChooserError Can not find an adapter amongst supported: '.
			"\n".join('', @{$errors}));
	}

	return $self;
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
