# SuperAI Assistant

A Telegram support bot for the XRP Super Football Fans community.

- Answers members' questions from an **approved knowledge base** (FAQs you control), with official links.
- Optional **AI** (any OpenAI-compatible provider) that may only use retrieved excerpts, plus a **free FAQ-only mode**.
- **Human handoff, two ways** (use either or both):
  1. A **Contact Human Moderator** button that opens your Telegram username (`SUPPORT_TELEGRAM_USERNAME`).
  2. A **private ticket system**: the member's message is delivered to you with a ticket ID, you reply through the bot, and your personal account is never revealed.

> **Cost:** with the defaults (`AI_PROVIDER=none`) the bot makes **no paid API calls**. AI is opt-in and capped by daily limits.

---

## 1. How it works

```
member message
   |-- rate limit, length limit, secret/credential check
   |-- support mode? ---------------------------> TicketService --> support chat (you)
   |                                                    ^                |
   |                                                    |  /reply or Telegram "Reply"
   '-- question --> KnowledgeBase.search()                |                v
                      |-- strong FAQ match  --> answer (no AI call)    member gets your reply
                      |-- partial match + AI --> AI answers from excerpts only (cached, capped)
                      |-- AI off/failed/over limit --> best FAQ match
                      '-- nothing reliable  --> "I can't verify that" + human-support buttons
```

| Module | Responsibility |
|---|---|
| `app/config.py` | All settings from environment variables, validated; secrets hidden from logs/repr |
| `app/db.py` | Portable SQLite / PostgreSQL layer, schema + versioned migrations |
| `app/knowledge.py` | FAQ CRUD, retrieval, optional import of official pages (as **drafts**) |
| `app/ai.py` | Answer engine, OpenAI-compatible provider, cache, link/injection guards |
| `app/tickets.py` | Tickets, moderator replies, closing (no Telegram dependency) |
| `app/settings.py` | Admin-changeable settings (moderator username override, daily counters) |
| `app/handlers_user.py`, `app/handlers_mod.py`, `app/ui.py` | Telegram handlers, texts, buttons |
| `app/bot.py`, `app/__main__.py` | Wiring; polling or webhook |

---

## 2. Create the bot (BotFather)

1. In Telegram open **@BotFather** and send `/newbot`. Choose a name and a username ending in `bot`.
2. Copy the token it gives you. Treat it like a password. If it ever leaks, send `/revoke` to BotFather.
3. Optional: `/setdescription`, `/setabouttext`, `/setuserpic`.
4. Optional but recommended for a group: `/setprivacy` -> your bot -> **Enable** (the bot then only sees commands and replies).

## 3. Configure securely

```bash
cp .env.example .env        # .env is git-ignored
```

Edit `.env` (local) or set the same names as **environment variables** on your host:

| Variable | Required | Meaning |
|---|---|---|
| `BOT_TOKEN` | yes | Token from BotFather |
| `MODERATOR_USER_IDS` | for tickets | Comma-separated numeric user IDs allowed to use moderator commands |
| `SUPPORT_CHAT_ID` | no | Where tickets arrive. Empty = first moderator's private chat with the bot |
| `SUPPORT_TELEGRAM_USERNAME` | no | Username for the **Contact Human Moderator** button. Empty/placeholder/invalid = "not configured" (the bot keeps working and explains it) |
| `DATABASE_URL` | no | `sqlite:///data/superai.db` (default) or `postgresql://...` |
| `AI_PROVIDER` | no | `none` (default) or `openai_compatible` |
| `AI_BASE_URL`, `AI_API_KEY`, `AI_MODEL` | if AI on | Provider settings (all three required, else AI is disabled with a warning) |
| `AI_DAILY_LIMIT`, `AI_USER_DAILY_LIMIT` | no | Global / per-member daily AI call caps (300 / 15) |
| `WEBHOOK_URL`, `WEBHOOK_SECRET_TOKEN`, `PORT` | no | Webhook mode (see section 8). Polling if `WEBHOOK_URL` is empty |

Full list with comments: `.env.example`.

### Finding your IDs
1. Start the bot (section 4) with only `BOT_TOKEN` set.
2. Message the bot `/id`. It replies with **your user ID** -> put it in `MODERATOR_USER_IDS`.
3. **Private tickets in your own chat:** leave `SUPPORT_CHAT_ID` empty and press **Start** in the bot once.
4. **Private support group instead:** create a group with only moderators, add the bot, send `/id` inside the group, and use the negative number it shows as `SUPPORT_CHAT_ID`. Keep that group restricted: anyone in it can read tickets.
5. Restart the bot after changing environment variables.

