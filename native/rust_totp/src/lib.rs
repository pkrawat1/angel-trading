use totp_rs::{Algorithm, Secret, TOTP};

#[rustler::nif]
fn totp_now(secret: String) -> Result<String, String> {
    match TOTP::new(
        Algorithm::SHA1,
        6,
        1,
        30,
        Secret::Encoded(secret).to_bytes().unwrap(),
    ) {
        Ok(totp) => Ok(totp.generate_current().unwrap()),
        _ => Err("Invalid totp secret".to_string()),
    }
}

rustler::init!("Elixir.AngelTrading.TOTP", [totp_now]);
