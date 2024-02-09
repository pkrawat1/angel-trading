# AngelTrading

Hey there, Elixir enthusiasts!

I developed this application as a personal passion project. The primary goal is to design a comprehensive dashboard that provides a centralized hub for managing and monitoring multiple portfolios, all accessible from a single device. While it's still a work in progress, you're invited to log in and explore your portfolio, complete with real-time updates.

Implements
- Authentication
- Portfolio Holdings
- External(AngelOne SmarAPI) API / Socket connections using Tesla and Websockex
- binary data parsing via pattern matching
- syncing data feed from external web socket communication with Live view via broadcasting

<div>
  <a href="https://www.loom.com/share/60816921d58245b6b5e1e33a96ec66a6?sid=a0380d2c-5934-4cfd-8244-c70f2cd90f39">
    <p>Demo of streaming data from websocket</p>
  </a>
  <img width="250" alt="Screenshot 2024-01-30 at 9 54 30 AM" src="https://github.com/pkrawat1/angel-trading/assets/3807725/423b8da0-c328-4914-9324-30af2871cc62">
  <img width="250" src="https://github.com/pkrawat1/angel-trading/assets/3807725/afcd4655-f50f-462b-b66e-738fb0808963">
  <img width="250" alt="Screenshot 2024-01-30 at 9 43 07 AM" src="https://github.com/pkrawat1/angel-trading/assets/3807725/cfa35d29-f6aa-42b3-b7e9-0f168a3af89c">
  <img width="250" alt="Screenshot 2024-01-30 at 9 43 49 AM" src="https://github.com/pkrawat1/angel-trading/assets/3807725/9f64b213-2f10-4ab6-b81d-94cdb274c767">
  <img width="250" alt="Screenshot 2024-01-30 at 9 44 42 AM" src="https://github.com/pkrawat1/angel-trading/assets/3807725/5955b351-0234-4138-93a6-04e847f62952">
  <img width="250" alt="Screenshot 2024-01-30 at 9 45 28 AM" src="https://github.com/pkrawat1/angel-trading/assets/3807725/96c928d6-b55a-4628-9373-99375dad35af">
  <img width="250" alt="Screenshot 2024-01-30 at 9 46 39 AM" src="https://github.com/pkrawat1/angel-trading/assets/3807725/355d3e44-3967-4d6d-b0f2-5117d6727c45">
  <img width="250" alt="Screenshot 2024-01-30 at 9 46 55 AM" src="https://github.com/pkrawat1/angel-trading/assets/3807725/d1a1b485-b1c8-4ddc-8567-eb88b22c5748">
  <a href="https://www.loom.com/share/ccb5ea5a390e4f20b140a10824fd6941">
    <img style="height:532px;" src="https://cdn.loom.com/sessions/thumbnails/ccb5ea5a390e4f20b140a10824fd6941-with-play.gif">
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
