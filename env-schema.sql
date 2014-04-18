-- * Header  -*-Mode: sql;-*-
\ir settings.sql
SELECT set_file('env-schema.sql', '$Id');

--	Wicci Project
--	env_ref (Context Environment) Schema

-- ** Copyright

--	Copyright (c) 2005-2012, J. Greg Davidson.
--	You may use this file under the terms of the
--	GNU AFFERO GENERAL PUBLIC LICENSE 3.0
--	as specified in the file LICENSE.md included with this distribution.
--	All other use requires my permission in writing.

-- * env_refs/_rows

SELECT create_ref_type('env_refs');

DROP TYPE IF EXISTS stati CASCADE;

CREATE TYPE stati AS ENUM (
    'failed status',
    'found status',
    'inserted status',
    'updated status',						-- illegal for env_refs!!
    'inherited status'					-- possible for env_refs!!
);
COMMENT ON TYPE stati IS
'The possible stati when performing an operation
on a relation.';

CREATE OR REPLACE
FUNCTION status_text(stati) RETURNS text AS $$
	SELECT substring($1::text FROM '[^ ]*')
$$ LANGUAGE SQL IMMUTABLE;

DROP TYPE IF EXISTS env_stati CASCADE;

CREATE TYPE env_stati AS (
	env env_refs,
	status stati
);

CREATE OR REPLACE
FUNCTION try_env_status(env_refs, stati) RETURNS env_stati AS $$
	SELECT ($1, $2)::env_stati
	WHERE $2 <> 'updated status'
$$ LANGUAGE SQL STRICT IMMUTABLE;

CREATE OR REPLACE
FUNCTION env_status(env_refs, stati) RETURNS env_stati AS $$
	SELECT non_null(
		try_env_status($1, $2), 'env_status(env_refs, stati)'
	)
$$ LANGUAGE SQL IMMUTABLE;

-- ** TYPE env_pair_stati(env, key_, value_, status)

DROP TYPE IF EXISTS key_value_pairs CASCADE;

CREATE TYPE key_value_pairs AS (
	key_  refs,
	value_ refs
);
COMMENT ON TYPE key_value_pairs IS
'represents a single key->value mapping suitable
for associating with an env_ref.';

CREATE OR REPLACE
FUNCTION trial_key_value_pair(refs, refs) RETURNS key_value_pairs AS $$
	SELECT ($1, $2)::key_value_pairs WHERE $1 IS NOT NULL
$$ LANGUAGE SQL IMMUTABLE;

CREATE OR REPLACE
FUNCTION key_value_pair(refs, refs) RETURNS key_value_pairs AS $$
	SELECT non_null(
		trial_key_value_pair($1, $2), 'key_value_pair(refs, refs)'
	)
$$ LANGUAGE SQL IMMUTABLE;

CREATE OR REPLACE
FUNCTION no_key_value_pairs() RETURNS key_value_pairs[] AS $$
	SELECT '{}'::key_value_pairs[]
$$ LANGUAGE SQL IMMUTABLE;

DROP TYPE IF EXISTS env_pair_stati CASCADE;

CREATE TYPE env_pair_stati AS (
	env env_refs,
	key_ refs,
	value_ refs,
	status stati
);

CREATE OR REPLACE
FUNCTION stati_env(env_pair_stati) RETURNS env_refs AS $$
	SELECT ($1).env
$$ LANGUAGE SQL STRICT IMMUTABLE;

CREATE OR REPLACE
FUNCTION try_env_pair_status(env_refs, refs, refs, stati)
RETURNS env_pair_stati AS $$
	SELECT ($1, $2, $3, $4)::env_pair_stati
$$ LANGUAGE SQL STRICT IMMUTABLE;

CREATE OR REPLACE
FUNCTION env_pair_status(env_refs, refs, refs, stati)
RETURNS env_pair_stati AS $$
	SELECT non_null(
		try_env_pair_status($1, $2, $3, $4),
		'env_pair_status(env_refs, refs, refs, stati)'
	)
$$ LANGUAGE SQL IMMUTABLE;

-- ** TYPE env_triple_stati(env, object_, feature_, value_, status)

DROP TYPE IF EXISTS env_triple CASCADE;

CREATE TYPE env_triple AS (
	object_  refs,
	feature_  refs,
	value_ refs
);
COMMENT ON TYPE env_triple IS
'represents a single key->value mapping suitable
for associating with an env_ref.';

CREATE OR REPLACE
FUNCTION try_env_triple(refs, refs, refs)
RETURNS env_triple AS $$
	SELECT ($1, $2, $3)::env_triple
$$ LANGUAGE SQL STRICT IMMUTABLE;

CREATE OR REPLACE
FUNCTION env_triple(refs, refs, refs) RETURNS env_triple AS $$
	SELECT non_null(
		try_env_triple($1, $2, $3), 'env_triple(refs, refs, refs)'
	)
$$ LANGUAGE SQL IMMUTABLE;

