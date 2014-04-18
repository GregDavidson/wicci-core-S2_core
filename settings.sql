-- * Header  -*-Mode: sql;-*-
\cd
\cd .Wicci/Core/S2_core
\i ../settings+sizes.sql

SELECT s0_lib.set_schema_path('S2_core','S1_refs','S0_lib','public');

SELECT ensure_schema_ready();
