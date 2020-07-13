address 0x1 {
module Token {
    use 0x1::Event;
    use 0x1::Signer;

    /// The currency has a `CoinType` color that tells us what currency the
    /// `value` inside represents.
    resource struct Coin<Token: resource> {
        value: u64,
    }

    /// A minting capability allows coins of type `CoinType` to be minted
    resource struct MintCapability<Token: resource> {
        enabled: bool,
    }

    /// A burn capability allows coins of type `CoinType` to be burned
    resource struct BurnCapability<Token: resource> { }

    struct MintEvent {
        /// funds added to the system
        amount: u64,
        /// UTF-8 encoded symbol for the coin type (e.g., "STC")
        currency_code: vector<u8>,
    }

    struct BurnEvent {
        /// funds removed from the system
        amount: u64,
        /// UTF-8 encoded symbol for the coin type (e.g., "STC")
        currency_code: vector<u8>,
        /// address with the Preburn resource that stored the now-burned funds
        preburn_address: address,
    }

    struct PreburnEvent {
        /// funds waiting to be removed from the system
        amount: u64,
        /// UTF-8 encoded symbol for the coin type (e.g., "STC")
        currency_code: vector<u8>,
        /// address with the Preburn resource that now holds the funds
        preburn_address: address,
    }

    struct CancelBurnEvent {
        /// funds returned
        amount: u64,
        /// UTF-8 encoded symbol for the coin type (e.g., "STC")
        currency_code: vector<u8>,
        /// address with the Preburn resource that holds the now-returned funds
        preburn_address: address,
    }

    resource struct CurrencyInfo<CoinType: resource> {
        /// The total value for the currency represented by
        /// `CoinType`. Mutable.
        total_value: u128,
        /// Value of funds that are in the process of being burned
        preburn_value: u64,
        //TODO remove this.
        is_synthetic: bool,
        // The scaling factor for the coin (i.e. the amount to multiply by
        // to get to the human-readable reprentation for this currency). e.g. 10^6 for Coin1
        scaling_factor: u64,
        // The smallest fractional part (number of decimal places) to be
        // used in the human-readable representation for the currency (e.g.
        // 10^2 for Coin1 cents)
        fractional_part: u64,
        // We may want to disable the ability to mint further coins of a
        // currency while that currency is still around. Mutable.
        can_mint: bool,
        // event stream for minting
        mint_events: Event::EventHandle<MintEvent>,
        // event stream for burning
        burn_events: Event::EventHandle<BurnEvent>,
        // event stream for preburn requests
        preburn_events: Event::EventHandle<PreburnEvent>,
        // event stream for cancelled preburn requests
        cancel_burn_events: Event::EventHandle<CancelBurnEvent>,
    }

    // An association account holding this privilege can add/remove the
    // currencies from the system.
    struct AddCurrency { }

    ///////////////////////////////////////////////////////////////////////////
    // Initialization and granting of privileges
    ///////////////////////////////////////////////////////////////////////////
    public fun apply_for_mint_capability<TokenType: resource>(
        signer: &signer,
        token_address: address,
    ) {
        assert(is_registered_in<TokenType>(token_address), 43);
        move_to(signer, MintCapability<TokenType> { enabled: false })
    }

    public fun approve_mint_capability<TokenType: resource>(_token: &TokenType, account: address)
    acquires MintCapability {
        borrow_global_mut<MintCapability<TokenType>>(account).enabled = true
    }

    public fun remove_mint_capability<TokenType: resource>(
        _token: &TokenType,
        account: address,
    ): MintCapability<TokenType> acquires MintCapability {
        move_from<MintCapability<TokenType>>(account)
    }

    // Returns a MintCapability for the `CoinType` currency. `CoinType`
    // must be a registered currency type.
    public fun create_mint_capability<CoinType: resource>(
        _token: &CoinType,
    ): MintCapability<CoinType> {
        MintCapability<CoinType> { enabled: true }
    }

    public fun destroy_mint_capability<Token: resource>(cap: MintCapability<Token>) {
        let MintCapability<Token>{ enabled: _enabled } = cap;
    }

    // Return `amount` coins.
    // Fails if the sender does not have a published MintCapability.
    public fun mint<Token: resource>(
        account: &signer,
        amount: u64,
        token_address: address,
    ): Coin<Token> acquires CurrencyInfo, MintCapability {
        mint_with_capability(
            amount,
            token_address,
            borrow_global<MintCapability<Token>>(Signer::address_of(account)),
        )
    }

    // Mint a new Coin::Coin worth `value`. The caller must have a reference to a MintCapability.
    // Only the Association account can acquire such a reference, and it can do so only via
    // `borrow_sender_mint_capability`
    public fun mint_with_capability<Token: resource>(
        value: u64,
        token_address: address,
        capability: &MintCapability<Token>,
    ): Coin<Token> acquires CurrencyInfo {
        assert(capability.enabled, 10000);
        // update market cap resource to reflect minting
        let info = borrow_global_mut<CurrencyInfo<Token>>(token_address);
        assert(info.can_mint, 4);
        info.total_value = info.total_value + (value as u128);
        // don't emit mint events for synthetic currenices
        Coin<Token> { value }
    }

    // Create a new Coin::Coin<CoinType> with a value of 0
    public fun zero<CoinType: resource>(): Coin<CoinType> {
        Coin<CoinType> { value: 0 }
    }

    // Public accessor for the value of a coin
    public fun value<CoinType: resource>(coin: &Coin<CoinType>): u64 {
        coin.value
    }

    // Splits the given coin into two and returns them both
    // It leverages `Self::withdraw` for any verifications of the values
    public fun split<CoinType: resource>(
        coin: Coin<CoinType>,
        amount: u64,
    ): (Coin<CoinType>, Coin<CoinType>) {
        let other = withdraw(&mut coin, amount);
        (coin, other)
    }

    // "Divides" the given coin into two, where the original coin is modified in place
    // The original coin will have value = original value - `amount`
    // The new coin will have a value = `amount`
    // Fails if the coins value is less than `amount`
    public fun withdraw<CoinType: resource>(
        coin: &mut Coin<CoinType>,
        amount: u64,
    ): Coin<CoinType> {
        // Check that `amount` is less than the coin's value
        assert(coin.value >= amount, 10);
        coin.value = coin.value - amount;
        Coin { value: amount }
    }

    // Merges two coins of the same currency and returns a new coin whose
    // value is equal to the sum of the two inputs
    public fun join<CoinType: resource>(
        coin1: Coin<CoinType>,
        coin2: Coin<CoinType>,
    ): Coin<CoinType> {
        deposit(&mut coin1, coin2);
        coin1
    }

    // "Merges" the two coins
    // The coin passed in by reference will have a value equal to the sum of the two coins
    // The `check` coin is consumed in the process
    public fun deposit<CoinType: resource>(coin: &mut Coin<CoinType>, check: Coin<CoinType>) {
        let Coin{ value: value } = check;
        coin.value = coin.value + value;
    }

    // Destroy a coin
    // Fails if the value is non-zero
    // The amount of Coin in the system is a tightly controlled property,
    // so you cannot "burn" any non-zero amount of Coin
    public fun destroy_zero<CoinType: resource>(coin: Coin<CoinType>) {
        let Coin{ value: value } = coin;
        assert(value == 0, 5)
    }

    ///////////////////////////////////////////////////////////////////////////
    // Definition of Currencies
    ///////////////////////////////////////////////////////////////////////////

    // Register the type `CoinType` as a currency. Without this, a type
    // cannot be used as a coin/currency unit n Libra.
    public fun register_currency<CoinType: resource>(
        account: &signer,
        token: &CoinType,
        scaling_factor: u64,
        fractional_part: u64,
    ) {
        move_to(account, create_mint_capability(token));
        move_to(
            account,
            CurrencyInfo<CoinType> {
                total_value: 0,
                preburn_value: 0,
                is_synthetic: false,
                scaling_factor,
                fractional_part,
                can_mint: true,
                mint_events: Event::new_event_handle<MintEvent>(account),
                burn_events: Event::new_event_handle<BurnEvent>(account),
                preburn_events: Event::new_event_handle<PreburnEvent>(account),
                cancel_burn_events: Event::new_event_handle<CancelBurnEvent>(account),
            },
        );
    }

    // Return the total amount of currency minted of type `CoinType`
    public fun market_cap<CoinType: resource>(token_address: address): u128 acquires CurrencyInfo {
        borrow_global<CurrencyInfo<CoinType>>(token_address).total_value
    }

    // Return true if the type `CoinType` is a registered in `token_address`.
    public fun is_registered_in<CoinType: resource>(token_address: address): bool {
        exists<CurrencyInfo<CoinType>>(token_address)
    }

    // There may be situations in which we disallow the further minting of
    // coins in the system without removing the currency. This function
    // allows the association to control whether or not further coins of
    // `CoinType` can be minted or not.
    public fun update_minting_ability<CoinType: resource>(
        account: &signer,
        _token: &CoinType,
        can_mint: bool,
    ) acquires CurrencyInfo {
        let currency_info = borrow_global_mut<CurrencyInfo<CoinType>>(Signer::address_of(account));
        currency_info.can_mint = can_mint;
    }
}
}