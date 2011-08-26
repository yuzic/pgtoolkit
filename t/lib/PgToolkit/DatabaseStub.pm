package PgToolkit::DatabaseStub;

use parent qw(PgToolkit::Database);

use strict;
use warnings;

use Test::MockObject;
use Test::More;

use Test::Exception;

sub init {
	my $self = shift;

	$self->SUPER::init(@_);

	$self->{'mock'} = Test::MockObject->new();

	$self->{'mock'}->mock(
		'-is_called',
		sub {
			my ($self, $pos, $name, %substitution_hash) = @_;

			if (defined $name) {
				my $sql_pattern = $self->{'data_hash'}->{$name}->
				{'sql_pattern'};
				for my $item (keys %substitution_hash) {
					$sql_pattern =~ s/<$item>/$substitution_hash{$item}/g;
				}

				is($self->call_pos($pos), 'execute');
				like({$self, $self->call_args($pos)}->{'sql'},
					 qr/$sql_pattern/);
			} else {
				is($self->call_pos($pos), undef);
			}

			return;
		});

	$self->{'mock'}->mock(
		'execute',
		sub {
			my ($self, %arg_hash) = @_;

			my $result;
			for my $data (values %{$self->{'data_hash'}}) {
				my $sql_pattern = $data->{'sql_pattern'};
				$sql_pattern =~ s/<[a-z_]+>/.*/g;
				if ($arg_hash{'sql'} =~ qr/$sql_pattern/) {
					if (exists $data->{'row_list'}) {
						$result = $data->{'row_list'};
					} else {
						$result = shift @{$data->{'row_list_sequence'}};
						if (not defined $result) {
							die("Not enough results for: \n".
								$arg_hash{'sql'});
						}
					}
					last;
				}
			}

			if (not defined $result) {
				die("Can not find an appropriate SQL pattern for: \n".
					$arg_hash{'sql'});
			}

			if (ref($result) ne 'ARRAY') {
				die($result);
			}

			return $result;
		});

	$self->{'mock'}->{'data_hash'} = {
		'has_special_triggers' => {
			'sql_pattern' => (
				qr/SELECT count\(1\) FROM pg_trigger.+/s.
				qr/tgrelid = '"schema"\."table"'::regclass/),
			'row_list' => [[0]]},
		'get_statistics' => {
			'sql_pattern' => (
				qr/SELECT\s+page_count, total_page_count.+/s.
				qr/pg_class\.oid = '"schema"\."table"'::regclass/),
			'row_list_sequence' => [
				[[100, 120, undef, undef, undef]],
				[[100, 120, 85, 15, 5000]],
				[[90, 108, 85, 5, 1250]],
				[[85, 102, 85, 0, 0]]]},
		'get_column' => {
			'sql_pattern' => (
				qr/SELECT attname.+attrelid = '"schema"\."table"'::regclass.+/s.
				qr/indrelid = '"schema"\."table"'::regclass/),
			'row_list' => [['column']]},
		'clean_pages' => {
			'sql_pattern' => (
				qr/SELECT _clean_pages\(.+'"schema"."table"', '"column"'.+/s.
				qr/<to_page>, 5/),
			'row_list_sequence' => [
				[[94]], [[89]], [[84]],
				'No more free space left in the table']},
		'vacuum' => {
			'sql_pattern' => qr/VACUUM "schema"\."table"/,
			'row_list' => [[undef]]},
		'vacuum_analyze' => {
			'sql_pattern' => qr/VACUUM ANALYZE "schema"\."table"/,
			'row_list' => [[undef]]},
		'reindex_select' => {
			'sql_pattern' => (
				qr/SELECT indexname, tablespace, indexdef.+/s.
				qr/schemaname = 'schema'.+tablename = 'table'/s),
			'row_list' => [
				['i_table__idx1', undef,
				 'CREATE INDEX i_table__idx1 ON schema.table '.
				 'USING btree (column1)'],
				['i_table__idx2', 'tablespace',
				 'CREATE INDEX i_table__idx2 ON schema.table '.
				 'USING btree (column2) WHERE column2 = 1']]},
		'reindex_create1' => {
			'sql_pattern' =>
				qr/CREATE INDEX CONCURRENTLY i_compactor_$$ ON schema\.table /.
				qr/USING btree \(column1\)/,
			'row_list' => []},
		'reindex_create2' => {
			'sql_pattern' =>
				qr/CREATE INDEX CONCURRENTLY i_compactor_$$ ON schema\.table /.
				qr/USING btree \(column2\) TABLESPACE tablespace /.
				qr/WHERE column2 = 1/,
			'row_list' => []},
		'reindex_drop1' => {
			'sql_pattern' => qr/DROP INDEX "schema"\."i_table__idx1"/,
			'row_list' => []},
		'reindex_drop2' => {
			'sql_pattern' => qr/DROP INDEX "schema"\."i_table__idx2"/,
			'row_list' => []},
		'reindex_alter1' => {
			'sql_pattern' =>
				qr/ALTER INDEX "schema"\.i_compactor_$$ /.
				qr/RENAME TO "i_table__idx1"/,
			'row_list' => []},
		'reindex_alter2' => {
			'sql_pattern' =>
				qr/ALTER INDEX "schema"\.i_compactor_$$ /.
				qr/RENAME TO "i_table__idx2"/,
			'row_list' => []},
		'get_table_name_list' => {
			'sql_pattern' =>
				qr/SELECT tablename FROM pg_tables\n/.
				qr/WHERE schemaname = 'schema\d?'/,
			'row_list' => [['table1'],['table2']]},
		'has_schema' => {
			'sql_pattern' =>
				qr/SELECT count\(1\) FROM pg_namespace /.
				qr/WHERE nspname = 'schema\d?'/,
			'row_list' => [[1]]},
		'get_schema_name_list' => {
			'sql_pattern' =>
				qr/SELECT nspname FROM pg_namespace/,
			'row_list' => [['schema1'],['schema2']]},
		'create_clean_pages' => {
			'sql_pattern' =>
				qr/CREATE OR REPLACE FUNCTION _clean_pages/,
			'row_list' => []},
		'drop_clean_pages' => {
			'sql_pattern' =>
				qr/DROP FUNCTION _clean_pages/,
			'row_list' => []},
		'get_dbname_list' => {
			'sql_pattern' =>
				qr/SELECT datname FROM pg_database/,
			'row_list' => [['dbname1'],['dbname2']]},
		'has_pgstattuple' => {
			'sql_pattern' =>
				qr/SELECT sign\(count\(1\)\) FROM pg_proc /.
				qr/WHERE proname = 'pgstattuple'/,
			'row_list' => [[0]]},
		'get_pgstattuple_statistics' => {
			'sql_pattern' => (
				qr/free_percent, free_space.+/s.
				qr/FROM pgstattuple\('"schema"\."table"'\)/),
			'row_list_sequence' => [
				[[100, 120, undef, undef, undef]],
				[[100, 120, 85, 15, 5000]],
				[[90, 108, 85, 5, 1250]],
				[[85, 102, 85, 0, 0]]]}};

	return;
}

sub execute {
	return shift->{'mock'}->execute(@_);
}

1;