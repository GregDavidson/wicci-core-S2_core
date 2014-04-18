-- * Header  -*-Mode: sql;-*-
\ir settings.sql
SELECT set_file('env-code.sql', '$Id');

--	Wicci Project, TorEnv Code

-- ** Copyright

--	Copyright (c) 2005, 2006 J. Greg Davidson.
--	You may use this file under the terms of the
--	GNU AFFERO GENERAL PUBLIC LICENSE 3.0
--	as specified in the file LICENSE.md included with this distribution.
--	All other use requires my permission in writing.

-- ** Provides

--	env_key_value(env_refs, refs) -> refs
--	env_obj_feature_value(env_refs, refs, refs) -> refs

-- ** NOTES

--	WHY: When is_nil(env_refs), env_key_value or env_obj_feature_value return NULL. <-- ???
--	It may be necessary to create an environment with id=0
--	if this special "always empty" environment is statisfy
--	foreign key constraints.

-- * key_value_pairs

CREATE OR REPLACE
FUNCTION key_value_pair_text(key_value_pairs)
RETURNS text AS $$
	SELECT ($1).key_ || ': ' || CASE
		WHEN ($1).value_ IS NULL THEN '(NULL)'
		ELSE show_ref( ($1).value_)
	END
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION debug_enter_pairs(
	regprocedure, key_value_pairs,
	VARIADIC key_value_pairs[] = NULL
) RETURNS regprocedure AS $$
	SELECT CASE
		WHEN debug_on($1)
		THEN raise_debug_enter(
			$1,
			CASE WHEN $3 IS NULL THEN key_value_pair_text($2)
			ELSE E'\n' || key_value_pair_text($2)
			|| array_to_string( ARRAY(
				SELECT E'\t' || key_value_pair_text(x)
				FROM unnest($3) x
			), E'\n' )
			END
		)
	END;
	SELECT $1
$$ LANGUAGE sql;

-- * table env_rows finders

CREATE OR REPLACE
FUNCTION env_from_id(ref_ids) RETURNS env_refs AS $$
	SELECT ref FROM env_rows
	WHERE ref = unchecked_env_from_id($1)
$$ LANGUAGE sql;

CREATE OR REPLACE
FUNCTION try_env(text)  RETURNS env_refs AS $$
	SELECT debug_return( 'try_env(text)', CASE
		WHEN $1 ~ '^env_refs:-?[1-9][0-9]*$' THEN
			env_from_id( substring($1 FROM 7)::ref_ids )
		ELSE
			env_rows_ref($1)
	END )
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION find_env(text) RETURNS env_refs AS $$
	SELECT non_null( try_env($1), 'find_env(text)' )
$$ LANGUAGE sql;

CREATE OR REPLACE
FUNCTION try_env(env_refs, VARIADIC env_refs[]) 
RETURNS env_refs AS $$
	SELECT ref FROM env_rows
	WHERE ref = $1 AND base_refs = $2
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION find_env(env_refs, VARIADIC env_refs[])
RETURNS env_refs AS $$
	SELECT non_null(
		try_env($1, VARIADIC $2), 'find_env(env_refs,env_refs[])'
	)
$$  LANGUAGE sql;

-- * table env_rows constructors

CREATE OR REPLACE
FUNCTION make_env(env_refs, VARIADIC env_refs[] = '{}')
RETURNS env_refs AS $$
	INSERT INTO env_rows(ref, base_refs) VALUES($1, $2);
	SELECT $1
$$ LANGUAGE sql;

CREATE OR REPLACE
FUNCTION make_user_env(VARIADIC env_refs[] = '{}')
RETURNS env_refs AS $$
	SELECT make_env(next_user_env(), VARIADIC $1)
$$ LANGUAGE sql;

CREATE OR REPLACE
FUNCTION make_system_env(VARIADIC env_refs[]='{}')
RETURNS env_refs AS $$
	SELECT make_env(next_system_env(), VARIADIC $1)
