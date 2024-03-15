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
                endpoint: "https://generativelanguage.googleapis.com/"
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
    |> LLMChain.add_functions([
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
  @spec run_chain(LangChain.Chains.LLMChain.t()) :: :ok | {:error, binary}
  def run_chain(%{custom_context: %{live_view_pid: live_view_pid}} = chain) do
    callback_fn =
      fn
        %MessageDelta{} = delta ->
          send(live_view_pid, {:chat_response, delta})

        %Message{role: role} = data when role == :assistant ->
          send(
            live_view_pid,
            {:chat_response, struct(MessageDelta, Map.from_struct(data))}
          )

        :ok ->
          :ok

        %Message{} = data ->
          send(live_view_pid, {:chat_response, data})

        {:error, _reason} ->
          :error
      end

    retry_with_backoff(chain, callback_fn, 0, @initial_backoff_ms)
  end

  defp retry_with_backoff(chain, callback_fn, retries, backoff_ms) when retries < @max_retries do
    try do
      LLMChain.run(chain, while_needs_response: true, callback_fn: callback_fn)
    rescue
      _ ->
        backoff_ms = backoff_ms * 2
        Process.sleep(backoff_ms)
        retry_with_backoff(chain, callback_fn, retries + 1, backoff_ms)
    end
  end

  defp retry_with_backoff(_chain, _callback_fn, _retries, _backoff_ms) do
    {:error,
     "Uh-oh! Looks like our AI server's taking a coffee break. Hang tight and give it another shot in a bit!"}
  end
end
