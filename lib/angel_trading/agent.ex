defmodule AngelTrading.Agent do
  alias LangChain.{Function, Message, MessageDelta}
  alias LangChain.MessageDelta
  alias LangChain.Chains.LLMChain
  alias LangChain.ChatModels.ChatGoogleAI
  alias AngelTrading.{API, Utils}

  @init_messages [
    Message.new_system!(
      ~s(You are a helpful stock trading portfolio assistant.
      ONLY generate information with the given client information provided.
      NOTE that the currency is in india rupee. So use currency symbol, where money is involved.
      NOTE that the minus values are negative values and should be considered when doing calculations.
      NOTE always use proper format and distinctions when showing data. Use any markdown format for showing data properly, example tabular, list etc.)
    )
  ]

  @chat_model ChatGoogleAI.new!(%{
                stream: true,
                endpoint: "https://generativelanguage.googleapis.com/"
              })

  def client_portfolio_info do
    Function.new!(%{
      name: "get_client_portfolio_info",
      description: "Return JSON object of the client's information.",
      function: fn _args, %{client_token: token, live_view_pid: pid} = _context ->
        send(pid, {:function_run, "Retrieving client portfolio information."})

        Jason.encode!(
          with {:profile, {:ok, %{"data" => profile}}} <- {:profile, API.profile(token)},
               {:portfolio, {:ok, %{"data" => holdings}}} <-
                 {:portfolio, API.portfolio(token)},
               {:funds, {:ok, %{"data" => funds}}} <- {:funds, API.funds(token)} do
            %{
              profile: Map.take(profile, ["name"]),
              holdings:
                holdings
                |> Utils.formatted_holdings()
                |> Utils.calculated_overview(),
              funds: Map.take(funds, ["net"])
            }
          else
            _ -> %{error: "Unable to fetch the client portfolio."}
          end
        )
      end
    })
  end

  def new_chain(context),
    do:
      %{llm: @chat_model, custom_context: context, verbose: false}
      |> LLMChain.new!()
      |> LLMChain.add_messages(@init_messages)
      |> LLMChain.add_functions([client_portfolio_info()])

  def run_chain(%{custom_context: %{live_view_pid: live_view_pid}} = chain) do
    callback_fn =
      fn
        %MessageDelta{} = delta ->
          send(live_view_pid, {:chat_response, delta})

        %Message{role: role} = data when role == :assistant ->
          send(
            live_view_pid,
            {:chat_response, struct(MessageDelta, %{Map.from_struct(data) | content: ""})}
          )

          :ok

        %Message{} = data ->
          send(live_view_pid, {:chat_response, data})

          :ok

        {:error, _reason} ->
          :error
      end

    dbg()
    case LLMChain.run(chain, while_needs_response: true, callback_fn: callback_fn) do
      # Don't return a large success result. Callbacks return what we want.
      {:ok, _updated_chain, _last_message} ->
        :ok

      # return the errors for display
      {:error, reason} ->
        {:error, reason}
    end
  end
end
