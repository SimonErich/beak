#!/bin/bash
# Forbid edits of generated .g.dart files

filePath=$(jq -r '.tool_input.filePath // .tool_input.path // empty' < /dev/stdin)

if [[ -z "$filePath" ]]; then
  exit 0
fi

if [[ "$filePath" == *.g.dart || "$filePath" == *.freezed.dart ]]; then
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: "Editing generated .g.dart and .freezed.dart files is forbidden. These files are auto-generated and any changes will be lost on regeneration."
    }
  }'
  exit 0
fi

exit 0