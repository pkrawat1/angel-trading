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
  <a href="https://www.loom.com/share/3244b916cdeb4f1d8333b0e325e5b19b">
    <p>Demo of AI assistant</p>
  </a>
  <img width="250" alt="Screenshot 2024-01-30 at 9 54 30 AM" src="https://github.com/user-attachments/assets/7fcb3e81-5dd9-47ae-b4c7-4d1fc3109eb4">
  <img width="250" alt="Screenshot 2024-09-04 at 7 32 36 PM" src="https://github.com/user-attachments/assets/d007b50f-dc67-482c-9aa3-7d1d68ddc69e">
  <img width="250" alt="Screenshot 2024-09-04 at 7 34 34 PM" src="https://github.com/user-attachments/assets/4a5d429e-0a10-465e-881e-ad752703059c">
  <img width="250" alt="Screenshot 2024-09-04 at 7 35 46 PM" src="https://github.com/user-attachments/assets/99c936a2-f365-4671-b85d-531fd8688a34">
  <img width="250" alt="Screenshot 2024-09-04 at 7 36 51 PM" src="https://github.com/user-attachments/assets/3c912ab9-9ee7-4dbb-9a49-53bb00e14ed9">
  <img width="250" alt="Screenshot 2024-09-04 at 7 38 24 PM" src="https://github.com/user-attachments/assets/82164a7f-3637-473c-b246-5b5634c6637b">
  <img width="250" alt="Screenshot 2024-09-04 at 7 41 05 PM" src="https://github.com/user-attachments/assets/e4d97c47-6d5c-4298-a66b-9870cea7597e">
  <img width="250" alt="Screenshot 2024-09-04 at 7 43 29 PM" src="https://github.com/user-attachments/assets/bb01042e-2f4a-4cb2-943f-93e8f48e5eac">
  <img width="250" alt="Screenshot 2024-01-30 at 9 46 39 AM" src="https://github.com/pkrawat1/angel-trading/assets/3807725/355d3e44-3967-4d6d-b0f2-5117d6727c45">
  <img width="250" alt="Screenshot 2024-01-30 at 9 46 55 AM" src="https://github.com/pkrawat1/angel-trading/assets/3807725/d1a1b485-b1c8-4ddc-8567-eb88b22c5748">
  <a href="https://www.loom.com/share/60816921d58245b6b5e1e33a96ec66a6?sid=a0380d2c-5934-4cfd-8244-c70f2cd90f39">
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
