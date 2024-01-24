defmodule AngelTrading.WebSocket do
  use TradeGalleon.Brokers.AngelOne.WebSocket,
    pub_sub_module: AngelTrading.PubSub
end
