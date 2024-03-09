defmodule AngelTradingWeb.AskLive do
  use AngelTradingWeb, :live_view
  alias AngelTrading.{Account, Agent, Utils}
  alias Phoenix.LiveView.AsyncResult
  alias AngelTrading.Agent.ChatMessage
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
        |> assign(:llm_chain, SmartChat.new_chain(%{client_token: token, live_view_pid: self()}))
        |> stream_configure(:messages, dom_id: &"message-#{:erlang.phash2(&1.content)}")
        |> stream(:display_messages, [
          %ChatMessage{
            role: :assistant,
            hidden: false,
            content: "Hello! I'm your personal Assistant! How can I help you today?"
          }
        ])
        |> reset_chat_message_form()
      else
        _ ->
          socket
          |> put_flash(:error, "Invalid client")
          |> push_navigate(to: "/")
      end

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", %{"chat_message" => params}, socket) do
    changeset =
      params
      |> ChatMessage.create_changeset()
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"chat_message" => params}, socket) do
    socket =
      case ChatMessage.new(params) do
        {:ok, %ChatMessage{} = message} ->
          socket
          |> add_user_message(message.content)
          |> reset_chat_message_form()
          |> start_async(:running_llm, Agent.run_chain(socket.assigns.llm_chain))

        {:error, changeset} ->
          assign_form(socket, changeset)
      end

    {:noreply, socket}
  end

  def handle_event(
        "ask",
        _,
        socket
      ),
      do: {:noreply, socket}

  @impl true
  def handle_info({:chat_response, %LangChain.MessageDelta{} = delta}, socket) do
    # apply the delta message to our tracked LLMChain. If it completes the
    # message, optionally display the message
    updated_chain = LLMChain.apply_delta(socket.assigns.llm_chain, delta)
    # if this completed the delta, create the message and track on the chain
    socket =
      if updated_chain.delta == nil do
        case updated_chain.last_message do
          # Messages that only execute a function have no content. Don't display if no content.
          %Message{role: role, content: content}
          when role in [:user, :assistant] and is_binary(content) ->
            append_display_message(socket, %ChatMessage{role: role, content: content})

          # otherwise, not a message for display
          _other ->
            socket
        end
      else
        socket
      end

    {:noreply, assign(socket, :llm_chain, updated_chain)}
  end

  def handle_info({:function_run, message}, socket) do
    display = %ChatMessage{
      role: :function_call,
      hidden: false,
      content: message
    }

    {:noreply, append_display_message(socket, display)}
  end

  def handle_info(_, socket) do
    {:noreply, socket}
  end

  defp add_user_message(socket, user_text) when is_binary(user_text) do
    # NOT the first message. Submit the user's text as-is.
    updated_chain = LLMChain.add_message(socket.assigns.llm_chain, Message.new_user!(user_text))

    socket
    |> assign(llm_chain: updated_chain)
    |> append_display_message(%ChatMessage{role: :user, content: user_text})
  end

  defp reset_chat_message_form(socket) do
    changeset = ChatMessage.create_changeset(%{})
    assign_form(socket, changeset)
  end

  defp append_display_message(socket, %ChatMessage{} = message) do
    stream_insert(socket, :display_messages, message)
  end
end