$$ LANGUAGE sql;

-- * table env_rows destructor

CREATE OR REPLACE
FUNCTION drop_env(env_refs) RETURNS VOID AS $$
	DECLARE
		derived env_refs := NULL::unchecked_refs;
		-- unchecked_ref_null();
	BEGIN
		SELECT ref INTO derived FROM env_rows
		WHERE $1 = ANY(base_refs) LIMIT 1;
		IF FOUND THEN
			RAISE EXCEPTION 'drop_env(%): % in base refs',
			$1, derived;
		END IF;
		DELETE FROM env_bindings WHERE env_ = $1;
		DELETE FROM env_associations WHERE env_ = $1;
		DELETE FROM env_rows WHERE ref = $1;
	END;
$$  LANGUAGE plpgsql;


-- * env_key_value bindings

-- ** env_key_value bindings search

-- +++ this_env_key(env_refs, refs) -> refs
CREATE OR REPLACE
FUNCTION this_env_key(env_refs, refs) RETURNS refs AS $$
	SELECT value_ FROM env_bindings
	WHERE env_ = $1 AND key_ = $2
$$ LANGUAGE sql STABLE;
COMMENT ON FUNCTION this_env_key(env_refs, refs) IS
'returns the proper value, if any, of the given key in the given
env_ref without inheritance';

-- ++ create_this_env_key_for(env_refs, value_) -> key refs
CREATE OR REPLACE
FUNCTION create_this_env_key_for(env_refs, refs)
RETURNS refs AS $$
	SELECT key_ FROM env_bindings
	WHERE env_ = $1 AND value_ = $2
$$ LANGUAGE sql;
COMMENT ON
FUNCTION create_this_env_key_for(env_refs, refs) IS
'returns the key, if any, of the given value in the given env_ref
without inheritance';

CREATE OR REPLACE
FUNCTION env_key_value(env_refs, refs) RETURNS refs AS $$
--	SELECT unchecked_ref_null()::refs
	SELECT NULL::refs
$$ LANGUAGE sql;
COMMENT ON FUNCTION env_key_value(env_refs, refs) IS
'returns the proper value, if any, of the given key in the given or
inherited env_rows - FORWARD REFERENCE';

-- --- env_refs_key(env_array_refs, key_) -> refs
CREATE OR REPLACE
FUNCTION env_refs_key(env_refs[], refs) RETURNS refs AS $$
	BEGIN
		IF array_lower($1, 1) IS NOT NULL THEN
			FOR i IN array_lower($1, 1) .. array_upper($1, 1) LOOP
				DECLARE
-- value_ refs :=  env_key_value($1[i], $2); -- crashes pgsql!!
--					value_ refs := unchecked_ref_null();
					value_ refs := NULL;
				BEGIN
					SELECT env_key_value($1[i], $2) INTO value_;
					IF NOT nil_tagged(value_) THEN
						RETURN value_;
					END IF;
				END;
			END LOOP;
		END IF;
		RETURN NULL; -- unchecked_ref_null()::refs;
	END
$$ LANGUAGE plpgsql;
COMMENT ON FUNCTION env_refs_key(env_refs[], refs) IS
'returns the first proper value, if any, of the given key in the
given env_rows, depth-first';

CREATE OR REPLACE
FUNCTION env_bases_key(env_refs, refs) RETURNS refs AS $$
	SELECT env_refs_key( base_refs, $2 )
	FROM env_rows WHERE ref = $1
$$ LANGUAGE sql;

-- --- env_key_value(env_refs, key_) -> refs
CREATE OR REPLACE
FUNCTION env_key_value(env_refs, refs) RETURNS refs AS $$
	SELECT CASE WHEN nil_tagged(obj) THEN NULL ELSE obj END
	FROM COALESCE(
		this_env_key($1, $2), env_bases_key( $1, $2 )
	) obj;
