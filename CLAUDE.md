# Project: architecture-templates

## Reference Project: Now in Android (MANDATORY)

**Always reference the Now in Android project** at `/Users/choi/Documents/GitHub/nowinandroid` when writing code for this template.

- **Path:** `/Users/choi/Documents/GitHub/nowinandroid`
- **Source:** https://github.com/android/nowinandroid
- **Purpose:** Google's official Android architecture sample. Treat it as the canonical reference for this multi-module template.

### When to reference it

- Adding new modules (`core/*`, `feature/*`) — match their structure and Gradle conventions
- Writing Hilt DI, Room, Retrofit, or Compose navigation code — copy their patterns
- Setting up `build-logic` convention plugins — mirror their approach
- Writing tests (unit, instrumented, screenshot) — follow their test organization
- Resolving architecture questions — check how NIA solves it first, then adapt

### How to reference it

1. **Search NIA first** before designing a new pattern:
   ```
   Grep/Glob inside /Users/choi/Documents/GitHub/nowinandroid
   ```
2. **Prefer NIA's conventions** over inventing new ones. This template is derived from NIA — stay aligned.
3. **Cite NIA paths** when explaining decisions (e.g., "matches `nowinandroid/core/data/build.gradle.kts`").

### What NOT to copy blindly

- NIA-specific feature code (news, topics, bookmarks) — we have our own `post` feature
- Their `sync` module — unless we add background sync
- Their CI/Kokoro config — we have our own setup

**Rule of thumb:** structure and conventions come from NIA; business logic is ours.
