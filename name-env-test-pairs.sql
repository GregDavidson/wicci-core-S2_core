-- * Header  -*-Mode: sql;-*-
\ir settings.sql
SELECT set_file('name-env-test-pairs.sql', '$Id');

--	Wicci Project TorEnv Schema

-- ** Copyright

--	Copyright (c) 2005, J. Greg Davidson.
--	You may use this file under the terms of the
--	GNU AFFERO GENERAL PUBLIC LICENSE 3.0
--	as specified in the file LICENSE.md included with this distribution.
--	All other use requires my permission in writing.

-- ** Provides

--	TABLE env_rows
--	TABLE env_derived_bases
--	TABLE env_mappings

-- ** Requires

-- from utilities-schema.sql
--	TABLE names

-- from refs-schema.sql

-- * The code

SELECT test_func(
			 'env_nil()',
	is_nil( env_rows_ref( 'nil', env_nil() ) )
);

SELECT env_rows_ref('user', user_base_env());

SELECT env_rows_ref('system', system_base_env());

SELECT declare_name('user', 'owner');

SELECT env_add_binding(
	user_base_env(), 'user'::name_refs,  'owner'::name_refs
);

SELECT test_func(
			 'env_name_value(env_refs, name_refs)',
			 user_base_env()^'user',
			 'owner'::name_refs::refs
);

-- INSERT INTO env_pairs VALUES (user_base_env(), 'user',  'owner'::name_refs);

SELECT
  declare_name('black', 'white', 'green', 'blue', 'red', 'rose', 'pink');

SELECT
	declare_name('Greg', 'Sher', 'Bill', 'Lynn', 'Stacey', 'fambly');

SELECT create_env_name_type_func('env_color', 'name_refs');

SELECT env_color( user_base_env(), 'black'::name_refs );

SELECT env_add_binding(
	'greg', 'user'::name_refs,  'Greg'::name_refs
);

SELECT env_add_binding(
	'sher', 'user'::name_refs,  'Sher'::name_refs
);

SELECT env_color('sher', 'rose'::name_refs);

SELECT env_add_binding('bill', 'user'::name_refs,  'Bill'::name_refs);

SELECT env_add_binding('sher+greg', 'user'::name_refs, 'fambly'::name_refs);

SELECT (env_color('sher+greg', ref_nil()::unchecked_refs::name_refs)).status;

SELECT test_func(
 'env_name_value(env_refs, name_refs)',
	env_color(user_base_env()),
	'black'::name_refs
);

SELECT test_func(
	'env_name_value(env_refs, name_refs)',
	try_env_color('sher+greg') IS NULL
);

SELECT test_func(
	'env_name_value(env_refs, name_refs)',
	 env_color('sher'),
	'rose'::name_refs
);

SELECT test_func(
 'env_name_value(env_refs, name_refs)',
	env_rows_ref('sher+greg')^'user',
	'fambly'::name_refs::refs
);

TABLE bindings_summary;