$$ LANGUAGE sql;
COMMENT ON FUNCTION env_key_value(env_refs, refs) IS
'returns the proper value, if any, of the given key in the given or
inherited env_rows';

-- ** env_key_value bindings update functions

-- *** Notes

-- See the discussion in env_refs-notes.txt
-- on how these side-effecting functions interact
-- (poorly) with downwards inheritance.

-- Make idempotent!!!
-- Should do nothing if this binding was already findable
-- by env_key_value.
-- Error if incompatible binding in this immediate env_ref
-- ** env_key_set(env_refs, key_, refs) -> BOOLEAN
-- Would it be better to return something else?
CREATE OR REPLACE
FUNCTION env_key_set(env_refs, refs, refs)
RETURNS BOOLEAN AS $$
	BEGIN
		PERFORM env_ FROM env_bindings
			WHERE env_ IS NOT DISTINCT FROM $1
			AND key_ = $2 AND value_ = $3;
		IF FOUND THEN RETURN true; END IF;
		INSERT INTO env_bindings VALUES ($1, $2, $3);
		IF FOUND THEN RETURN true; END IF;
		RAISE NOTICE 'env_key_set(%, %) fails', $1, $2;
		RETURN false;
	END
$$ LANGUAGE plpgsql;
COMMENT ON FUNCTION env_key_set(env_refs, refs, refs) IS
'tries to create the indicated binding through simple
insertion, returns true on success; non-monotonic if there
was an inheritable value for this key; inserting ref_nil()
will mask any inherited value';

-- * env_obj_feature_value associations

-- ** env_obj_feature_value association search

-- +++ this_env_obj_feature(env_refs, object_, feature_) -> refs
CREATE OR REPLACE
FUNCTION this_env_obj_feature(env_refs, refs, refs)
RETURNS refs AS $$
	SELECT value_ FROM env_associations
	WHERE env_ = $1 AND object_ = $2 AND feature_ = $3
$$ LANGUAGE sql STABLE;
COMMENT ON
FUNCTION this_env_obj_feature(env_refs, refs, refs) IS
'returns the proper value, if any, of the given association
without inheritance';

CREATE OR REPLACE
FUNCTION env_obj_feature_value(env_refs, refs, refs)
RETURNS refs AS $$
	SELECT NULL::refs -- unchecked_ref_null()::refs
$$ LANGUAGE sql;

-- --- env_refs_obj_feature(env_array_refs, obj, feature) -> refs
CREATE OR REPLACE
FUNCTION env_refs_obj_feature(env_refs[], refs, refs)
RETURNS refs AS $$
	BEGIN
		IF array_lower($1, 1) IS NOT NULL THEN
			FOR i IN array_lower($1, 1) .. array_upper($1, 1) LOOP
				DECLARE
--	value_ refs := env_obj_feature_value($1[i], $2, $3); --bombs!!
--					value_ refs := unchecked_ref_null();
					value_ refs := NULL;
				BEGIN
					SELECT env_obj_feature_value($1[i], $2, $3) INTO value_;
					IF NOT nil_tagged(value_) THEN
						RETURN value_;
					END IF;
				END;
			END LOOP;
		END IF;
		RETURN NULL; -- unchecked_ref_null()::refs;
	END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE
FUNCTION env_bases_obj_feature(env_refs, refs, refs)
RETURNS refs AS $$
	SELECT env_refs_obj_feature( base_refs, $2, $3 )
	FROM env_rows WHERE ref = $1
$$ LANGUAGE sql;

-- --- env_obj_feature_value(env_refs, obj, feature) -> refs
CREATE OR REPLACE
FUNCTION env_obj_feature_value(env_refs, refs, refs)
RETURNS refs AS $$
	SELECT CASE WHEN nil_tagged(obj) THEN NULL ELSE obj END
	FROM COALESCE(
		this_env_obj_feature($1, $2, $3),
		env_bases_obj_feature( $1, $2, $3 )
	) obj;