### The moderator contact username
- Set `SUPPORT_TELEGRAM_USERNAME=your_username` (hard-coded nowhere).
- Change it **without redeploying**: `/setsupport @new_username`. `/setsupport clear` returns to the environment value. `/setsupport` shows the current one.
- `/support` displays the configured `@username`; the button opens `https://t.me/<username>`.

> Opening your username is **not** the same as the ticket system. The button just opens a Telegram chat with you. Tickets are delivered to the bot's support chat, tracked, and answered through the bot.

## 4. Run locally

```bash
python3 -m venv .venv && source .venv/bin/activate     # Windows: .venv\Scripts\activate
pip install -r requirements.txt
python -m app
```
The database tables are created automatically on first start, and the starter FAQs are loaded once.

## 5. Tests

```bash
python -m unittest discover -s tests -t .      # or: pip install pytest && pytest
```
Covers: FAQ retrieval and admin editing, AI fallback/caching/limits/injection, ticket creation, duplicates, delivery failures, moderator authorization, reply delivery, member isolation, username validation and configuration fallbacks.

## 6. Moderator commands (only IDs in `MODERATOR_USER_IDS`; private chat or the support chat only)

| Command | What it does |
|---|---|
| `/tickets [open\|answered\|closed\|all]` | List tickets |
| `/ticketinfo T-ABC234` | Details, member info, recent messages |
| `/reply T-ABC234 text` | Answer the member. **Or just use Telegram's Reply on the ticket message.** |
| `/close T-ABC234 [silent]` | Close; the member is told unless `silent` |
| `/setsupport @name` / `clear` | Change the Contact Moderator username |
| `/addfaq Q \| A \| keywords \| https://source` | Add an FAQ (live immediately) |
| `/editfaq ID \| Q \| A \| keywords \| url` | Edit (empty part keeps the old value) |
| `/delfaq ID`, `/listfaq`, `/kbview ID` | Manage and read entries |
| `/kbrefresh` | Fetch the official pages as **drafts**; `/kbpending`, `/kbapprove ID\|all` publish them |
| `/stats`, `/modhelp` | Overview and help |

Members' commands: `/start /help /faq /website /register /support /cancel` (private chat). In groups the bot only points people to a private chat.

### Knowledge base notes
- The starter FAQs in `data/seed_faq.json` were written from what the public pages XRPFootball.com and the netmark.ai/xrp page said on the day this project was generated. **Review them, and edit with `/editfaq` whenever the campaign changes.**
- `/kbrefresh` only fetches hosts from `KB_SOURCE_URLS`, never follows redirects to other hosts, and saves excerpts as **unapproved drafts**. Nothing reaches members until you approve it. If a page needs JavaScript or is unreachable, add the facts with `/addfaq`.
- Keep campaign facts separate from general SuperOne platform facts (the AI prompt also tells the model to).

## 7. AI provider, limits and cost

