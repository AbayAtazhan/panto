# Launch kit — Panto

Ten days, one shot. Everything below is copy-paste ready. Replace `USER` with your GitHub handle.

## Day 0 — before anything

- [ ] Repo public, README first screen = GIF, MIT license, 3 screenshots.
- [ ] `brew install --cask` cask submitted (Casks/panto.rb, fill the sha256 after the release).
- [ ] Release `v0.1.0` with `Panto-0.1.0.zip` + notes ("first public build, video only").
- [ ] Pin an issue: "What should Panto do next?" with 5 options.

## Day 1 — Hacker News (Tuesday–Thursday, 08:00–10:00 ET)

**Title:** `Show HN: Panto – free, native auto-zoom for screen recordings (Screen Studio alternative)`

**Body:**
> Screen Studio is $89 and most people only use it for one thing: zooms on the parts of a demo that matter.
>
> Panto is a ~1500-line Swift app that records a display with ScreenCaptureKit, tracks clicks, and bakes a smooth camera move into the mp4 afterwards. The camera center is clamped so you never see black bars, and it is smoothed so it does not feel robotic.
>
> No Electron, no account, no telemetry. Build with the Command Line Tools only.
>
> It is an MVP: video only, no audio yet, no manual timeline. I would love feedback on the zoom feel — that is the whole product.

**First comment (yours, immediately):** the architecture in 3 lines + "what I got wrong" + ask people to post a recording where the zoom feels bad.

## Day 1–2 — Reddit

- r/macapps: `I made a free, native Screen Studio alternative for macOS — auto-zoom, no subscription`
- r/SideProject: `I built the "$89 app" I refused to buy: auto-zoom for screen recordings`
- r/mac: only if a mod allows; otherwise skip, r/mac hates self-promo.
- r/webdev / r/UXDesign: angle "how do you record demos?" — post the GIF, mention the repo in a comment.

Rule: answer every comment for the first 6 hours. Stars follow replies.

## Day 2 — X / Twitter

Thread:
1. GIF, no text: "screen recordings but the camera knows where to look"
2. "Screen Studio is $89. I built the one feature I actually needed, in Swift, in a weekend."
3. architecture screenshot / code snippet of the transform
4. "free + MIT. repo ↓"
DM 20 indie hackers who post screen recordings. Ask for a 10-second test, not a retweet.

## Day 3 — Product Hunt

Tagline: `Auto-zoom for screen recordings. Free and open source.`
First comment: the Screen Studio price comparison + "what's missing" honesty.
Launch 00:01 PT; ask 10 friends to *comment*, not just upvote.

## Day 4 — Chinese communities (this is where half the top Mac repos get their stars)

- 小红书: 15-second vertical video of the zoom, caption "免费开源的 Screen Studio 替代品".
- V2EX: 分享创造 node, title `Panto：免费开源的 macOS 录屏自动缩放`.
- 少数派 (sspai) submission.
Add a `README.zh-CN.md` before posting — Chinese devs star repos with Chinese docs 2–3× more often.

## Day 5–7 — long tail

- Dev.to / Hashnode: "How I built a camera system for screen recordings with AVVideoComposition" (technical posts keep trickling stars for months).
- YouTube Shorts / TikTok: 20s before/after.
- Awesome-mac lists: PR to `jaywcjlove/awesome-mac` under "Screen Recording".

## Do not

- Buy stars. GitHub purges them, and HN will find the graph.
- Launch on Friday or during a US holiday.
- Post the same text in 5 subreddits on the same day — mods ban for it.
- Add features before 100 stars. Fix the demo, not the backlog.

## Metrics to watch

| Signal | Good | Great |
|---|---|---|
| HN front page | top 30 | top 10 for 3h |
| Stars day 1 | 150 | 500 |
| Stars day 10 | 1 000 | 3 000+ |
| Issues opened | 10 | 30 (people care) |

10 000 in 10 days is roughly 1 000/day — top-3 worldwide for the week. It happens when the
GIF is forwarded by non-developers, not when the code is good. Optimize the GIF.
