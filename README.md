# AngelTrading

Hey there, Elixir enthusiasts!

I developed this application as a personal passion project. The primary goal is to design a comprehensive dashboard that provides a centralized hub for managing and monitoring multiple portfolios, all accessible from a single device. While it's still a work in progress, you're invited to log in and explore your portfolio, complete with real-time updates.

Implements
- Authentication
- Portfolio Holdings
- External(AngelOne SmarAPI) API / Socket connections using Tesla and Websockex
- binary data parsing via pattern matching
- syncing data feed from external web socket communication with Live view via broadcasting

Demo of streams : https://lnkd.in/dqpBTh5m

<div>
  <a href="https://www.loom.com/share/ccb5ea5a390e4f20b140a10824fd6941?sid=69a6e34f-f1a4-4321-a3ae-e404575170d1">
    <p>Demo of streaming data from websocket</p>
  </a>
  <img height="300" alt="Screenshot 2023-09-27 at 7 51 14 AM" src="https://github.com/pkrawat1/angel-trading/assets/3807725/345cfa75-f77b-4d26-acb6-2791bf932faa">
  <img height="300" alt="Screenshot 2023-09-27 at 8 02 31 AM" src="https://github.com/pkrawat1/angel-trading/assets/3807725/a5662719-7012-498e-bd44-dd75da0250f6">
  <a href="https://www.loom.com/share/ccb5ea5a390e4f20b140a10824fd6941">
    <img style="max-width:300px;" src="https://cdn.loom.com/sessions/thumbnails/ccb5ea5a390e4f20b140a10824fd6941-with-play.gif">
  </a>
</div>


To start your Phoenix server:

  * Create `.envrc` from `.envrc.example` and add required creds. Credentials can be created using [smartapi angel website](https://smartapi.angelbroking.com/).
  * [Enable TOPT](https://smartapi.angelbroking.com/enable-totp) using Google Authenticator app.
  * Run `mix setup` to install and setup dependencies
  * Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Learn more

  * Official website: https://www.phoenixframework.org/
  * Guides: https://hexdocs.pm/phoenix/overview.html
  * Docs: https://hexdocs.pm/phoenix
  * Forum: https://elixirforum.com/c/phoenix-forum
  * Source: https://github.com/phoenixframework/phoenix
