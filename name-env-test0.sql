-- * Header  -*-Mode: sql;-*-
\ir settings.sql
SELECT set_file('name-env-test0.sql', '$Id');

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


-- select spx_debug_on();

-- select refs_debug_on();

-- select name_refs_debug_on();

-- * The code

-- handles must be unique!
DELETE FROM env_rows_row_handles;

SELECT env_rows_row('test', make_system_env());
SELECT env_rows_row('greg', make_user_env(user_base_env()));
SELECT env_rows_row('sher', make_user_env(user_base_env()));
SELECT env_rows_row('bill', make_user_env(user_base_env()));
SELECT env_rows_row('cat', make_user_env(user_base_env()));

SELECT env_rows_row( 'sher+greg',
	make_user_env( 'greg', 'sher' )
);

SELECT env_rows_row( 'branting',
	make_user_env(
		'greg',
		'sher',
		'bill',
		'cat'
	)
);

TABLE env_view;
