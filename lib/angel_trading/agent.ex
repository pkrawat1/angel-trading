defmodule AngelTrading.Agent do
  alias LangChain.{Message, MessageDelta}
  alias LangChain.MessageDelta
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
                model: "gemini-2.0-flash"
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
  def new_chain(context) do
    %{llm: @chat_model, custom_context: context, verbose: false}
    |> LLMChain.new!()
    |> LLMChain.add_messages(@init_messages)
    |> LLMChain.add_tools([
      Client.client_portfolio_info_function(),
      Client.search_stock_function(),
      Client.candle_data_function()
    ])
  end

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
  def run_chain(%{custom_context: %{live_view_pid: live_view_pid}} = chain) do
    callback_handlers = %{
      on_llm_new_delta: fn _chain, delta ->
        send(live_view_pid, {:chat_response, delta})
      end,
      on_llm_new_message: fn _chain, data ->
        send(
          live_view_pid,
          {:chat_response, struct(MessageDelta, Map.from_struct(data))}
        )
      end,
      on_llm_end: fn _, _ ->
        :ok
      end,
      on_llm_error: fn _, _reason ->
        :error
      end,
      on_llm_start: fn _, _ ->
        IO.inspect("LLM started")
      end
    }

    retry_with_backoff(chain, callback_handlers, 0, @initial_backoff_ms)
  end

  defp retry_with_backoff(chain, callback_handlers, retries, backoff_ms)
       when retries < @max_retries do
    try do
      result =
        chain
        |> LLMChain.add_callback(callback_handlers)
        |> LLMChain.run(mode: :while_needs_response)

      case result do
        {:ok, updated_chain} -> {:ok, updated_chain}
        %LangChain.Chains.LLMChain{} = updated_chain -> {:ok, updated_chain}
        {:error, reason} -> {:error, reason}
        _ -> {:ok, result}
      end
    rescue
      _exception ->
        backoff_ms = backoff_ms * 2
        Process.sleep(backoff_ms)
        retry_with_backoff(chain, callback_handlers, retries + 1, backoff_ms)
    end
  end

  defp retry_with_backoff(_chain, _callback_handlers, _retries, _backoff_ms) do
    {:error,
     "Uh-oh! Looks like our AI server's taking a coffee break. Hang tight and give it another shot in a bit!"}
  end
end
