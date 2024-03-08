defmodule AngelTradingWeb.AskLive do
  use AngelTradingWeb, :live_view
  alias AngelTrading.{Account, SmartChat, Utils}
  alias LangChain.Message
  alias Phoenix.LiveView.AsyncResult
  require Logger

  embed_templates "*"

  def mount(
        %{"client_code" => client_code},
        %{"user_hash" => user_hash},
        socket
      ) do
    client_code = String.upcase(client_code)

    user_clients =
      case Account.get_client_codes(user_hash) do
        {:ok, %{body: data}} when is_map(data) -> Map.values(data)
        _ -> []
      end

    socket =
      with true <- client_code in user_clients,
           {:ok, %{body: client_data}} when is_binary(client_data) <-
             Account.get_client(client_code),
           {:ok,
            %{
              token: token,
              client_code: client_code
            }} <- Utils.decrypt(:client_tokens, client_data) do
        socket
        |> assign(:page_title, "Smart Assistant")
        |> assign(:token, token)
        |> assign(:client_code, client_code)
        |> assign(:lang_chain, AsyncResult.loading())
        |> start_async(:ask_lang_chain, fn -> SmartChat.new_chain(%{client_token: token}) end)
        |> stream_configure(:messages, dom_id: &"message-#{:erlang.phash2(&1.content)}")
        |> stream(:messages, [])
      else
        _ ->
          socket
          |> put_flash(:error, "Invalid client")
          |> push_navigate(to: "/")
      end

    {:ok, socket}
  end

  def handle_async(:ask_lang_chain, {:ok, {_, lang_chain, response}}, socket) do
    {:noreply,
     socket
     |> assign(:lang_chain, AsyncResult.ok(socket.assigns.lang_chain, lang_chain))
     |> stream_insert(:messages, response)}
  end

  def handle_async(:ask_lang_chain, {:exit, _}, socket) do
    {:noreply,
     assign(
       socket,
       :lang_chain,
       AsyncResult.failed(socket.assigns.lang_chain, {:exit, "Seems AI is stuck in traffic."})
     )}
  end

  def handle_event(
        "ask",
        %{"ask" => message},
        %{assigns: %{lang_chain: %{result: lang_chain}}} = socket
      )
      when bit_size(message) > 0 do
    message = Message.new_user!(message)

    {:noreply,
     socket
     |> assign(:lang_chain, AsyncResult.loading())
     |> start_async(:ask_lang_chain, fn ->
       SmartChat.run(lang_chain, [message], [])
     end)
     |> stream_insert(:messages, message)}
  end

  def handle_event(
        "ask",
        _,
        socket
      ),
      do: {:noreply, socket}
end
