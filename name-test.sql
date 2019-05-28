-- * Header  -*-Mode: sql;-*-
\ir settings.sql
SELECT set_file('name_refs-test.sql', '$Id');

-- Right now, 28 May 2019, things fail with this debugging code on!!!
SELECT spx_debug_on();
SELECT refs_debug_on();

SELECT declare_name('hello');

SELECT test_func(
	'get_name(TEXT)',
	ref_text_op(get_name('hello')),
	'hello'
);

SELECT test_func(
	'name_text(name_refs)',
	name_text('hello'::name_refs),
	'hello'
);

SELECT * FROM  name_rows;

SELECT test_func(
			 'name_nil()',
			 ref_id( name_nil() ),
			 0::ref_ids
);
