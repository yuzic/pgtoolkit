package Pc::Compactor::Cluster;

use parent qw(Pc::Class);

use strict;
use warnings;

=head1 NAME

B<Pc::Compactor::Cluster> - a cluster level processing for bloat
reducing.

=head1 SYNOPSIS

	my $cluster_compactor = Pc::Compactor::Cluster->new(
		database_constructor => $database_constructor,
		logger => $logger,
		database_compactor_constructor => $database_compactor_constructor,
		dbname_list => $dbname_list,
		excluded_dbname_list => $excluded_dbname_list,
		max_retry_count => 10);

	$cluster_compactor->process();

=head1 DESCRIPTION

B<Pc::Compactor::Cluster> class is an implementation of a cluster
level processing logic for bloat reducing mechanism.

=head3 Constructor arguments

=over 4

=item C<database_constructor>

a database constructor code reference

=item C<logger>

a logger object

=item C<database_compactor_constructor>

a database compactor constructor code reference

=item C<dbname_list>

a list of database names to process

=item C<excluded_dbname_list>

a list of database names to exclude from processing

=item C<max_retry_count>

a maximum amount of attempts to compact cluster.

=back

=cut

sub init {
	my ($self, %arg_hash) = @_;

	$self->{'_database_constructor'} = $arg_hash{'database_constructor'};
	$self->{'_logger'} = $arg_hash{'logger'};
	$self->{'_max_retry_count'} = $arg_hash{'max_retry_count'};

	$self->{'_logger'}->write(
		message => 'Scanning the cluster.',
		level => 'info');

	my $dbname_list = [];
	if (@{$arg_hash{'dbname_list'}}) {
		$dbname_list = $arg_hash{'dbname_list'};
	} else {
		eval {
			$dbname_list = $self->_get_dbname_list();
		};
		if ($@) {
			$self->{'_logger'}->write(
				message => (
					'Can not get a database name list for the cluster, '.
					'the following error has occured:'."\n".$@),
				level => 'error');
		}
	}

	my %dbname_hash = map(($_ => 1), @{$dbname_list});

	delete @dbname_hash{@{$arg_hash{'excluded_dbname_list'}}};

	$self->{'_database_compactor_list'} = [];
	for my $dbname (sort keys %dbname_hash) {
		my $database_compactor;
		eval {
			$database_compactor = $arg_hash{'database_compactor_constructor'}->(
				database => $self->{'_database_constructor'}->(
					dbname => $dbname));
		};
		if ($@) {
			$self->{'_logger'}->write(
				message => (
					'Can not prepare the "'.$dbname.'" database to '.
					'compacting, the following error has occured:'."\n".$@),
				level => 'error');
		} else {
			push(@{$self->{'_database_compactor_list'}}, $database_compactor);
		}
	}

	return;
}

=head1 METHODS

=head2 B<process()>

Runs a bloat reducing process for the cluster.

=cut

sub process {
	my $self = shift;

	if (@{$self->{'_database_compactor_list'}}) {
		$self->{'_logger'}->write(
			message => 'Processing the cluster.',
			level => 'info');

		my $attempt = 0;
		while (not $self->is_processed() and
			   $attempt <= $self->{'_max_retry_count'}) {

			if ($attempt != 0) {
				$self->{'_logger'}->write(
					message => 'Retrying cluster processing '.$attempt.' time.',
					level => 'notice');
			}

			for my $database_compactor
				(@{$self->{'_database_compactor_list'}})
			{
				if (not $database_compactor->is_processed()) {
					$database_compactor->process();
				}
			}

			$attempt++;
		}

		$self->{'_logger'}->write(
			message => (
				'Finished processing the cluster after '.$attempt.
				' attempt(s).'),
			level => 'info');

		if (not $self->is_processed()) {
			$self->{'_logger'}->write(
				message => 'Processing of the cluster has not been completed.',
				level => 'warning');
		}
	} else {
		$self->{'_logger'}->write(
			message => (
				'Processing of the cluster has been cancelled as no '.
				'databases has been chosen.'),
			level => 'warning');
	}

	return;
}

=head2 B<is_processed()>

Tests if the cluster is processed.

=head3 Returns

True or false value.

=cut

sub is_processed {
	my $self = shift;

	my $result = 1;
	map(($result &&= $_->is_processed()),
		@{$self->{'_database_compactor_list'}});

	return $result;
}

sub _get_dbname_list {
	my $self = shift;

	my $result = $self->{'_database_constructor'}->(dbname => 'postgres')
		->execute(
		sql => <<SQL
SELECT datname FROM pg_database
WHERE datname NOT IN ('postgres', 'template0', 'template1')
ORDER BY 1
SQL
		);

	return [map($_->[0], @{$result})];
}

=head1 SEE ALSO

=over 4

=item L<Pc::Class>

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