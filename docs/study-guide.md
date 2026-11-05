# Study Guide

A plain-English walkthrough of this app, written as it gets built. Each task adds a section. Task 8 reorders everything to follow one request through the app and adds interview questions.

## Task 1: Tools, the template, and the first install

### The tools

- **Homebrew** (`brew`) installs command-line programs on a Mac.
- **mise** is a version manager. macOS comes with an old Ruby (2.6) that Apple uses for itself, and you should never install gems into it. mise installs a separate Ruby (3.3.0 here, the version in the template's `.ruby-version` file) and Node, and puts them first on your `PATH`. The line `eval "$(mise activate zsh)"` in `~/.zshrc` is what makes every new Terminal window use them. `which ruby` should show a path under `~/.local/share/mise/`, not `/usr/bin/ruby`.
- **Ruby** is the language of the backend. **Bundler** (`bundle`) installs the Ruby libraries ("gems") listed in `web/Gemfile`, and writes the exact versions it picked into `web/Gemfile.lock`.
- **Node and npm** run the frontend tooling. `npm install` reads `web/frontend/package.json` and fills `node_modules/`.
- **Rails** is the backend web framework. It maps URLs to Ruby code (routes → controllers), talks to the database (models), and runs tests (`bin/rails test`).
- **Shopify CLI** (`shopify`) runs the app in development. `shopify app dev` starts Rails and the frontend dev server together, opens a public tunnel (the `trycloudflare.com` URL) so Shopify can reach your laptop, and keeps the app's settings in your Partner account in sync with `shopify.app.toml`.

### The template

The app started from Shopify's official Ruby app template (`Shopify/shopify-app-template-ruby`). It gives a working embedded app out of the box:

- the `shopify_app` gem, which handles installing the app on a store and checking every request is really from Shopify;
- the `shopify_api` gem, which gives a GraphQL client for the Shopify Admin API;
- a React frontend with Polaris (Shopify's UI components, so the app looks like the admin) and App Bridge (lets the app, which runs in an iframe inside the admin, talk to the admin around it);
- SQLite, a database stored in one file, used only to remember which stores installed the app and their access tokens.

### How install and login work

"Embedded" means the app's page loads inside the Shopify admin, in an iframe. When a merchant opens it:

1. The admin loads the app's URL and adds an `id_token` (a "session token") to the request. It is a short-lived signed token that says "this request is from store X". The app checks the signature with its API secret.
2. The first time, the app has no access token for that store. `shopify_app` performs a **token exchange**: it sends the session token to Shopify and gets back an access token for the Admin API. You can see this in the logs as `Performing Token Exchange`.
3. The access token is saved in the `shops` table (`web/app/models/shop.rb`). This app's tokens expire after an hour and come with a refresh token, which the gem uses to get a new one.
4. Later API calls use the saved token. `AuthenticatedController` (`include ShopifyApp::EnsureHasSession`) is the base for every `/api` controller; it refuses requests without a valid session token.

Permissions ("access scopes") are listed in `shopify.app.toml`. The merchant approves them on install. This app asks for `read_products`, `read_orders` and `read_inventory`, plus the `write_` versions for the seed task. Shopify stores only the `write_` ones, because each `write_` scope includes its `read_` partner.

### Folder layout

```
shopify.app.toml        app settings synced to Shopify: client id, scopes, webhooks
web/                    the Rails app
  Gemfile, Gemfile.lock Ruby gems and their exact versions
  app/controllers/      code that answers requests (home page, /api/...)
  app/services/         plain Ruby classes doing one job (this app's forecast code goes here)
  app/models/shop.rb    one row per installed store, with its access token
  config/routes.rb      which URL goes to which controller
  config/initializers/shopify_app.rb   app name, scopes, API version
  db/                   SQLite database files (not in git) and migrations
  test/                 Minitest tests, run with `bin/rails test`
  frontend/             the React app (pages/, components/), built by Vite
docs/                   spec, plan, and this guide
```

### API version

Shopify releases a new Admin API version every three months and supports each one for about a year. The template used `2025-10`. This app uses `2026-10`, the newest stable version the installed `shopify_api` gem (16.3.1) knows. It is set in `web/config/initializers/shopify_app.rb` (`config.api_version`), and webhooks use the same version in `shopify.app.toml`. It was checked on the dev store: the template's product counter makes a GraphQL call and got `200 OK`. The log notes that `shopify_api` has no REST helper classes for `2026-10`; that doesn't matter, since this app uses GraphQL only.

### What broke on the first run, and why

The template doesn't commit `Gemfile.lock`, so `bundle install` picked the newest version of every gem allowed by the Gemfile, not the versions the template was tested with. Three of them didn't fit Rails 7.1:

1. **`OpenStruct` not found.** `shopify_api` uses Ruby's `OpenStruct` class but never loads it. Older gem versions happened to load it for it. Fix: `gem "ostruct"` in the Gemfile (Rails loads every gem listed there at startup).
2. **Tests wouldn't start.** `minitest` 6 changed how tests are run, and Rails 7.1's test runner wasn't written for it. Fix: `gem "minitest", "~> 5.25"`. The `~>` means "5.25 or newer, but below 6".
3. **`unknown keyword: quirks_mode`.** `json` 3 removed an option that Rails 7.1 passes when turning data into JSON. Fix: `gem "json", "~> 2.7"`.

The lasting fix is committing `Gemfile.lock`, so every machine installs the same versions. `web/test/integration/shopify_api_load_test.rb` sends a fake GraphQL request through `shopify_api` (webmock intercepts it, so nothing goes to the internet) and would fail if any of these came back.

Two other things the CLI did: when it created the app it rewrote `shopify.app.toml` and emptied `scopes`, and set the webhook API version to `2027-01`, which is a release candidate, not a stable version. Both were put back by hand. The `client_id` it added is public and safe to commit; the secret stays in Shopify and in environment variables the CLI sets.

The template also shipped a `.github/` folder with Shopify's own repo tools (CLA bot, issue bots, a style-check workflow). It was removed: none of it applies here, and pushing workflow files needs an extra GitHub permission.