$$ LANGUAGE sql;
COMMENT ON
FUNCTION env_obj_feature_value(env_refs, refs, refs) IS
'returns the proper value, if any, of the given association';

-- ** env_obj_feature_value associations update functions

-- *** Notes

-- See the discussion in env_refs-notes.txt
-- on how these side-effecting functions interact
-- (poorly) with downwards inheritance.

-- Make idempotent!!!
-- ** env_obj_feature_set(env_refs, object_, feature_, refs) -> insert_OK BOOLEAN
CREATE OR REPLACE
FUNCTION env_obj_feature_set(env_refs, refs, refs, refs)
RETURNS BOOLEAN AS $$
	BEGIN
		INSERT INTO env_associations VALUES ($1, $2, $3, $4);
		IF FOUND THEN
			RETURN true;
		ELSE
			RAISE NOTICE 'env_obj_feature_set(%, ..., %, ...) fails',$1,$3;
			RETURN false;
		END IF;
	END
$$ LANGUAGE plpgsql;
COMMENT ON
FUNCTION env_obj_feature_set(env_refs, refs, refs, refs) IS
'tries to create the indicated association through simple
insertion, returns true on success; non-monotonic if there
was an inheritable feature for this object and same feature
key; inserting ref_nil() will mask any inherited value';

-- ** User Base TorEnv Convenience Functions

-- ++ base_key(key) -> refs
CREATE OR REPLACE
FUNCTION base_key(refs) RETURNS refs AS $$
	SELECT env_key_value(user_base_env(), $1);
$$ LANGUAGE sql;

-- ++ create_base_key_for(refs) -> key refs
CREATE OR REPLACE
FUNCTION create_base_key_for(refs) RETURNS refs AS $$
	SELECT create_this_env_key_for(user_base_env(), $1)
$$ LANGUAGE sql;

-- ++ base_set(key, new refs) -> BOOLEAN
CREATE OR REPLACE
FUNCTION base_set(key refs, save_value refs)
RETURNS BOOLEAN AS $$
	SELECT env_key_set(user_base_env(), $1, $2)
$$ LANGUAGE sql;

-- ++ base_association(object_, key_) -> refs
CREATE OR REPLACE
FUNCTION base_association(refs, refs) RETURNS refs AS $$
	SELECT env_obj_feature_value(user_base_env(), $1, $2);
$$ LANGUAGE sql;

-- ++ base_association_set(object_, key, refs) -> BOOLEAN
CREATE OR REPLACE
FUNCTION base_association_set(refs, refs, refs)
RETURNS BOOLEAN AS $$
	SELECT env_obj_feature_set(user_base_env(), $1, $2, $3)
$$ LANGUAGE sql;

-- ** System Base TorEnv Convenience Functions

-- ++ system_key(refs) -> refs
CREATE OR REPLACE
FUNCTION system_key(refs) RETURNS refs AS $$
	SELECT env_key_value(system_base_env(), $1)
$$ LANGUAGE sql;

-- ++ create_system_key_for(refs) -> refs
CREATE OR REPLACE
FUNCTION create_system_key_for(refs) RETURNS refs AS $$
	SELECT create_this_env_key_for(system_base_env(), $1)
$$ LANGUAGE sql;

-- ++ system_set(key, new refs) -> BOOLEAN
CREATE OR REPLACE
FUNCTION system_set(key refs, save_value refs)
RETURNS BOOLEAN AS $$
	SELECT env_key_set(system_base_env(), $1, $2)
$$ LANGUAGE sql;

-- ++ system_association(object_, key) -> refs
CREATE OR REPLACE
FUNCTION system_association(refs, refs) RETURNS refs AS $$
	SELECT env_obj_feature_value(system_base_env(), $1, $2);
$$ LANGUAGE sql;

-- ++ system_association_set(object_, key, refs) -> BOOLEAN
CREATE OR REPLACE
FUNCTION system_association_set(refs, refs, refs)
RETURNS BOOLEAN AS $$
	SELECT env_obj_feature_set(system_base_env(), $1, $2, $3)
