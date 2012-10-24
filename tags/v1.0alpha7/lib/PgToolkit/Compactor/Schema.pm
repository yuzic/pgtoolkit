package PgToolkit::Compactor::Schema;

use base qw(PgToolkit::Compactor);

use strict;
use warnings;

=head1 NAME

B<PgToolkit::Compactor::Schema> - a schema level processing for bloat reducing.

=head1 SYNOPSIS

	my $schema_compactor = PgToolkit::Compactor::Schema->new(
		database => $database,
		logger => $logger,
		schema_name => $schema_name,
		table_compactor_constructor => $table_compactor_constructor,
		table_name_list => $table_name_list,
		excluded_table_name_list => $excluded_table_name_list,
		pgstattuple_schema_name => 0);

	$schema_compactor->process();

=head1 DESCRIPTION

B<PgToolkit::Compactor::Schema> class is an implementation of a schema level
processing logic for bloat reducing mechanism.

=head3 Constructor arguments

=over 4

=item C<database>

a database object

=item C<logger>

a logger object

=item C<schema_name>

a schema name to process

=item C<table_compactor_constructor>

a table compactor constructor code reference

=item C<table_name_list>

a list of table names to process

=item C<excluded_table_name_list>

a list of table names to exclude from processing

=item C<pgstattuple_schema_name>

shema where pgstattuple is if we should use it to get statistics.

=back

=head3 Throws

=over 4

=item C<SchemaCompactorError>

if there is no such schema.

=back

=cut

sub _init {
	my ($self, %arg_hash) = @_;

	$self->{'_database'} = $arg_hash{'database'};
	$self->{'_schema_name'} = $arg_hash{'schema_name'};

	$self->{'_ident'} = $self->{'_database'}->quote_ident(
		string => $self->{'_schema_name'});

	$self->{'_log_target'} = $self->{'_database'}->quote_ident(
		string => $self->{'_database'}->get_dbname()).', '.$self->{'_ident'};

	if (not $self->_has_schema()) {
		die('SchemaCompactorError There is no schema '.$self->{'_ident'}.'.');
	}

	my $table_name_list = $self->_get_table_name_list(
		table_name_list => $arg_hash{'table_name_list'});

	$self->{'_table_compactor_list'} = [];
	for my $table_name (@{$table_name_list}) {
		if (not grep(
				$_ eq $table_name, @{$arg_hash{'excluded_table_name_list'}}))
		{
			my $table_compactor = $arg_hash{'table_compactor_constructor'}->(
				database => $self->{'_database'},
				schema_name => $self->{'_schema_name'},
				table_name => $table_name,
				pgstattuple_schema_name => (
					$arg_hash{'pgstattuple_schema_name'}));
			push(@{$self->{'_table_compactor_list'}}, $table_compactor);
		}
	}

	return;
}

sub _process {
	my ($self, %arg_hash) = @_;

	$self->{'_logger'}->write(
		message => 'Processing.',
		level => 'info',
		target => $self->{'_log_target'});

	for my $table_compactor (@{$self->{'_table_compactor_list'}}) {
		if (not $table_compactor->is_processed()) {
			$table_compactor->process(attempt => $arg_hash{'attempt'});
		}
	}

	if ($self->is_processed()) {
		$self->{'_logger'}->write(
			message => (
				'Processing complete: size reduced by '.$self->get_size_delta().
				' bytes ('.$self->get_total_size_delta().' bytes including '.
				'toasts and indexes) in total.'),
			level => 'info',
			target => $self->{'_log_target'});
	} else {
		$self->{'_logger'}->write(
			message => (
				'Processing incomplete: '.$self->_incomplete_count().
				' tables left, size reduced by '.$self->get_size_delta().
				' bytes ('.$self->get_total_size_delta().' bytes including '.
				'toasts and indexes) in total.'),
			level => 'warning',
			target => $self->{'_log_target'});
	}

	return;
}

=head1 METHODS

=head2 B<is_processed()>

Tests if the schema is processed.

=head3 Returns

True or false value.

=cut

sub is_processed {
	my $self = shift;

	my $result = 1;
	map(($result &&= $_->is_processed()),
		@{$self->{'_table_compactor_list'}});

	return $result;
}

=head2 B<get_size_delta()>

Returns a size delta in bytes.

=head3 Returns

A number or undef if has not been processed.

=cut

sub get_size_delta {
	my $self = shift;

	my $result = 0;
	map($result += $_->get_size_delta(),
		@{$self->{'_table_compactor_list'}});

	return $result;
}

=head2 B<get_total_size_delta()>

Returns a tital (including toasts and indexes) size delta in bytes.

=head3 Returns

A number or undef if has not been processed.

=cut

sub get_total_size_delta {
	my $self = shift;

	my $result = 0;
	map($result += $_->get_total_size_delta(),
		@{$self->{'_table_compactor_list'}});

	return $result;
}

sub _incomplete_count {
	my $self = shift;

	my $result = 0;
	map(($result += not $_->is_processed()),
		@{$self->{'_table_compactor_list'}});

	return $result;
}

sub _get_table_name_list {
	my ($self, %arg_hash) = @_;

	my $table_name_in = '';
	if (@{$arg_hash{'table_name_list'}}) {
		$table_name_in =
			'AND tablename IN (\''.
			join('\', \'', @{$arg_hash{'table_name_list'}}).
			'\')';
	}

	my $result = $self->_execute_and_log(
		sql => <<SQL
SELECT tablename FROM pg_catalog.pg_tables
WHERE schemaname = '$self->{'_schema_name'}' $table_name_in
ORDER BY
    pg_catalog.pg_relation_size(
        quote_ident(schemaname) || '.' || quote_ident(tablename)),
    tablename
SQL
		);

	return [map($_->[0], @{$result})];
}

sub _has_schema {
	my $self = shift;

	my $result = $self->_execute_and_log(
		sql => <<SQL
SELECT count(1) FROM pg_catalog.pg_namespace
WHERE nspname = '$self->{'_schema_name'}'
SQL
		);

	return $result->[0]->[0];
}

=head1 SEE ALSO

=over 4

=item L<PgToolkit::Class>

=back

=head1 LICENSE AND COPYRIGHT

Copyright 2010-2011 postgresql-consulting.com

TODO Licence boilerplate

=head1 AUTHOR

=over 4

=item L<Sergey Konoplev|mailto:sergey.konoplev@postgresql-consulting.com>

=back

=cut

1;