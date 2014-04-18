# Directory: Wicci/Core/S2_core

This project is dependent on

* [Wicci Core, C_lib, S0_lib](https://github.com/GregDavidson/wicci-core-S0_lib)

* [Wicci S1_refs](https://github.com/GregDavidson/wicci-core-S1_refs)

## Names and Environment Contexts for PostgreSQL

Names and Environments are first class datatypes
participating in the Object-Oriented Features

* Reference
* Row
* Operator and Method Function

which are implemented in

* [WicciS1_refs](https://github.com/GregDavidson/wicci-core-S1_refs).

### Names

Names are symbols with short identifier-like unique names
intended to be used to name things or attributes within some
environment or context.

Names are
* Referenced by name_refs
* Stored in table name_rows

|Function/Operator| Purpose
|-----------------------|----------
| declare_name			| Variadic function for ensuring names exist
| ref_text_op					| Convert object value to text

### Environments

Environments

Environments represent contexts for the evaluation of
methods.  When evaluation of composite objects,
e.g. document trees involves recursion, a reference to the
evaluation environment will be passed along with the
evaluation of all component objects.

Bindings and Associations in an environment should never be
changed; however, because environments support inheritance,
they can at any time be augmented by being used as the Base
for a new environment whose Bindings and Associations will
take precedence over the Bindings and Associations in the
original environment.

* Inherit from 0 or more Base Environments
* Are associated with Name -> Value Bindings
* Are associated with Object + Feature -> Value Associations
* Can block inheritance of specific Bindings and Associations

|Function/Operator| Purpose
|-----------------------|----------
| ref_text_op					| Convert object value to text
|	_env_ ^ _name_	| Return binding of _name_ in _env_
| *and more*			| read the code! :)

All data structures in the Wicci System are expected to be
either immutable or monotonic.  Monotonic data structures
consist of one or more rows in one or more tables.  If the
data structure permits, you may add rows to the value of an
object, but you may not remove rows unless you entirely drop
the object.  You may only update null fields of the rows of
monotonic objects.
