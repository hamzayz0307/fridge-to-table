# Fridge-to-Table / Dolaptan Sofraya

Pantry-based recipe and meal-planning web app. Owner: Hamza (works in Turkish — reply in Turkish).

## Architecture
- **Frontend:** a single `index.html` (HTML + CSS + JS, no build step), hosted on **Vercel**, auto-deployed from this repo.
- **Backend:** **Supabase** (Postgres + Auth + Edge Functions). The browser uses the Supabase URL and the *publishable/anon* key (`SUPABASE_URL`, `SUPABASE_ANON_KEY` in `index.html`). These are public by design; data is protected by RLS.
- **AI:** Google **Gemini** via the Supabase Edge Function `gemini-proxy` (`callClaude()` in `index.html` is the historical name; it calls the proxy). The Gemini key lives only in Supabase Secrets (`GEMINI_API_KEY`).

## Security rules (do not break)
- Never put secret keys (Supabase service_role/secret key, Gemini key, passwords) in this repo. Secrets go in Supabase Secrets.
- Every table must have RLS enabled with an `auth.uid() = user_id` policy.
- Work on a separate branch and let the owner review the Vercel preview; never push to `main` directly.
- Database changes: write the SQL and give it to the owner to run in the Supabase SQL Editor (no direct DB access).

## Database tables
`pantry_items` (name, category, use_soon, quantity) · `saved_recipes` · `meal_history` (cooked_on) · `meal_plans` (start_date, days jsonb, prep jsonb) · `shopping_list` (name, amount, checked, source) · `profiles` (user_id PK; language, diet, goal, allow_missing, servings, allergies, plan_prefs jsonb, onboarded, display_name) · `guest_menus` (title, guests, dishes jsonb, timeline jsonb). · `feedback` (kind, message, page, language, user_agent; users can insert/read their own, the owner reads all in the Supabase Table Editor).
- `delete_my_account()` (Postgres function, security definer): deletes the caller's rows in every table and their `auth.users` row; the Profile "Delete my account" button calls it via `rpc`. Add any new table to it.

## Auth
- Email/password, Google (Supabase Google provider), and password reset (`resetPasswordForEmail` → `PASSWORD_RECOVERY` event → new-password card). Redirects go to the current page URL, so the Vercel production and preview URLs must be in Supabase → Authentication → URL Configuration → Redirect URLs.
- **Open reminder for the owner:** the Google Auth Platform app is still in *Testing* (not published), so only Google accounts added as test users can sign in with Google. Remind Hamza to publish it (Audience → Publish app) before sharing the app more widely.

## Product decisions
- **Sidebar/Profile = universal settings** (diet, allergies, servings, goal, language). They are the defaults everywhere.
- **Recipes page** choices are temporary for that suggestion and never write to the profile (shows a "changed" badge + "reset to my defaults").
- **Meal plan page** has its own remembered settings (`profiles.plan_prefs`), independent of the sidebar. Default mode is **meal prep** (few dishes cooked once, eaten on several days; the app computes which dish is eaten which day and portion counts); **daily plan** is the alternative.
- **Guest menu**: courses with notes, guest count, occasion, prep time (3h/5h/10h/1d/2d), host timeline.
- Everything is bilingual (English/Turkish): UI strings in the `translations` object (`t(key)`), option pills in `pillLabels`; AI is told to answer in the selected language. Brand: "Fridge-to-Table" / "Dolaptan Sofraya".
- New accounts get a setup card + spotlight tour once (`profiles.onboarded`).
- Navigation: floating bottom bar with 4 tabs — Today (home), Kitchen (pantry), Plan (meal prep + guest menu via a top switch), List (shopping list) — plus a round Profile button. Profile is a full page holding the universal settings, saved recipes and meal history. Recipes, saved and history are sub-pages with a back button.

## Visual style
- Page is a soft sage tint (`--bg`) with white cards (`--surface`); each section gets a color wash at the top (`body[data-page]` → `--wash`: home tomato, kitchen green, plan blue, list mustard, profile plum); home has faint kitchen line doodles behind the greeting. Elements inside white cards use `--bg-soft`.
- Stage 1 done: light cards, near-black primary buttons and selected pills, colored round icons per category (`--ic-*`), Newsreader (display/serif) + Instrument Sans (UI). No all-caps labels.
- Stage 2 done: Kitchen, Plan, List, recipe cards and cook mode in the same style.
- Stage 3 done: dark theme. Profile → Appearance: Light / Dark / System, stored per device in localStorage `ftt_theme` (no DB column); an inline script in `<head>` sets `html[data-theme]` before first paint. Dark values override the `:root` tokens under `:root[data-theme="dark"]`. Use tokens (`--surface`, `--ink`, `--on-ink` for text on ink-filled controls, `--ok-*`/`--warn-*`/`--bad-*` for status tints) instead of hard-coded colors so both themes keep working.

## Working conventions
- Keep element `id`s and classes stable; JS depends on them.
- After changes: check JS syntax, tag balance, that every `t()` key exists in both languages, and run a headless smoke test (jsdom with a fake Supabase + fake AI) covering the main flows.
