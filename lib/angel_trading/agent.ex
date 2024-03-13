defmodule AngelTrading.Agent do
  alias LangChain.{Function, Message, MessageDelta}
  alias LangChain.MessageDelta
  alias LangChain.Chains.LLMChain
  alias LangChain.ChatModels.ChatGoogleAI
  alias AngelTrading.{API, Utils, YahooFinance}

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

  def search_stock do
    Function.new!(%{
      name: "search_stock_details",
      description:
        "Return JSON object of the stock details including symbol, token, exchange etc.",
      parameters_schema: %{
        type: "object",
        properties: %{
          name: %{type: "string", description: "Stock Name"}
        },
        required: ["name"]
      },
      function: fn %{"name" => name}, %{client_token: token} = _context ->
        Jason.encode!(
          case YahooFinance.search(name) do
            {:ok, yahoo_quotes} when yahoo_quotes != [] ->
              token_list =
                yahoo_quotes
                |> Enum.map(
                  &(&1.symbol
                    |> String.slice(0..(String.length(name) - 1))
                    |> String.split(".")
                    |> List.first())
                )
                |> MapSet.new()
                |> Enum.map(&API.search_token(token, "NSE", &1))
                |> Enum.flat_map(fn
                  {:ok, %{"data" => token_list}} -> token_list
                  _ -> []
                end)
                |> Enum.uniq_by(& &1["tradingsymbol"])
                |> Enum.filter(&String.ends_with?(&1["tradingsymbol"], "-EQ"))
                |> Enum.map(
                  &(&1
                    |> Map.put_new("name", Utils.stock_long_name(&1["tradingsymbol"])))
                )

              %{
                token_list: token_list
              }

            _ ->
              %{error: "No match found for the name."}
          end
        )
      end
    })
  end

  def candle_data do
    Function.new!(%{
      name: "get_candle_data",
      description:
        "Return JSON object of the candle data (RSI) for a stock recorded in 1 week time with 1 hour gap.",
      parameters_schema: %{
        type: "object",
        properties: %{
          exchange: %{type: "string", description: "Exchange name"},
          symbol_token: %{
            type: "string",
            description: "Symbol token is numeric code for the stock found in stock detail"
          }
        },
        required: ["exchange", "symbol_token"]
      },
      function: fn %{"exchange" => exchange, "symbol_token" => symbol_token},
                   %{client_token: token} = _context ->
        Jason.encode!(
          with {:ok, %{"data" => candle_data}} <-
                 API.candle_data(
                   token,
                   exchange,
                   symbol_token,
                   "ONE_HOUR",
                   Timex.now("Asia/Kolkata")
                   |> Timex.shift(weeks: -1)
                   |> Timex.format!("{YYYY}-{0M}-{0D} {h24}:{0m}"),
                   Timex.now("Asia/Kolkata")
                   |> Timex.shift(days: 1)
                   |> Timex.format!("{YYYY}-{0M}-{0D} {h24}:{0m}")
                 ) do
            %{
              candle_data: Utils.formatted_candle_data(candle_data)
            }
          else
            e ->
              IO.inspect(e)
              %{error: "Unable to fetch the candle data."}
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
      |> LLMChain.add_functions([search_stock(), client_portfolio_info(), candle_data()])

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

          :ok

        %Message{} = data ->
          send(live_view_pid, {:chat_response, data})

          :ok

        {:error, _reason} ->
          :error
      end

    LLMChain.run(chain, while_needs_response: true, callback_fn: callback_fn)
  end
end
