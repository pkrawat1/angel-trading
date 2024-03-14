defmodule AngelTrading.Agent do
  alias LangChain.{Function, Message, MessageDelta}
  alias LangChain.MessageDelta
  alias LangChain.Chains.LLMChain
  alias LangChain.ChatModels.ChatGoogleAI
  alias AngelTrading.{API, Client, Utils, YahooFinance}

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
          case Client.get_client_portfolio_info(token) do
            {:ok, %{profile: profile, funds: funds} = portfolio} ->
              %{portfolio | profile: Map.take(profile, ["name"]), funds: Map.take(funds, ["net"])}

            _ ->
              %{error: "Unable to fetch the client portfolio."}
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
      function: fn %{"name" => name}, %{client_token: token, live_view_pid: pid} = _context ->
        send(pid, {:function_run, "Retrieving stock information for #{name}"})

        Jason.encode!(
          case Client.search_stock(name, token) do
            {:ok, result} -> result
            _ -> %{error: "No match found for the name."}
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
          },
          trading_symbol: %{
            type: "string",
            description: "Trading symbol for the stock found in the stock details details"
          }
        },
        required: ["exchange", "symbol_token"]
      },
      function: fn %{
                     "exchange" => exchange,
                     "symbol_token" => symbol_token,
                     "trading_symbol" => trading_symbol
                   },
                   %{client_token: token, live_view_pid: pid} = _context ->
        send(pid, {:function_run, "Retrieving candle data information for #{trading_symbol}"})

        Jason.encode!(
          case Client.get_candle_data(exchange, symbol_token, token) do
            {:ok, result} -> result
            _ -> %{error: "Unable to fetch the candle data."}
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

  def run_chain(%{custom_context: %{live_view_pid: live_view_pid}} = chain, retry \\ 0) do
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

    try do
      LLMChain.run(chain, while_needs_response: true, callback_fn: callback_fn)
    rescue
      _ ->
        if retry < 3 do
          run_chain(chain, retry + 1)
        else
          {:error,
           "Uh-oh! Looks like our AI server's taking a coffee break. Hang tight and give it another shot in a bit!"}
        end
    end
  end
end
