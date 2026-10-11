#!/usr/bin/env bash
# tmux-claude-agents
#
# List, monitor status, and jump across nested Claude Code sessions from a
# single popup. tpm runs this file as an executable on tmux startup; it reads
# user options (with sensible defaults) and installs the key bindings.

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/helpers.sh
. "$CURRENT_DIR/scripts/helpers.sh"

launch_key="$(get_tmux_option @claude_launch_key 'y')"
list_key="$(get_tmux_option @claude_list_key 'u')"

# Launch (or re-attach to) a Claude session for the current pane's directory.
# #{pane_current_path} / #{window_id} are expanded by run-shell before the args
# reach the script.
tmux bind-key "$launch_key" \
  run-shell "$CURRENT_DIR/scripts/launch.sh '#{q:pane_current_path}' '#{q:window_id}'"

# Open the session picker. When pressed from inside a session popup, list.sh
# closes that popup first so the picker opens full-size on the outer client.
tmux bind-key "$list_key" \
  run-shell "$CURRENT_DIR/scripts/list.sh '#{q:client_name}'"

# Forward a bell from a dedicated session to its origin window's pane, so
# tmux's own bell machinery (window-status-bell-style, and terminal
# passthrough when that window is visible) picks it up even though the
# session that rang is a separate session from the origin. Off by default: it
# only matters for sessions started from the launch popup.
if [ "$(get_tmux_option @claude_forward_bell 'off')" = 'on' ]; then
  tmux set-hook -g alert-bell \
    "run-shell -b \"$CURRENT_DIR/scripts/bell.sh '#{q:hook_session_name}'\""
fi

# Agent state dot, drawn by a window format that includes
#   #{?@claude_state,#{E:@claude_dot} ,}
# @claude_state is set per window by the Claude plugin's agent-state.sh. States
# and colors follow herdr: idle ○ green, working ● yellow, blocked ● red,
# done ● cyan (finished, not looked at yet), anything else · grey. Basic ANSI
# colors, so the shades come from the terminal theme. Set @claude_dot yourself
# to draw it differently.
if [ -z "$(tmux show-option -gqv @claude_dot)" ]; then
  tmux set-option -g @claude_dot '#{?#{==:#{@claude_state},blocked},#[fg=red]●,#{?#{==:#{@claude_state},working},#[fg=yellow]●,#{?#{==:#{@claude_state},done},#[fg=cyan]●,#{?#{==:#{@claude_state},idle},#[fg=green]○,#[fg=brightblack]·}}}}'
fi

# `done` becomes idle once its window is looked at: switched to within a
# session, or current in a session a client switches to. Indexed, so hooks the
# user has on the same events stay.
tmux set-hook -g 'session-window-changed[42]' \
  'if -F "#{==:#{@claude_state},done}" "set -w @claude_state idle"'
tmux set-hook -g 'client-session-changed[42]' \
  'if -F "#{==:#{@claude_state},done}" "set -w @claude_state idle"'
