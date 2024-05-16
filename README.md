# PJson

This Perl script provides a comprehensive approach to encoding various types of variables into JSON format, including handling special cases such as circular references, undefined values, and different types of references like scalars, arrays, hashes, globs, regexes, code references, file handles, and blessed objects. It also includes options for customizing how certain types of references are handled and for excluding keys during serialization.

The encode_json_variable subroutine is the core function that determines how to encode a given variable based on its type and the provided options. It checks for circular references using a hash ($seen_refs) to keep track of seen references. If a circular reference is detected, it either returns a predefined string "CIRCULAR_REFERENCE" or calls a callback function provided through $options->{handle_circular_refs} if one is defined.

For undefined variables, it offers three behaviors: omitting them entirely, replacing them with a placeholder value specified in $options->{undef_placeholder}, or defaulting to JSON::null. The depth of recursion is controlled by $depth, and there's an option to limit the maximum depth of recursion to prevent infinite loops due to circular references.

The script supports encoding of various reference types, including:

1.Scalars: Directly uses the scalar value.

2.Arrays: Encodes each element recursively unless the maximum depth is reached.

3.Hashes: Encodes each key-value pair recursively unless the maximum depth is reached.

4.Globs: Supports custom handling via a callback function.

5.Regexes: Converts the regex pattern to a string.

6.Code References: Supports custom handling via a callback function.

7.File Handles: Supports custom handling via a callback function.

8.Blessed Objects: Can serialize the object's attributes or stringify the object based on the handle_blessed option.


Additionally, it includes support for serializing blessed objects with custom serializers specified in $options->{custom_serializers}. This allows for flexible customization of how complex objects are serialized.

The encode_json_object and encode_json_array subroutines handle the encoding of hash references and array references, respectively, by iterating over their elements and encoding each one recursively. They also exclude keys specified in $options->{exclude_keys} from being encoded.

Finally, the looks_like_number helper function is used to determine if a scalar value should be treated as a number, simplifying the encoding process for numeric values.

This script demonstrates a robust approach to JSON serialization in Perl, offering flexibility and control over the encoding process through various options and callbacks.