Any service that offers `POST {AI_BASE_URL}/chat/completions` works (OpenAI, Groq, OpenRouter, Google's OpenAI-compatible Gemini endpoint, a local server, ...). Example shape:

```
AI_PROVIDER=openai_compatible
AI_BASE_URL=https://<provider's OpenAI-compatible base URL>
AI_API_KEY=<key from the provider's dashboard>
AI_MODEL=<model id from the provider>
```
- **Free tiers, quotas and prices are set by each provider and change.** Check the provider's current pricing page *before* creating a key, and prefer a key without a payment method attached. This project never signs up for or enables anything paid.
- The bot only calls the AI when FAQs don't already answer a question, caches answers (`CACHE_TTL_SECONDS`), and stops at `AI_USER_DAILY_LIMIT` per member and `AI_DAILY_LIMIT` overall; after that it uses the FAQ fallback. The daily counter is stored in the database.
- The AI only sees retrieved excerpts, must answer `NO_ANSWER` when unsure, is told never to promise income or ask for credentials, and any URL it writes that is not in the excerpts is removed.

## 8. GitHub

```bash
git init
git add .
git status                      # confirm .env and data/*.db are NOT listed
git commit -m "SuperAI Assistant"
git branch -M main
git remote add origin https://github.com/<you>/<repo>.git
git push -u origin main
```
Use a **private** repository if you prefer. `.gitignore` already excludes `.env` and database files. If a secret is ever committed, revoke it (BotFather `/revoke`, regenerate the AI key); deleting the commit is not enough.

## 9. Deploy

General rule: the process is `python -m app`; configuration is environment variables only; use **PostgreSQL** (`DATABASE_URL`) on any host whose disk is not persistent, otherwise tickets disappear on redeploy.

**Polling vs webhook.** Polling (default) needs an always-on process and no public URL. Webhook mode (`WEBHOOK_URL=https://your-domain`, `WEBHOOK_SECRET_TOKEN=...`, listens on `PORT`) is for hosts that sleep idle services or require an HTTP port. Run only **one** instance of the bot.

### Railway
1. New project -> **Deploy from GitHub repo** -> select the repo (the `Dockerfile` is used automatically).
2. Add a **PostgreSQL** database to the project, then in the bot service's *Variables* add `DATABASE_URL` referencing the database's connection URL.
3. Add `BOT_TOKEN`, `MODERATOR_USER_IDS`, `SUPPORT_CHAT_ID` (optional), `SUPPORT_TELEGRAM_USERNAME`, and optionally the AI variables.
4. Deploy and read the logs: you should see "AI: ... | private tickets: ... | moderator contact: ...".
5. Polling needs no domain. For webhook mode, generate a public domain, set `WEBHOOK_URL` to it and add `WEBHOOK_SECRET_TOKEN`.
- Railway usage is metered/plan-based: check its current pricing before deploying. Nothing in the code depends on Railway.

### Render (alternative)
1. New **Web Service** from the GitHub repo, runtime **Docker**.
2. Create a Render **PostgreSQL** and set `DATABASE_URL` to its internal URL.
3. Set the same variables. Use **webhook mode** (`WEBHOOK_URL=https://<service>.onrender.com`, `WEBHOOK_SECRET_TOKEN`); `PORT` is provided by Render.
4. Free web services may sleep when idle, which delays replies; a paid always-on instance avoids this. Check Render's current plans first.

### Any VPS / Docker host (alternative)
```bash
git clone <your repo> && cd <repo>
cp .env.example .env && nano .env
docker compose up -d --build                      # SQLite file kept in ./data
# or with PostgreSQL: set POSTGRES_PASSWORD and DATABASE_URL in .env, then
docker compose --profile postgres up -d --build
docker compose logs -f bot
```
Back up the `./data` folder (SQLite) or the Postgres volume.

## 10. Database and migrations
- Tables are created on startup (`CREATE TABLE IF NOT EXISTS`). The applied schema version is stored in the `settings` table.
- To change the schema later, add statements under a new version number in `MIGRATIONS` in `app/db.py`; they run once, in order, on the next start.
- Moving from SQLite to PostgreSQL: start the bot with the new `DATABASE_URL`. Existing SQLite data is **not** copied automatically (export FAQs first with `/listfaq` + `/kbview` if you need them; the starter FAQs reload automatically).

## 11. Security summary
- Moderator commands require your ID in `MODERATOR_USER_IDS` **and** a private chat or the support chat. Members get a neutral refusal and no data.
- Ticket replies are addressed from the database's stored chat ID for that ticket, never from text a user typed, so one member's messages cannot reach another.
- The database enforces one active ticket per member. Members are told "sent" only after Telegram accepted the message to the support chat.
- Secrets live only in environment variables. Logs redact bot tokens and keys; HTTP client logging that contains URLs is silenced; message text is never logged.
- Messages that look like pasted private keys, XRPL family seeds or Xaman secret numbers are not stored, answered or forwarded.
- Prompt-injection phrases skip the AI entirely; the AI prompt treats the question as untrusted data.
- Limits: per-member message rate, message length, ticket creation rate, daily AI budgets.

## 12. Known limitations (read before launch)
- Telegram bots cannot read or reply to messages the member sends outside a chat with the bot; moderators must keep the **support chat reachable** (press Start in the bot, or add it to the group).
- Support mode (the "type your message now" state) and rate limits live in memory and reset on restart; tickets and settings are in the database.
- Retrieval is keyword based (no embeddings). Add `keywords` to FAQs to improve matching for the words your members actually use.
- Members can send text only; photos/files are not forwarded to tickets.
- The secret detector catches common key formats, not every possible phrase. The bot warns members never to share credentials.
- Single-process design: do not run two copies against the same bot token.
