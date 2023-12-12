use totp_rs::{Algorithm, Secret, TOTP};

#[rustler::nif]
fn totp_now(secret: String) -> String {
    let totp = TOTP::new(
        Algorithm::SHA1,
        6,
        1,
        30,
        Secret::Encoded(secret).to_bytes().unwrap(),
    )
    .unwrap();
    totp.generate_current().unwrap()
}

rustler::init!("Elixir.AngelTrading.TOTP", [totp_now]);
