address 0x42 {
module STC {
    use 0x1::Signer;
    use 0x2::Token;

    resource struct STC {}

    public fun register(signer: &signer)
    acquires STC {
        assert(Signer::address_of(signer) == token_address(), 42);
        let token = STC {};
        move_to(signer, token);
        let borrowed_token = borrow_global<STC>(Signer::address_of(signer));
        Token::register_currency(signer, borrowed_token, 1000, 1000);
        accept_stc(signer);
    }

    public fun mint(signer: &signer, amount: u64): Token::Coin<STC> {
        Token::mint<STC>(signer, amount, token_address())
    }

    public fun accept_stc(signer: &signer) {
        Token::accept_coin<STC>(signer, token_address());
    }

    public fun token_address(): address {
        0x42
    }
}
}