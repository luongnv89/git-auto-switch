#!/usr/bin/env bash
# Command router

route_command() {
  local command="${1:-help}"
  shift 2>/dev/null || true

  case "$command" in
    init)
      cmd_init "$@"
      ;;
    add)
      cmd_add "$@"
      ;;
    remove)
      cmd_remove "$@"
      ;;
    list|ls)
      cmd_list "$@"
      ;;
    apply)
      cmd_apply "$@"
      ;;
    validate|check)
      cmd_validate "$@"
      ;;
    audit)
      cmd_audit "$@"
      ;;
    current|whoami)
      cmd_current "$@"
      ;;
    version|--version|-v)
      show_version
      ;;
    help|--help|-h)
      show_help
      ;;
    *)
      log_error "Unknown command: $command"
      echo
      show_help
      exit 1
      ;;
  esac
}
