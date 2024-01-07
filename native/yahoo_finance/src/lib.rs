use tokio_test;
use yahoo_finance_api as yahoo;

#[rustler::nif]
fn search(company_name: String) -> Result<Vec<String>, String> {
    let provider = yahoo::YahooConnector::new();
    let company_symbol = tokio_test::block_on(provider.search_ticker(&company_name))
        .unwrap()
        .quotes
        .iter()
        .filter(|q| q.exchange == "NSI")
        .map(|q| {
            format!(
                "{} -> {}",
                q.symbol
                    .clone()
                    .split(".")
                    .collect::<Vec<&str>>()
                    .first()
                    .unwrap(),
                q.long_name
            )
        })
        .collect();
    Ok(company_symbol)
}

rustler::init!("Elixir.AngelTrading.YahooFinance", [search]);
