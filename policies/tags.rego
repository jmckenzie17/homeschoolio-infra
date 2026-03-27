package main

import rego.v1

# Required tags on every taggable Azure resource per constitution Infrastructure Standards.
required_tags := {"Project", "Environment", "ManagedBy", "Owner"}

deny contains msg if {
  resource := input.resource_changes[_]

  # Only evaluate resources being created or updated (not no-op or deleted)
  action := resource.change.actions[_]
  action != "no-op"
  action != "delete"

  # Skip data sources (address starts with "data.")
  not startswith(resource.address, "data.")

  tag := required_tags[_]
  not resource.change.after.tags[tag]

  msg := sprintf(
    "Resource %s (%s) is missing required tag: %s",
    [resource.address, resource.type, tag],
  )
}
