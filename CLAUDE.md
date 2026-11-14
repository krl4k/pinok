# Pinok — notes for Claude

macOS menu-bar app (Swift, SwiftUI, macOS 26+). It shows short reminders (posture, tongue, blink, water…),
sets of reminders that show together, and breaks that lock the screen and show an exercise.

- Short reminders do not block work: things you can do in 2 seconds at the desk.
- Exercises (stretch, push-ups, squats, walk) belong to breaks, not to short reminders.

## Writing English: ASD-STE100 Simplified Technical English

Write all English text in **ASD-STE100 Simplified Technical English (Issue 9, 2025)**.
This applies to UI strings, README, docs, release notes and error messages.
It does not apply to code, identifiers, or replies to the user in chat.

### Words

- Use simple, common words. Give each word **one meaning only**, and use it only in that meaning.
  For example, "close" means "to close", never "near". "Right" is a direction, never "correct".
- Always use the same word for the same thing. Do not use synonyms for variety.
  In this app: "reminder", "break", "menu bar", "screen", "arrow", "tongue", "Settings".
- Technical names and verbs are allowed: Mac, menu bar, display, microphone, camera, click, type, drag.
- Do not use phrasal verbs. Write "start", not "set off"; "wait", not "hold off"; "stop", not "turn off" (for actions).
- Replace complex words. Typical replacements:
  utilize → use · ensure → make sure · prior to → before · commence → start · terminate → stop ·
  approximately → about · additional → more · sufficient → enough · in order to → to ·
  display (verb) → show · heads-up → warning · palate → roof of the mouth.
- Verb forms: only infinitive, imperative, simple present, simple past, and future with "will".
  Do not use "-ing" forms as verbs. Use the past participle only as an adjective.
- Do not use contractions. Write "do not", "you are", "it is".
- Use "can" for ability and "must" for a requirement. Do not use "should", "may" or "might" for instructions.
- Do not make noun clusters of more than 3 words. Write "timer for the break", not "break reminder timer setting".
- Do not leave out "the", "a", "this" or "that" to make text shorter.

### Sentences

- **Instructions** (procedures): 20 words maximum. Write one instruction in each sentence.
  Use the imperative: "Click Open." Put a condition first: "If the app does not start, click Open again."
- **Descriptions**: 25 words maximum. Give one idea in each sentence.
- Use the **active voice**. Write "The app shows a warning", not "A warning is shown".
- Paragraphs: one topic, 6 sentences maximum. Use vertical lists for steps and options.
- Warnings and cautions: start with a clear command, then give the reason.
  "Do not close the lid during a break. The timer stops."
- Do not use semicolons or long dashes to join ideas. Write two sentences.
- Talk to the user as "you".

### UI text

- Buttons and menu items: 1–3 words, verb first ("Start now", "Skip", "Choose…").
- Labels and toggles: a short noun phrase or a short imperative ("Pause during calls").
- Subtitles under a setting: one description sentence, 12 words or fewer.
- No jargon in the UI: no "overlay", "nudge", "assertion", "snooze".

### Check before you finish

Reread every new or changed English string and check it against the rules above:
one meaning per word, approved verb forms, active voice, no contractions, sentence length.

## Localization

- Every user-facing string goes through `t("...")` (see `Sources/PinokKit/Localization.swift`).
- The key is the English text itself. Add a Russian entry to `L10n.ru` for every new string.
- If you change an English string, change its key in `L10n.ru` too.
- Strings with values use format keys: `t("Break in %@", time)`, `t("%ld min", minutes)`.

## Project

- All code lives in the `PinokKit` library; `Sources/Pinok/main.swift` only starts the app.
- SwiftUI previews: open `Package.swift` in Xcode and use the **PinokKit** scheme.
- Build: `./build.sh` → `build/Pinok.app`. DMG: `./scripts/make-dmg.sh`. GIFs: `./scripts/record-gifs.sh`.
- Code comments are in Russian; that is fine.
- Tests: `swift test --no-parallel` (Swift Testing, `Tests/PinokKitTests`). The scheduler takes a fake clock, presenter,
  idle and busy sources, so test logic without windows. Use `--scratch-path` per agent when agents run in parallel.
- `SettingsUITests` opens the real Settings window and selects every sidebar row. If the sidebar stops
  responding to clicks, this test fails. Keep the sidebar built from `SidebarModel`.
- Do not take screenshots of the user's screen. Use Xcode previews or `--stage` mode instead.