$$ LANGUAGE sql;

-- ** basic ops with env_refs arguments

CREATE OR REPLACE FUNCTION finger_env_return_value(
	env_refs, ANYELEMENT
) RETURNS ANYELEMENT AS $$
	SELECT debug_enter(
		'finger_env_return_value(env_refs, ANYELEMENT)',
		$1, 'env_refs'
	);
	INSERT INTO fingered_env_keys(key) VALUES($1);
	SELECT $2
$$ LANGUAGE SQL;

CREATE OR REPLACE
FUNCTION delete_fingered_env_keys() RETURNS void AS $$
DECLARE
	the_ref env_refs := NULL; -- unchecked_ref_null();
BEGIN
	FOR the_ref IN SELECT ref FROM fingered_env_keys LOOP
		DELETE FROM fingered_env_keys WHERE key = the_ref;
		PERFORM drop_env(the_ref);
	END LOOP;
END  
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION drop_env_give_value(
	env_refs, ANYELEMENT
) RETURNS ANYELEMENT AS $$
	SELECT drop_env($1);
	SELECT $2
$$ LANGUAGE SQL;

COMMENT ON FUNCTION
drop_env_give_value(env_refs, ANYELEMENT)
IS 'deletes the environment given as the first argument
and then returns the value given as the second; the idea
is that the environment was used in the construction of
the value and is no longer necessary';

-- * env_refs binding constructors

-- just replaced = with IS NOT DISTINCT FROM
-- but = used to work --- any idea why???
CREATE OR REPLACE
FUNCTION env_add_binding(env_refs, refs, refs)
RETURNS env_pair_stati AS $$
	SELECT COALESCE(
		( SELECT try_env_pair_status($1, $2, $3, 'found status')
			WHERE this_env_key($1, $2) IS NOT DISTINCT FROM $3
		),
		( SELECT try_env_pair_status($1, $2, $3, 'inherited status')
			WHERE env_key_value($1, $2) IS NOT DISTINCT FROM $3
		),
		( SELECT try_env_pair_status( $1, $2, $3, CASE status
				WHEN false THEN 'failed status'::stati
				WHEN true THEN 'inserted status'::stati
		END ) FROM env_key_set($1, $2, $3) status )
	) WHERE non_nil($1)
$$  LANGUAGE sql;

-- CREATE OR REPLACE
-- FUNCTION env_chain_binding(env_pair_stati, refs, refs)
-- RETURNS env_pair_stati AS $$
-- 	SELECT env_add_binding( ($1).env, $2, $3 )
-- $$  LANGUAGE sql;

-- COMMENT ON FUNCTION 
-- env_chain_binding(env_pair_stati, refs, refs)
-- IS 'Allows nesting calls to bind multiple values';

-- -- --- env_add_bindings(env_refs, [key, value, ...]) -> env_refs
-- CREATE OR REPLACE FUNCTION env_add_bindings(
-- 	env_refs, VARIADIC key_value_pairs[]
-- ) RETURNS env_refs AS $$
-- 	SELECT env_add_binding($1, (pair).key_, (pair).value_)
-- 	FROM unnest($2) pair
-- 	WHERE pair IS NOT NULL AND (pair).value_ IS NOT NULL;
-- 	SELECT $1
-- $$ LANGUAGE sql;

-- * env_refs association constructors

-- triggers a warning when ref is ref_nil
-- is there a better way to check/set an erase?
CREATE OR REPLACE
FUNCTION env_add_association(env_refs, refs, refs, refs)
RETURNS env_triple_stati AS $$
	SELECT COALESCE(
		( SELECT try_env_triple_status($1, $2, $3, $4, 'found status')
			WHERE this_env_obj_feature($1, $2, $3) IS NOT DISTINCT FROM $4
		),
		( SELECT try_env_triple_status($1, $2, $3, $4, 'inherited status')
			WHERE env_obj_feature_value($1, $2, $3)
			IS NOT DISTINCT FROM $4
		),
		( SELECT try_env_triple_status( $1, $2, $3, $4, CASE status
			WHEN false THEN 'failed status'::stati
			WHEN true THEN 'inserted status'::stati
		END ) FROM env_obj_feature_set($1, $2, $3, $4) status )
	) WHERE non_nil($1)