DROP TYPE IF EXISTS env_triple_stati CASCADE;

CREATE TYPE env_triple_stati AS (
	env env_refs,
	object_ refs,
	feature_ refs,
	value_ refs,
	status stati
);

CREATE OR REPLACE
FUNCTION try_env_triple_status(env_refs, refs, refs, refs, stati)
RETURNS env_triple_stati AS $$
	SELECT ($1, $2, $3, $4, $5)::env_triple_stati
$$ LANGUAGE SQL STRICT IMMUTABLE;

CREATE OR REPLACE
FUNCTION env_triple_status(env_refs, refs, refs, refs, stati)
RETURNS env_triple_stati AS $$
	SELECT non_null(
		try_env_triple_status($1, $2, $3, $4, $5),
		'env_triple_status(env_refs, refs, refs, refs, stati)'
	)
$$ LANGUAGE SQL IMMUTABLE;

-- * define tables

CREATE TABLE IF NOT EXISTS env_rows (
	ref env_refs PRIMARY KEY,
	base_refs env_refs[] NOT NULL DEFAULT('{}'::env_refs[])
	-- makes a heterarchy
	-- note that search_ids[1] == id
	-- if id is positive,
	--	all base_ids and all search_ids must have lesser values
	-- if id is negative,
	--	all base_ids and all search_ids must have greater values
	-- id=0 forbidden
	-- No inheritance allowed for id=1 or id=-1
);
COMMENT ON TABLE env_rows IS
'represents a set of refs->refs and (refs ,refs feature)->refs
mappings; may participate in multiple inheritance';

SELECT create_handles_for('env_rows');
SELECT declare_ref_class_with_funcs('env_rows');
SELECT create_simple_serial('env_rows', _min := 2);

INSERT INTO env_rows(ref) VALUES( env_nil() );

-- ** user env_rows have positive ids

CREATE OR REPLACE
FUNCTION next_user_env() RETURNS env_refs AS $$
	SELECT next_env_ref()
$$ LANGUAGE sql;

CREATE OR REPLACE
FUNCTION user_base_env() RETURNS env_refs AS $$
	SELECT unchecked_env_from_id( 1 )
$$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION user_base_env()
IS 'The base of the user env_rows';

INSERT INTO env_rows(ref) VALUES ( user_base_env() );

-- ** system env_rows have negative ids

DROP SEQUENCE IF EXISTS env_rows_system_id_seq CASCADE;

CREATE SEQUENCE env_rows_system_id_seq
	OWNED BY env_rows.ref
	INCREMENT BY -1 START -2
	MAXVALUE -2 MINVALUE :RefIdMin CYCLE;

CREATE OR REPLACE
FUNCTION next_system_env() RETURNS env_refs AS $$
	SELECT unchecked_env_from_id( nextval('env_rows_system_id_seq')::ref_ids )
$$ LANGUAGE sql;

CREATE OR REPLACE
FUNCTION system_base_env() RETURNS env_refs AS $$
	SELECT unchecked_env_from_id( -1 )
$$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION system_base_env()
IS 'The base of the user env_rows';

INSERT INTO env_rows(ref) VALUES ( system_base_env() );

-- ** fingered_env_keys

-- Do we still need fingered_env_keys ???
-- Can't handles suffice ???
-- tags-search "finger_env" --> wicci-page-code.sql, ...

CREATE TABLE IF NOT EXISTS fingered_env_keys (
	key env_refs  PRIMARY KEY REFERENCES env_rows ON DELETE CASCADE
);
COMMENT ON TABLE fingered_env_keys IS
'holds temporary env_rows which are to be deleted at the end of a
transaction, possibly after being inspected - this system is
currently only used for debugging purposes ';

-- * context environment schemas

-- ** TABLE env_bindings(env_refs, key_, value_)

CREATE TABLE IF NOT EXISTS env_bindings (
	env_  env_refs REFERENCES env_rows ON DELETE CASCADE
		CHECK(non_nil(env_)),
	key_  refs,
	UNIQUE(env_, key_),
	value_ refs
);
COMMENT ON TABLE env_bindings IS
'represents individual key->value mappings within an env_ref
Updates are prohibited.  Deletes should not happen either,
except when the associated env_ref is deleted!!';
COMMENT ON COLUMN env_bindings.value_ IS
'when zero, represents an unbound value and blocks inheritance';

SELECT declare_monotonic('env_bindings');

-- ** TABLE env_associations(env_refs, object_, feature_, value_)

CREATE TABLE IF NOT EXISTS env_associations (
	env_  env_refs REFERENCES env_rows ON DELETE CASCADE
		CHECK(non_nil(env_)),
	object_  refs,
	feature_  refs,
	UNIQUE(env_, object_, feature_),
	value_ refs
);
COMMENT ON TABLE env_associations IS
'represents object.feature->value mappings within an env_ref
Updates are prohibited.  Deletes should not happen either,
except when the associated env_ref is deleted!!';

SELECT declare_monotonic('env_associations');
