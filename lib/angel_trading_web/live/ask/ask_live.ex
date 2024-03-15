defmodule AngelTradingWeb.AskLive do
  use AngelTradingWeb, :live_view
  alias AngelTrading.{Account, Agent, Utils}
  alias Phoenix.LiveView.AsyncResult
  alias AngelTrading.Agent.ChatMessage
  alias LangChain.{Message, MessageDelta}
  alias LangChain.Chains.LLMChain
  require Logger

  embed_templates "*"

  @impl true
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
        |> assign(:llm_chain, Agent.new_chain(%{client_token: token, live_view_pid: self()}))
        |> stream_configure(:display_messages, dom_id: &"message-#{:erlang.phash2(&1.content)}")
        |> stream(:display_messages, [
          %ChatMessage{
            role: :assistant,
            hidden: false,
            content: "Hello! I'm your personal Assistant! How can I help you today?"
          }
        ])
        |> assign(:delta, nil)
        |> reset_chat_message_form()
        |> assign(:async_result, AsyncResult.ok(%AsyncResult{}, :ok))
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
          |> run_chain()

        {:error, changeset} ->
          assign_form(socket, changeset)
      end

    {:noreply, socket}
  end

  def handle_event("retry", _, socket) do
    {:noreply, run_chain(socket)}
  end

  @impl true
  def handle_info({:chat_response, %MessageDelta{} = delta}, socket) do
    socket = handle_chat_response(socket, delta)
    {:noreply, socket}
  end

  def handle_info({:function_run, message}, socket) do
    display = %ChatMessage{
      role: :function_call,
      hidden: false,
      content: message
    }

    {:noreply, append_display_message(socket, display)}
  end

  def handle_info({:llm_error, message}, socket) do
    socket =
      socket
      |> put_flash(:error, message)

    {:noreply, socket}
  end

  def handle_info(_, socket) do
    {:noreply, socket}
  end

  def handle_async(:running_llm, {:ok, {:ok, chain, _last_response} = _success_result}, socket) do
    socket =
      socket
      |> assign(:async_result, AsyncResult.ok(%AsyncResult{}, :ok))
      |> assign(:llm_chain, chain)

    {:noreply, socket}
  end

  def handle_async(:running_llm, {:ok, {:error, reason}}, socket) do
    socket =
      socket
      |> put_flash(:error, reason)
      |> assign(:async_result, AsyncResult.failed(%AsyncResult{}, reason))

    {:noreply, socket}
  end

  def handle_async(:running_llm, {:exit, reason}, socket) do
    socket =
      socket
      |> put_flash(:error, "Call failed: #{inspect(reason)}")
      |> assign(:async_result, %AsyncResult{})

    {:noreply, socket}
  end

  def run_chain(socket) do
    socket
    |> start_async(:running_llm, fn -> Agent.run_chain(socket.assigns.llm_chain) end)
    |> assign(:async_result, AsyncResult.loading())
  end

  defp add_user_message(socket, user_text) when is_binary(user_text) do
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

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp handle_chat_response(socket, %MessageDelta{} = delta) do
    case delta do
      %MessageDelta{role: role, content: content, status: :complete}
      when role in [:user, :assistant] and is_binary(content) ->
        socket
        |> append_display_message(%ChatMessage{role: role, content: content})
        |> assign(:delta, nil)

      _ ->
        content = Map.get(socket.assigns.delta || %{}, :content, "") <> (delta.content || "")
        assign(socket, :delta, %MessageDelta{delta | content: content})
    end
  end
end
