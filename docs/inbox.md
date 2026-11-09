# Sending messages and gifts

Players get messages from `store/inbox.json`. Edit it, commit and push to `main`,
and phones pick it up the next time Home opens (allow a few minutes for GitHub's
cache). No app update is needed once a version with the inbox is live.

```json
{
  "messages": [
    {
      "id": "thanks-2026-11",
      "title": "Thank you!",
      "body": "Thanks for playing Egg Escape. Here's a little something.",
      "rewards": {"coins": 5000, "bomb": 2},
      "min_level": 5,
      "from": "2026-11-20",
      "until": "2026-11-30"
    }
  ]
}
```

| Field | Needed | Meaning |
|---|---|---|
| `id` | yes | Unique, and never reused: a phone that collected this id never sees it again |
| `title` | yes | The heading |
| `body` | no | The text, up to 200 characters (anything longer is cut off) |
| `rewards` | no | Any of `coins`, `materials`, `bomb`, `swap` (the Any Piece), `rocks`, `skips`. With none, the button says OK |
| `min_level`, `max_level` | no | Only players on these levels |
| `min_streak` | no | Only players on this login streak or longer |
| `from`, `until` | no | Dates, `YYYY-MM-DD`, in the player's local time, both included |

Things to know:

- **The file is public**, because the repo is. Don't put anything private in it.
- **Check the JSON before pushing.** A broken file is ignored, so phones keep the last good one; a message missing `id` or `title` is skipped.
- **A reward can be collected again after a reinstall**, because what's been collected is saved on the phone. Reinstalling also resets progress, so it's rarely worth doing. Use `until` on every gift so old ones stop going to new players.
- **There's no targeting of individual players or of a real top 10**: the game has no accounts. Rules are all a phone can check about itself.
- Editing a message that's already out changes it for anyone who hasn't collected it. Changing its `id` sends it again to everyone.
- The tile on Home only shows while a message is waiting. It hides on its own when the inbox is empty.
- The same file can also change ad frequency and other numbers: see [remote-settings.md](remote-settings.md).
