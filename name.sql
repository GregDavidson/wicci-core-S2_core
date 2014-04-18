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

-- * name_refs/_rows

SELECT create_name_ref_schema('name');

-- this will need to change if we're going to use it with
-- name-types other than name_refs!!!
CREATE OR REPLACE
FUNCTION ref_name_search_op(refs, name_refs) RETURNS refs
AS 'spx.so','call_scalar_method' LANGUAGE c;

SELECT create_name_ref_env_value_func('name');

-- CREATE OR REPLACE
-- FUNCTION env_name_value(env_refs, name_refs) RETURNS refs AS $$
-- 	SELECT env_key_value($1, $2)
-- $$ LANGUAGE sql;

SELECT create_name_ref_env_obj_value_func('name');

-- CREATE OR REPLACE
-- FUNCTION env_obj_name_value(env_refs, refs, name_refs)
-- RETURNS refs AS $$
-- 	SELECT env_obj_feature_value($1, $2, $3)
-- $$ LANGUAGE sql;

-- **

DROP OPERATOR IF EXISTS ^ (env_refs, name_refs) CASCADE;

CREATE OPERATOR ^ (
		leftarg = env_refs,
		rightarg = name_refs,
		procedure = env_name_value
);

-- **

CREATE OR REPLACE
FUNCTION env_name_pair(env_refs, name_refs)
RETURNS key_value_pairs AS $$
	SELECT env_key_pair($1, $2)
$$ LANGUAGE SQL;

CREATE OR REPLACE
FUNCTION trial_name_value_pair(name_refs, refs)
RETURNS key_value_pairs AS $$
	SELECT trial_key_value_pair($1, $2)
$$ LANGUAGE SQL IMMUTABLE;

CREATE OR REPLACE
FUNCTION name_value_pair(name_refs, refs)
RETURNS key_value_pairs AS $$
	SELECT key_value_pair($1, $2)
$$ LANGUAGE SQL IMMUTABLE;


-- * metacode for fixed-name --> fixed-type pairs

-- make the lookup function STABLE
-- as environments should NOT change
-- during a transaction!!
CREATE OR REPLACE
FUNCTION create_env_name_type_func(text, regtype)
RETURNS regprocedure AS $$
	SELECT get_name($1); -- key & func name!
	SELECT create_func(
		_name := $1, _args := ARRAY[meta_arg('env_refs')],
		_returns := $2, _lang := 'meta__sql',
		_strict := 'meta__strict2', _stability := 'meta__stable',
		_body := 'SELECT ' || call_text(
				try_find_func_name(_type := $2),
				call_text(
					env_value_func_name(_type := 'name_refs'),
					'$1', quote_literal($1)
				)
		),
		_ := 'lookup value associated with name ' || $1 ||
		' in given environment and return as value of type ' || $2,
		_by := 'create_env_name_type_func(text, regtype)'
	);
	SELECT create_func(
		_name := $1, _args := ARRAY[meta_arg('env_refs'),meta_arg($2)],
		_returns := 'env_pair_stati', _lang := 'meta__sql',
		_strict := 'meta__strict2', _stability := 'meta__volatile',
		_body :=E'\tSELECT ' || call_text(
				'env_add_binding', '$1', quote_literal($1) || '::name_refs', '$2'
		),
		_ := 'lookup value associated with name ' || $1 ||
		' in given environment and return as value of type ' || $2,
		_by := 'create_env_name_type_func(text, regtype)'
	)
$$ LANGUAGE sql;
