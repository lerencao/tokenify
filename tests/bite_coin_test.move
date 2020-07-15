//! account: alice, 0x1
//! account: bob

//! new-transaction
//! sender: alice

script {
    use 0x1::BiteCoin;
    fun main(signer: &signer) {
        BiteCoin::initialize(signer);
    }
}

// check: EXECUTED

//! new-transaction
//! sender: bob

script {
    use 0x1::BiteCoin;
    use 0x1::Token;
    use 0x1::Balance;
    fun main(signer: &signer) {
        let total = Token::market_cap<BiteCoin::T>(BiteCoin::token_address());
        let founder_amount = BiteCoin::balance({{alice}});
        assert((founder_amount as u128) == total, 100);

        Balance::accept_token<BiteCoin::T>(signer);

    }
}
// check: EXECUTED


//! new-transaction
//! sender: alice

script {
    use 0x1::BiteCoin;
    fun main(signer: &signer) {
        BiteCoin::transfer_to(signer, {{bob}}, 1000);
    }
}

// check: EXECUTED


//! new-transaction
//! sender: bob
script {
    use 0x1::BiteCoin;
    use 0x1::Signer;
    fun main(signer: &signer) {
        let my_balance = BiteCoin::balance(Signer::address_of(signer));
        assert(my_balance == 1000, 101);
        BiteCoin::burn(signer, 500);
        assert(BiteCoin::balance(Signer::address_of(signer)) == 500, 102);
    }
}
