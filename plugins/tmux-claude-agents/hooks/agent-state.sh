#!/usr/bin/env bash
# Show this agent's state and name on its tmux window.
#
#   agent-state.sh <state>   idle | working | blocked | done
#   agent-state.sh end       on SessionEnd: undo both
#
# The state goes into the window option @claude_state. The picker (agents.sh)
# reads it, and @claude_dot draws it when a window format includes
#   #{?@claude_state,#{E:@claude_dot} ,}
# States follow herdr: `done` means finished and not looked at yet. A turn that
# ends in the window on screen goes straight to idle, and the tmux hooks in
# claude_agents.tmux turn `done` idle once the window is switched to.
#
# The window takes the session's name from Claude's session file. A derived
# name (`nameSource: derived`, `<start folder>-<xx>`) is cut to `xx`: the tmux
# session usually says which project it is already. A name set with --name or
# /rename stays whole. Only windows nobody named are taken over: automatic-rename
# on, a bare shell or version name (`zsh`, `2.1.296` - restore scripts such as
# tmux-resurrect put those back pinned), or the name set here before. The window
# gets it back on SessionEnd.
#
# Interactive sessions only: `claude -p` runs hooks too, but is gone before
# anyone looks, and must not rename the window it runs in.
#
# Never fails and never prints: hook output lands in the transcript, and a
# failed hook must not fail the turn.

[ -n "${TMUX_PANE:-}" ] || exit 0
command -v jq >/dev/null 2>&1 || exit 0
# Claude sets this to 0 for `claude -p`, which writes no session file either, so
# the `kind` check below cannot catch it.
[ "${CLAUDE_CODE_SESSION_ATTENDED:-1}" != 0 ] || exit 0

action="${1:-}"
input="$(cat)"
sid="$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)"

# Field separator for multi-value reads. Not a tab: tab is IFS whitespace, so
# an empty field in the middle would collapse and shift the rest.
US=$'\x1f'

# entry <session-id>
#   kind US name US name-source, from the session's file; empty when not found
#   (it may not be written yet on SessionStart).
entry() {
  [ -n "$1" ] || return 0
  local files
  files=("${CLAUDE_CONFIG_DIR:-$HOME/.claude}"/sessions/*.json)
  [ -f "${files[0]}" ] || return 0
  jq -r --arg sid "$1" \
    'select(.sessionId == $sid) | [.kind // "", .name // "", .nameSource // ""] | join("\u001f")' \
    "${files[@]}" 2>/dev/null | head -n 1
}

IFS=$US read -r kind name source <<<"$(entry "$sid")"
[ -z "$kind" ] || [ "$kind" = interactive ] || exit 0

# A name nobody chose.
generic_name() {
  case "$1" in
    zsh | bash | sh | fish) return 0 ;;
  esac
  [[ $1 =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

rename_window() {
  [ -n "$name" ] || return 0
  local short="$name" current auto ours
  [ "$source" = derived ] && short="${name##*-}"
  # A format, not show-options: it resolves automatic-rename through the global
  # value when the window does not set its own.
  IFS=$US read -r current auto ours <<<"$(tmux display-message -p -t "$TMUX_PANE" \
    "#W$US#{automatic-rename}$US#{@claude_name}" 2>/dev/null)"
  [ "$current" = "$short" ] && return 0
  if [ "$auto" = 1 ] || generic_name "$current" ||
    { [ -n "$ours" ] && [ "$current" = "$ours" ]; }; then
    tmux rename-window -t "$TMUX_PANE" "$short" 2>/dev/null
    tmux set-option -w -t "$TMUX_PANE" @claude_name "$short" 2>/dev/null
  fi
}

case "$action" in
  idle | working | blocked | done)
    state="$action"
    if [ "$state" = "done" ] &&
      [ "$(tmux display-message -p -t "$TMUX_PANE" '#{&&:#{window_active},#{session_attached}}' 2>/dev/null)" = 1 ]; then
      state=idle
    fi
    tmux set-option -w -t "$TMUX_PANE" @claude_state "$state" 2>/dev/null
    rename_window
    ;;
  end)
    IFS=$US read -r current ours <<<"$(tmux display-message -p -t "$TMUX_PANE" \
      "#W$US#{@claude_name}" 2>/dev/null)"
    if [ -n "$ours" ] && [ "$current" = "$ours" ]; then
      # Unset rather than `on`, so the window follows the global setting again.
      tmux set-option -wu -t "$TMUX_PANE" automatic-rename 2>/dev/null
    fi
    tmux set-option -wu -t "$TMUX_PANE" @claude_name 2>/dev/null
    tmux set-option -wu -t "$TMUX_PANE" @claude_state 2>/dev/null
    ;;
esac

exit 0
