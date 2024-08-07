use rustler::NifStruct;
use tokio_test;
use yahoo_finance_api as yahoo;

#[derive(Debug, NifStruct)]
#[module = "YQuoteItem"]
struct YQuoteItem {
    long_name: String,
    symbol: String,
}

#[rustler::nif]
fn search(company_name: String) -> Result<Vec<YQuoteItem>, String> {
    let provider = yahoo::YahooConnector::new().unwrap();
    let resp = tokio_test::block_on(provider.search_ticker(&company_name));
    match resp {
        Ok(company_symbol) => {
            let company_symbol = company_symbol
                .quotes
                .iter()
                .filter(|q| q.exchange == "NSI")
                .map(|q| YQuoteItem {
                    long_name: q.long_name.clone(),
                    symbol: q.symbol.clone(),
                })
                .collect::<Vec<YQuoteItem>>();
            Ok(company_symbol)
        }
        Err(e) => Err(e.to_string()),
    }
}

rustler::init!("Elixir.AngelTrading.YahooFinance", [search]);
