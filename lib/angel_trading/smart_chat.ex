defmodule AngelTrading.SmartChat do
  alias LangChain.{Function, Message}
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
    ),
    Message.new_user!("As first reply, tell me the client name and funds information.")
  ]

  @chat_model ChatGoogleAI.new!(%{endpoint: "https://generativelanguage.googleapis.com/"})

  def client_portfolio_info do
    Function.new!(%{
      name: "get_client_portfolio_info",
      description: "Return JSON object of the client's information.",
      function: fn _args, %{client_token: token} = _context ->
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
      |> LLMChain.run(while_needs_response: true)

  def run(updated_chain, messages, functions),
    do:
      updated_chain
      |> LLMChain.add_messages(messages)
      |> LLMChain.add_functions(functions)
      |> LLMChain.run(while_needs_response: true)
end
