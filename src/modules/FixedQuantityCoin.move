address 0x1 {
/**
    Fixed Quantity Token Example.
    Token Issuer register the token, and mint the specified token to himself.
    After this, no one can mint again, even token issuer himself.
    Toekn issuer can dispatch the minted token to others.
*/
module FixedQuantityCoin {
    use 0x1::Token;
    use 0x1::Signer;

    /// CoinType of FixedQuantityCoin
    resource struct T { }

    resource struct Balance {
        coin: Token::Coin<T>,
    }

    const TOKEN_ADDRESS: address = 0x1;
    /// Total Supply: 100 million.
    const TOTAL_SUPPLY: u64 = 100000000;

    /// Initialize method of the FixedQuantityCoin.
    /// should only be called once by the Token Issuer.
    public fun initialize(signer: &signer) {
        assert(Signer::address_of(signer) == TOKEN_ADDRESS, 401);
        let t = T {};
        // register currency.
        Token::register_currency<T>(signer, &t, 1000, 1000);
        // Mint all to myself at the beginning.
        let minted_token = Token::mint(signer, TOTAL_SUPPLY, TOKEN_ADDRESS);
        let balance = Balance { coin: minted_token };
        move_to(signer, balance);
        // destroy mint cap from myself.
        let mint_cap = Token::remove_my_mint_capability<T>(signer);
        Token::destroy_mint_capability(mint_cap);
        // destroy T, so that no one can mint.
        let T{  } = t;
    }

    /// `Signer` calls this method to accept the Coin.
    public fun accept(signer: &signer) {
        let zero_coin = Token::zero<T>();
        let b = Balance { coin: zero_coin };
        move_to(signer, b)
    }

    /// Get the balance of `user`
    public fun balance(_signer: &signer, user: address): u64 acquires Balance {
        let balance_ref = borrow_global<Balance>(user);
        Token::value(&balance_ref.coin)
    }

    /// Transfer `amount` of Coin from `signer` to `receiver`.
    public fun transfer_to(signer: &signer, receiver: address, amount: u64)
    acquires Balance {
        let my_balance = borrow_global_mut<Balance>(Signer::address_of(signer));
        let withdrawed_token = Token::withdraw(&mut my_balance.coin, amount);
        let receiver_balance = borrow_global_mut<Balance>(receiver);
        Token::deposit(&mut receiver_balance.coin, withdrawed_token);
    }
}
}