$$  LANGUAGE sql;

-- * env_refs class declarations

CREATE OR REPLACE
FUNCTION try_handle_from_env(env_refs)
RETURNS handles AS $$
	SELECT handle FROM env_rows_row_handles WHERE ref = $1
$$ LANGUAGE sql;

CREATE OR REPLACE
FUNCTION env_text(env_refs) RETURNS text AS $$
	SELECT CASE
		WHEN $1 = system_base_env() THEN '<<system>>'
		WHEN $1 = user_base_env() THEN '<<user>>'
		ELSE '<' || COALESCE(
			try_handle_from_env($1)::text,
			ref_id($1)::text
		) || '>'
	END
$$ LANGUAGE sql;

SELECT type_class_in('env_refs', 'env_rows', 'find_env(text)');

SELECT type_class_op_method(
	'env_refs', 'env_rows', 'ref_text_op(refs)', 'env_text(env_refs)'
);


-- * Nice VIEWs

CREATE OR REPLACE
VIEW named_env_env_view AS
	SELECT
		ref as "env_"
	FROM env_rows_row_handles;

CREATE OR REPLACE
VIEW named_env_ref_view AS
	SELECT
		key as "env_"
	FROM ref_keys_row_handles;

CREATE OR REPLACE
VIEW named_env_view AS
		SELECT * FROM named_env_env_view
	UNION
		SELECT * FROM named_env_ref_view;

CREATE OR REPLACE
VIEW env_view AS
	SELECT
		c.ref as "env_",
		c.base_refs as "bases"
	FROM env_rows c
	LEFT OUTER JOIN named_env_view cn ON (c.ref = cn.env_)
	WHERE non_nil(c.ref);

CREATE OR REPLACE
VIEW binding_counts AS
	SELECT e.ref, count(p.env_) AS pairs
	FROM env_rows e
	LEFT OUTER JOIN env_bindings p ON (e.ref = p.env_)
	WHERE NOT nil_tagged(p.value_)
	GROUP BY e.ref;

CREATE OR REPLACE
VIEW association_counts AS
	SELECT e.ref AS "env_", count(t.env_) AS triples
	FROM env_rows e
	LEFT OUTER JOIN env_associations t ON (e.ref = t.env_)
	WHERE NOT nil_tagged(t.value_)
	GROUP BY e.ref;

