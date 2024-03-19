#!/bin/bash

# Iterate over all arguments
for arg in "$@"; do
  # Match arguments starting with '--'
  if [[ $arg == --* ]]; then
    # Extract parameter name and value
    param="${arg#--}"
    name="${param%%=*}"
    value="${param#*=}"

    # Replace '-' with '_' in parameter name for valid shell variable names
    var_name=$(echo "$name" | tr '-' '_')

    # Dynamically create variable with the name of parameter
    declare "PARAM_$var_name"="$value"
  fi
done

# Example of how to use the created variables:
echo "$PARAM_name1"
echo "$PARAM_name2"
