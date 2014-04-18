-- * Header  -*-Mode: sql;-*-
\ir settings.sql
SELECT set_file('name-env-test-triples.sql', '$Id');

--	Wicci Project TorEnv Association Tests

-- ** Copyright

--	Copyright (c) 2005, J. Greg Davidson.
--	You may use this file under the terms of the
--	GNU AFFERO GENERAL PUBLIC LICENSE 3.0
--	as specified in the file LICENSE.md included with this distribution.
--	All other use requires my permission in writing.

SELECT declare_name('favorite-color');

SELECT env_add_association( user_base_env(),
	'Sher'::name_refs, 'favorite-color'::name_refs, 'pink'::name_refs
);

SELECT env_add_association( user_base_env(),
	'Greg'::name_refs, 'favorite-color'::name_refs, 'green'::name_refs
);

SELECT env_add_association( user_base_env(),
	'Bill'::name_refs, 'favorite-color'::name_refs, 'red'::name_refs
);

SELECT test_func( 
	'env_obj_name_value( env_refs, refs, name_refs )',
	env_obj_name_value(
		'sher+greg', 'Greg'::name_refs, 'favorite-color'
	),
	'green'::name_refs::refs
);

SELECT (env_add_association(
	'sher+greg',  'Greg'::name_refs,
	'favorite-color'::name_refs, ref_nil()
)).status;

SELECT test_func( 
	'env_obj_name_value( env_refs, refs, name_refs )',
	env_obj_name_value(
		user_base_env(), 'Greg'::name_refs, 'favorite-color'
	),
	'green'::name_refs::refs
);

SELECT test_func( 
	'env_obj_name_value( env_refs, refs, name_refs )',
	env_obj_name_value(
		'sher+greg', 'Greg'::name_refs, 'favorite-color'
	) IS NULL
);

TABLE associations_summary;
