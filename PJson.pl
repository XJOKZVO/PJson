#!/usr/bin/perl
package PJson;

use strict;
use warnings;
use JSON;
use Scalar::Util qw(blessed weaken isweak reftype);

sub encode_json_variable {
    my ($variable, $options, $depth, $seen_refs) = @_;

    $options //= {};
    $depth //= 0;
    $seen_refs //= {};

    # Check for circular references
    if (ref $variable && exists $seen_refs->{$variable}) {
        if ($options->{handle_circular_refs} && ref $options->{handle_circular_refs} eq 'CODE') {
            return $options->{handle_circular_refs}->($variable);
        } else {
            return "CIRCULAR_REFERENCE";
        }
    }

    my $json_value;
    if (!defined $variable) {
        if ($options->{undef_behavior} && $options->{undef_behavior} eq 'omit') {
            return;
        } elsif ($options->{undef_placeholder}) {
            $json_value = $options->{undef_placeholder};
        } else {
            $json_value = JSON::null;
        }
    } elsif (ref $variable eq 'HASH') {
        if ($depth < $options->{max_depth}) {
            $seen_refs->{$variable} = 1;
            $json_value = encode_json_object($variable, $options, $depth + 1, $seen_refs);
        } else {
            $json_value = "MAX_DEPTH_REACHED";
        }
    } elsif (ref $variable eq 'ARRAY') {
        if ($depth < $options->{max_depth}) {
            $seen_refs->{$variable} = 1;
            $json_value = encode_json_array($variable, $options, $depth + 1, $seen_refs);
        } else {
            $json_value = "MAX_DEPTH_REACHED";
        }
    } elsif (ref $variable eq 'SCALAR') {
        if ($options->{handle_scalar_refs} && ref $options->{handle_scalar_refs} eq 'CODE') {
            $json_value = $options->{handle_scalar_refs}->($variable);
        } else {
            $json_value = $$variable;
        }
    } elsif (ref $variable eq 'GLOB') {
        if ($options->{handle_globs} && ref $options->{handle_globs} eq 'CODE') {
            $json_value = $options->{handle_globs}->($variable);
        } else {
            $json_value = "UNSUPPORTED_GLOB_REFERENCE";
        }
    } elsif (ref $variable eq 'Regexp') {
        if ($options->{handle_regex} && ref $options->{handle_regex} eq 'CODE') {
            $json_value = $options->{handle_regex}->($variable);
        } else {
            $json_value = "$variable";
        }
    } elsif (ref $variable eq 'CODE') {
        if ($options->{handle_code} && ref $options->{handle_code} eq 'CODE') {
            $json_value = $options->{handle_code}->($variable);
        } else {
            $json_value = "UNSUPPORTED_CODE_REFERENCE";
        }
    } elsif (ref $variable eq 'IO::Handle' || ref $variable eq 'IO::File') {
        if ($options->{handle_filehandles} && ref $options->{handle_filehandles} eq 'CODE') {
            $json_value = $options->{handle_filehandles}->($variable);
        } else {
            $json_value = "UNSUPPORTED_FILEHANDLE_REFERENCE";
        }
    } elsif (ref $variable eq 'ARRAY') {
        if ($options->{handle_array_refs} && ref $options->{handle_array_refs} eq 'CODE') {
            $json_value = $options->{handle_array_refs}->($variable);
        } else {
            $json_value = join ',', @$variable;
        }
    } elsif (ref $variable eq 'HASH') {
        if ($options->{handle_hash_refs} && ref $options->{handle_hash_refs} eq 'CODE') {
            $json_value = $options->{handle_hash_refs}->($variable);
        } else {
            my %hash_copy = %$variable;
            $json_value = \%hash_copy;
        }
    } elsif (blessed($variable)) {
        if ($options->{handle_blessed} eq 'serialize') {
            $json_value = encode_blessed_reference($variable, $options, $depth + 1, $seen_refs);
        } elsif ($options->{handle_blessed} eq 'stringify') {
            $json_value = "$variable";
        } else {
            $json_value = "UNSUPPORTED_BLESSED_REFERENCE";
        }
    } elsif (looks_like_number($variable)) {
        $json_value = $variable;
    } elsif ($variable =~ /^(true|false)$/i) {
        $json_value = lc($variable) eq 'true' ? JSON::true : JSON::false;
    } elsif ($variable =~ /^null$/i) {
        $json_value = JSON::null;
    } else {
        $json_value = JSON::to_json($variable);
    }

    return $json_value;
}

sub encode_json_object {
    my ($hash_ref, $options, $depth, $seen_refs) = @_;
    my %json_hash;

    for my $key (keys %$hash_ref) {
        next if $options->{exclude_keys} && exists $options->{exclude_keys}->{$key};
        $json_hash{$key} = encode_json_variable($hash_ref->{$key}, $options, $depth, $seen_refs);
    }

    return \%json_hash;
}

sub encode_json_array {
    my ($array_ref, $options, $depth, $seen_refs) = @_;
    my @json_array;

    for my $element (@$array_ref) {
        push @json_array, encode_json_variable($element, $options, $depth, $seen_refs);
    }

    return \@json_array;
}

sub encode_blessed_reference {
    my ($object, $options, $depth, $seen_refs) = @_;

    my %json_object;
    $json_object{'__CLASS__'} = ref $object;

    if (overload::Method($object, '""')) {
        $json_object{'__STRING__'} = "$object";
    }

    if (overload::Method($object, '0+')) {
        $json_object{'__NUMERIC__'} = 0 + $object;
    }

    if (blessed($object)) {
        my $serializer = $options->{custom_serializers}->{ref $object};
        if ($serializer && ref $serializer eq 'CODE') {
            return $serializer->($object);
        }
    }

    # Check for circular references in blessed objects
    if (blessed($object) && exists $seen_refs->{$object}) {
        if ($options->{handle_circular_refs} && ref $options->{handle_circular_refs} eq 'CODE') {
            return $options->{handle_circular_refs}->($object);
        } else {
            return "CIRCULAR_REFERENCE";
        }
    }

    $seen_refs->{$object} = 1;

    # Extract and encode object attributes
    for my $attribute (keys %$object) {
        next if $attribute =~ /^_/; # Skip private attributes
        $json_object{$attribute} = encode_json_variable($object->{$attribute}, $options, $depth, $seen_refs);
    }

    return \%json_object;
}

# Helper function to check if a scalar value looks like a number
sub looks_like_number {
    my $value = shift;
    return 1 if $value =~ /^-?\d+$/; # integer
    return 1 if $value =~ /^-?\d+\.\d+$/; # float
    return;
}
1;
