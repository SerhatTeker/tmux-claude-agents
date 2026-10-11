# tmux-claude-agents

A [Claude Code plugin](https://docs.claude.com/en/docs/claude-code/plugins) that
ships the hook configuration
[tmux-claude-agents](https://github.com/SerhatTeker/tmux-claude-agents)
wants, so you don't have to paste JSON into `~/.claude/settings.json`.

It does three things:

- **Rings the terminal bell** when an agent ends a turn, asks for permission, or
  asks you a question — the three moments the picker calls `done`, `idle` and `blocked`.
  tmux only raises an alert for a real `\a` written to a pane's pty, which is what
  makes window-status alerts and this plugin's bell forwarding fire.
- **Refreshes the picker's agent cache** on those same events, plus session
  start/end and prompt submit. The picker paints its first frame from that cache
  (unless `@claude_picker_cache` is `'off'`), so without this it can be stale —
  showing `working` for an agent that has been waiting on you.
- **Shows each agent's state and name on its tmux window**: `@claude_state`
  (`idle`, `working`, `blocked`, `done`) and the session's name while the agent
  runs. Interactive sessions only; `claude -p` leaves the window alone. See
  [Agent states](../../README.md#agent-states).

## Install

```
/plugin marketplace add SerhatTeker/tmux-claude-agents
/plugin install tmux-claude-agents@tmux-claude-agents
```

## Notes

- All hooks are silent, always exit `0`, and run the cache refresh detached, so
  a failure never fails a turn and nothing lands in the transcript.
- The cache refresh is skipped entirely when the agent is not inside tmux — it
  would otherwise overwrite a good cache with an empty one.
- This covers the hook route only. `preferredNotifChannel` and
  `messageIdleNotifThresholdMs` are user settings a plugin cannot set; see
  [Making Claude ring the bell](../../README.md#making-claude-ring-the-bell) if
  you'd rather use Claude's built-in bell than a hook.
