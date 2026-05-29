defmodule AngelTrading.Agent do
  alias LangChain.{Message, MessageDelta, LangChainError}
  alias LangChain.Message.ContentPart
  alias LangChain.Chains.LLMChain
  alias LangChain.ChatModels.ChatGoogleAI
  alias AngelTrading.Client

  @init_messages [
    Message.new_system!(
      ~s(You are a helpful stock trading portfolio assistant.
      ONLY generate information with the given client information provided.
      NOTE that the currency is in india rupee. So use currency symbol, where money is involved.
      NOTE that the minus values are negative values and should be considered when doing calculations.
      NOTE always use proper format and distinctions when showing data. Use any markdown format for showing data properly, example tabular, list etc.
      NOTE all the questions will be related to the user's client. They are not the user's details but his/here clients info.)
    )
  ]

  @chat_model ChatGoogleAI.new!(%{
                stream: true,
                model: "gemini-3.5-flash"
              })
  @max_retries 5
  @initial_backoff_ms 500

  @doc """
  Creates a new language model chain with the specified context and functions.

  ## Parameters

    - context: A map containing the client token and live view process ID.

  ## Examples

      iex> context = %{client_token: "valid_token", live_view_pid: self()}
      iex> AngelTrading.Agent.new_chain(context)
      %LangChain.Chains.LLMChain{...}

  """
  @spec new_chain(map) :: LangChain.Chains.LLMChain.t()
  def new_chain(%{live_view_pid: live_view_pid} = context) do
    %{llm: @chat_model, custom_context: context, verbose: false}
    |> LLMChain.new!()
    |> LLMChain.add_messages(@init_messages)
    |> LLMChain.add_tools([
      Client.client_portfolio_info_function(),
      Client.search_stock_function(),
      Client.candle_data_function()
    ])
    |> LLMChain.add_callback(callback_handlers(live_view_pid))
  end

  # Attach callbacks once, at creation. add_callback/2 appends and the chain is reused across
  # turns, so registering per-run made turn N deliver every event N times.
  #
  # LangChain 0.8 vs 0.3: on_llm_new_delta receives a LIST of deltas (not one); the streaming
  # completion signal is on_message_processed (on_llm_end/on_llm_new_message are gone); and
  # message/delta content can be a list of ContentParts rather than a plain string.
  defp callback_handlers(live_view_pid) do
    %{
      on_llm_new_delta: fn _chain, deltas ->
        for %MessageDelta{} = delta <- List.wrap(deltas),
            text = extract_text(delta.content),
            text != "" do
          send(live_view_pid, {:chat_delta, text})
        end
      end,
      on_message_processed: fn _chain, message ->
        with %Message{role: :assistant, content: content} <- message,
             text when text != "" <- extract_text(content) do
          send(live_view_pid, {:chat_message, text})
        else
          _ -> :ok
        end
      end
    }
  end

  # Content in 0.8 is a string OR a list of ContentParts (text, thinking, …). Surface only the
  # user-visible :text parts so a thinking model's reasoning never leaks into the chat bubble.
  defp extract_text(content) when is_binary(content), do: content
  defp extract_text(%ContentPart{type: :text, content: text}) when is_binary(text), do: text
  defp extract_text(parts) when is_list(parts), do: Enum.map_join(parts, "", &extract_text/1)
  defp extract_text(_), do: ""

  @doc """
  Runs the specified language model chain and sends responses to the provided live view process.

  ## Parameters

  - chain: The language model chain to run.

  ## Examples

      iex> chain = AngelTrading.Agent.new_chain(%{client_token: "valid_token", live_view_pid: self()})
      iex> AngelTrading.Agent.run_chain(chain)
      :ok
  """
  @spec run_chain(LangChain.Chains.LLMChain.t()) ::
          {:ok, LangChain.Chains.LLMChain.t()} | {:error, binary}
  def run_chain(chain) do
    retry_with_backoff(chain, 0, @initial_backoff_ms)
  end

  defp retry_with_backoff(chain, retries, backoff_ms) when retries < @max_retries do
    try do
      chain
      |> LLMChain.run(mode: :while_needs_response)
      |> case do
        {:ok, updated_chain} ->
          {:ok, updated_chain}

        # 0.8 may return a 3-tuple {:ok, chain, last_message} on success.
        {:ok, updated_chain, _last_message} ->
          {:ok, updated_chain}

        # API failures (429, 400, overload, …) come back as {:error, chain, error}. Matching
        # only the 2-tuple {:error, reason} (as the original code did) let this fall through to
        # a `{:ok, result}` catch-all, so the LiveView stored the error tuple *as* the chain —
        # corrupting :llm_chain and crashing every following message in add_message/2.
        # Return a flat reason so the chain assign always stays a chain.
        {:error, _failed_chain, %LangChainError{message: message}} ->
          {:error, message}

        {:error, reason} ->
          {:error, reason}

        other ->
          {:error, "Unexpected response from the assistant: #{inspect(other)}"}
      end
    rescue
      _exception ->
        backoff_ms = backoff_ms * 2
        Process.sleep(backoff_ms)
        retry_with_backoff(chain, retries + 1, backoff_ms)
    end
  end

  defp retry_with_backoff(_chain, _retries, _backoff_ms) do
    {:error,
     "Uh-oh! Looks like our AI server's taking a coffee break. Hang tight and give it another shot in a bit!"}
  end
end
