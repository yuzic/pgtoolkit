# -*- mode: Perl; -*-
package PgToolkit::DatabasePsqlTest;

use parent qw(PgToolkit::Test);

use strict;
use warnings;

use Test::More;
use Test::Exception;

use PgToolkit::Database::Psql;

sub setup : Test(setup) {
	my $self = shift;

	$self->{'database_constructor'} = sub {
		return PgToolkit::DatabasePsqlTest::DatabasePsql->new(
			path => 'psql', host => 'somehost', port => '5432',
			dbname => 'somedb', user => 'someuser', password => 'somepassword',
			@_);
	}
}

sub test_init : Test(5) {
	my $self = shift;

	my $db = $self->{'database_constructor'}->();

	is($db->get_command(),
	   'PGPASSWORD=somepassword psql -A -t -X -h somehost -p 5432 '.
	   '-d somedb -U someuser -P null="<NULL>"');
	is($db->get_dbname(), 'somedb');

	$db = $self->{'database_constructor'}->(
		path => '/usr/bin/psql', host => 'anotherhost', port => '6432',
		dbname => 'anotherdb', user => 'anotheruser',
		password => 'anotherpassword');

	is($db->get_command(),
	   'PGPASSWORD=anotherpassword /usr/bin/psql -A -t -X -h anotherhost '.
	   '-p 6432 -d anotherdb -U anotheruser -P null="<NULL>"');
	is($db->get_dbname(), 'anotherdb');

	is(PgToolkit::DatabasePsqlTest::DatabasePsql->new()->get_command(),
	   'psql -A -t -X -P null="<NULL>"');
}

sub test_can_not_run : Test {
	my $self = shift;

	throws_ok(
		sub {
			PgToolkit::Database::Psql->new(
				psql => 'psql', host => 'localhost', port => '7432',
				dbname => 'test', user => 'test', password => '');
		},
		qr/DatabaseError Can not run psql\./);
}

sub test_execute : Test(5) {
	my $self = shift;

	my $db = $self->{'database_constructor'}->();

	my $data_hash = {
		'SELECT 1 WHERE false;' => [],
		'SELECT 1;' => [[1]],
		'SELECT NULL;' => [[undef]],
		'SELECT 1, \'text\';' => [[1, 'text']],
		'SELECT column1, column2 '.
		'FROM (VALUES (1, \'text1\'), (2, \'text2\'))_;' => [
			[1, 'text1'], [2, 'text2']]
	};

	for my $sql (keys %{$data_hash}) {
		is_deeply($db->execute(sql => $sql), $data_hash->{$sql});
	}
}

sub test_adapter_name : Test {
	my $self = shift;

	is($self->{'database_constructor'}->()->get_adapter_name(), 'psql');
}

1;

package PgToolkit::DatabasePsqlTest::DatabasePsql;

use parent -norequire, qw(PgToolkit::Database::Psql);

sub get_command {
	my $self  = shift;

	return $self->{'_command'};
}

sub _run_psql {
	my ($self, %arg) = @_;

	my $data_hash = {
		'SELECT 1 WHERE false;' => '',
		'SELECT 1;' => '1',
		'SELECT NULL;' => '<NULL>',
		'SELECT 1, \'text\';' => '1|text',
		'SELECT column1, column2 '.
		'FROM (VALUES (1, \'text1\'), (2, \'text2\'))_;' => "1|text1\n2|text2"
	};

	return $data_hash->{$arg{'sql'}};
}

1;