-- ** VIEW env_summary(env_refs, #pairs, #triples, []bases, key)
CREATE OR REPLACE
VIEW env_summary AS
	SELECT e.env_, p.pairs, t.triples, e.bases
	FROM env_view e
	LEFT OUTER JOIN binding_counts p ON (e.env_ = p.ref)
	LEFT OUTER JOIN association_counts t ON (e.env_ = t.env_);

-- ** VIEW bindings_summary(env_refs, key_, value_)
CREATE OR REPLACE
VIEW bindings_summary AS
	SELECT env_ AS env_, key_, value_
	FROM env_bindings
	WHERE NOT nil_tagged(value_)
	ORDER BY env_::text, key_::text;

-- ** VIEW associations_summary(env_refs, object_, feature_, value_)
CREATE OR REPLACE
VIEW associations_summary AS
	SELECT env_ AS env_, object_ AS object, feature_, value_
	FROM env_associations
	WHERE NOT nil_tagged(value_)
	ORDER BY env_::text, feature_::text;

CREATE OR REPLACE
FUNCTION env_refs_ready() RETURNS void AS $$
BEGIN
	PERFORM refs_ready();
-- Check sufficient elements of the TorEnv
-- dependency tree that we can be assured that
-- all of its modules have been loaded.
-- 	PERFORM require_module('s2_core.env-code');
--  PERFORM env_init();
END
$$ LANGUAGE plpgsql;
COMMENT ON FUNCTION env_refs_ready() IS '
	Ensure that all modules of the env_ref schema
	are present and initialized.
';

CREATE OR REPLACE
FUNCTION ensure_schema_ready()
RETURNS regprocedure AS $$
	SELECT env_refs_ready();
	SELECT 'env_refs_ready()'::regprocedure
$$ LANGUAGE sql;

-- * Some nice syntactic sugar

/*
DROP OPERATOR IF EXISTS ^ (env_refs, refs) CASCADE;

CREATE OPERATOR ^ (
		leftarg = env_refs,
		rightarg = refs,
		procedure = env_key_value
);
*/

CREATE OR REPLACE
FUNCTION env_key_pair(env_refs, refs)
RETURNS key_value_pairs AS $$
	SELECT key_value_pair($2, env_key_value($1, $2))
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION create_name_ref_env_value_func(
	_stub text=NULL, _type regtype=NULL, _class regclass=NULL,
	_name text=NULL
) RETURNS regprocedure AS $_$
	SELECT create_func(
		_name := env_value_func_name($1, $2, $3, $4),
		_args := ARRAY[meta_arg('env_refs'), meta_arg(_type)],
		_returns := 'refs',
		_strict := 'meta__non_strict',
		_stability := 'meta__stable',
		_body := $$SELECT env_key_value($1,$2)$$,
		_ := 'wrap env_key_value',
		_by := 'create_name_ref_env_value_func(
				text, regtype, regclass, text
		)'
	) FROM infer_type($1, $2, $3) _type
$_$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION create_name_ref_env_obj_value_func(
	_stub text=NULL, _type regtype=NULL, _class regclass=NULL,
	_name text=NULL
) RETURNS regprocedure AS $_$
	SELECT create_func(
		_name := env_obj_value_func_name($1, $2, $3, $4),
		_args := ARRAY[
			meta_arg('env_refs'), meta_arg('refs'), meta_arg(_type)
		],
		_returns := 'refs',
		_strict := 'meta__non_strict',
		_stability := 'meta__stable',
		_body := $$SELECT env_obj_feature_value($1,$2, $3)$$,
		_ := 'wrap env_obj_feature_value',
		_by := 'create_name_ref_env_obj_value_func(
				text, regtype, regclass, text
		)'
	) FROM infer_type($1, $2, $3) _type
$_$ LANGUAGE sql;

-- * removal of references

CREATE OR REPLACE
FUNCTION env_drop_ref(refs) RETURNS void AS $$
	DELETE FROM env_bindings WHERE
	key_ = $1 OR value_ = $1;
	DELETE FROM env_associations WHERE
	object_ = $1 OR feature_ = $1 OR value_ = $1
$$ LANGUAGE sql;

CREATE OR REPLACE
FUNCTION env_clean() RETURNS void AS $$
	SELECT refs_clean();
	DELETE FROM env_bindings WHERE
	bad_ref(key_) OR bad_ref(value_);
	DELETE FROM env_associations WHERE
	bad_ref(object_) OR bad_ref(feature_) OR bad_ref(value_)
$$ LANGUAGE sql;

CREATE OR REPLACE
FUNCTION drop_schemas_clean(schema_names)
RETURNS text[] AS $$
	SELECT ( SELECT names FROM env_clean() )
	FROM drop_schemas($1) names
$$ LANGUAGE sql;

COMMENT ON
FUNCTION drop_schemas_clean(schema_names) IS '
	DROP all of the schemas in my_schema_names
	from the MAX in use down to the given schema,
	then collect any garbage by calling env_clean()
	-> refs_clean() -> spx_clean()	-> schema_clean()
';
