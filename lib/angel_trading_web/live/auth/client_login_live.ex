defmodule AngelTradingWeb.ClientLoginLive do
  use AngelTradingWeb, :live_view
  alias AngelTrading.{API, Account}

  def mount(_params, %{"user_hash" => user_hash}, socket) do
    {:ok, assign(socket, page_title: "New Client", user_hash: user_hash)}
  end

  def handle_params(params, _url, socket) do
    {:noreply, assign(socket, params: params)}
  end

  def render(assigns) do
    ~H"""
    <div class="flex m-auto max-w-6xl px-4 sm:px-6 lg:px-8 justify-center">
      <.simple_form :let={f} for={%{}} as={:user} autocomplete="off" phx-submit="login">
        <.input field={f[:client_code]} value={@params["client_code"]} placeholder="Client code" />
        <.input
          field={f[:password]}
          type="password"
          value={@params["password"]}
          placeholder="Pin"
          maxlength="4"
          minlength="4"
        />
        <.input field={f[:totp_secret]} value={@params["totp_secret"]} placeholder="Totp secret" />
        <.input field={f[:api_key]} value={@params["api_key"]} placeholder="API key" />
        <.input
          field={f[:secret_key]}
          type="password"
          value={@params["secret_key"]}
          placeholder="Secret key"
        />
        <.input
          field={f[:proxy_url]}
          value={@params["proxy_url"]}
          placeholder="Proxy URL (e.g. http://103.210.12.49:5977/)"
        />
        <:actions>
          <.button class="w-full dark:bg-gray-500">ADD CLIENT</.button>
        </:actions>
      </.simple_form>
      <.bottom_nav active_page={:client} />
    </div>
    """
  end

  def handle_event(
        "login",
        %{
          "user" =>
            %{
              "client_code" => client_code,
              "password" => password,
              "totp_secret" => totp_secret,
              "api_key" => api_key,
              "secret_key" => secret_key,
              "proxy_url" => proxy_url
            } = params
        },
        socket
      )
      when bit_size(client_code) != 0 and bit_size(password) != 0 and
             bit_size(totp_secret) != 0 and bit_size(api_key) != 0 and
             bit_size(secret_key) != 0 do
    # Explicit config map — used for first-time registration before ETS is populated.
    client_config = %{
      api_key: api_key,
      secret_key: secret_key,
      proxy_url: if(proxy_url == "", do: nil, else: proxy_url)
    }

    with {:ok, totp} <- AngelTrading.TOTP.totp_now(totp_secret),
         {:ok,
          %{
            "data" => %{
              jwt_token: token,
              refresh_token: refresh_token,
              feed_token: feed_token
            }
          }} <-
           API.login(client_config, %{
             client_code: client_code,
             password: password,
             totp: totp
           }),
         :ok <-
           Account.set_tokens(socket.assigns.user_hash, %{
             "client_code" => client_code,
             "token" => token,
             "refresh_token" => refresh_token,
             "feed_token" => feed_token,
             "pin" => password,
             "totp_secret" => totp_secret,
             "api_key" => api_key,
             "secret_key" => secret_key,
             "proxy_url" => proxy_url
           }) do
      {:noreply,
       socket
       |> put_flash(:info, "Client #{client_code} added successfully.")
       |> push_navigate(to: ~p"/")}
    else
      {:error, error} ->
        message =
          case error do
            <<message::binary>> -> message
            %{"message" => message} -> message
            _ -> "Unexpected error. Please try again."
          end

        {:noreply,
         socket
         |> push_patch(to: ~p"/client/login?#{params}")
         |> put_flash(:error, message)}
    end
  end

  def handle_event("login", %{"user" => params}, socket) do
    {:noreply,
     socket
     |> push_patch(to: ~p"/client/login?#{params}")
     |> put_flash(:error, "Client code, pin, totp secret, API key and secret key are required.")}
  end
end
