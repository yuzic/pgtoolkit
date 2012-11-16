# -*- mode: Perl; -*-
package PgToolkit::DatabaseTest;

use base qw(PgToolkit::Test);

use strict;
use warnings;

use Test::More;
use Test::Exception;

use PgToolkit::DatabaseStub;

sub setup : Test(setup) {
	my $self = shift;

	$self->{'database_constructor'} = sub {
		return PgToolkit::DatabaseTest::DatabaseStub->new(
			dbname => 'somedb',
			@_);
	};
}

sub test_init : Test(2) {
	my $self = shift;

	is($self->{'database_constructor'}->()->get_dbname(), 'somedb');
	is(
		$self->{'database_constructor'}->(dbname => 'anotherdb')->get_dbname(),
		'anotherdb');
}

sub test_quote_ident_nothing_to_ident : Test(2) {
	my $self = shift;

	throws_ok(
		sub { $self->{'database_constructor'}->()->quote_ident(string => ''); },
		qr/DatabaseError Nothing to ident\./);
	throws_ok(
		sub {
			$self->{'database_constructor'}->()->quote_ident(
				string => undef);
		},
		qr/DatabaseError Nothing to ident\./);
}

sub test_escaped_dbname : Test(2) {
	my $self = shift;

	is(
		$self->{'database_constructor'}->(dbname => 'some db')
		->get_escaped_dbname(),
		'some\ db');
	is(
		$self->{'database_constructor'}->(dbname => 'another&db')
		->get_escaped_dbname(),
		'another\&db');
}

sub test_execute_calculates_duration : Test(2) {
	my $self = shift;

	my $database = $self->{'database_constructor'}->();

	$database->execute(sql => 'SELECT something');

	is($database->get_duration(), 1);

	$database->execute(sql => 'SELECT something');

	is($database->get_duration(), 2);

}

1;

package PgToolkit::DatabaseTest::DatabaseStub;

use base qw(PgToolkit::DatabaseStub);

sub init {
	my $self = shift;

	$self->SUPER::init(@_);

	$self->{'mock'} = Test::MockObject->new();
	$self->{'mock'}->set_series('-time', 0, 1, 0, 2, 1 .. 1000);

	return;
}

sub get_escaped_dbname {
	return shift->_get_escaped_dbname();
}

sub _execute {
	return [];
}

sub _time {
	return shift->{'mock'}->time();
}

1;
