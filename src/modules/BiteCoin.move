address 0x1 {
    module BiteCoin {
        use 0x1::Token;
        use 0x1::LibraBlock as Block;
        use 0x1::Signer;

        const TOKEN_ADDRESS: address = 0x1;

        const COIN: u64 = 100000000;

        /// Total Supply: 21 million * 2.
        const TOTAL_SUPPLY: u64 = 21000000 * 2;

        /// Initial Mint: 21 million. (50% of the total supply)
        const INITIAL_MINT_AMOUNT:u64 = 21000000;

        /// every 21w block, can mint 21w * `block_subsidy` to issuer.
        const HALVING_INTERVAL: u64 = 210000;

        const INITIAL_SUBSIDY: u64 = 50;

        /// CoinType
        resource struct T { }
        resource struct Balance {
            coin: Token::Coin<T>,
        }

        resource struct MintManager {
            mint_cap: Token::MintCapability<T>,
            mint_times: u64,
            start_block_height: u64,
        }

        public fun initialize(signer: &signer) {
            assert(Signer::address_of(signer) == TOKEN_ADDRESS, 401);
            let t = T {};
            // register currency.
            Token::register_currency<T>(signer, &t, 1000, 1000);
            // Mint to myself at the beginning.
            let minted_token = Token::mint(signer, INITIAL_MINT_AMOUNT * COIN, TOKEN_ADDRESS);

            let balance = Balance { coin: minted_token };
            move_to(signer, balance);

            let mint_cap = Token::remove_my_mint_capability<T>(signer);
            let block_height = Block::get_current_block_height();

            let mint_manager = MintManager {
                mint_cap,
                mint_times: 0,
                start_block_height: block_height,
            };

            move_to(signer, mint_manager);

            // destroy T, so that no one can mint. (except this contract)
            let T{  } = t;
        }

        /// anyone can trigger a mint action if it's time to mint.
        public fun trigger_mint(_signer: &signer) acquires Balance, MintManager {
            let current_block_height = Block::get_current_block_height();

            let mint_manager = borrow_global_mut<MintManager>(TOKEN_ADDRESS);
            let interval = current_block_height - mint_manager.start_block_height;
            let halvings = interval / HALVING_INTERVAL;
            let mint_times = mint_manager.mint_times;
            assert(mint_times <= halvings, 500);
            if (halvings == mint_times) {
                return
            };

            if (mint_times >= 64) {
                return
            };

            let mint_amount = HALVING_INTERVAL * (INITIAL_SUBSIDY * COIN >> (mint_times as u8));
            mint_manager.mint_times = mint_manager.mint_times + 1;

            if (mint_amount == 0) {
                return
            };

            let minted_token = Token::mint_with_capability(mint_amount, TOKEN_ADDRESS, &mint_manager.mint_cap);
            let issuer_balance = borrow_global_mut<Balance>(TOKEN_ADDRESS);
            Token::deposit(&mut issuer_balance.coin, minted_token);
        }

        /// Get the balance of `user`
        public fun balance(_signer: &signer, user: address): u64 acquires Balance {
            let balance_ref = borrow_global<Balance>(user);
            Token::value(&balance_ref.coin)
        }
    }
}