module Moonverz::airdrop {
    use std::signer;
    use aptos_framework::timestamp;
    use Moonverz::m_coin;

    #[test_only]
    use aptos_framework::primary_fungible_store;

    #[test_only]
    use aptos_framework::account;

    const ENOT_AUTHORIZED: u64 = 1;
    const ETOO_EARLY: u64 = 2;
    const AIRDROP_INTERVAL: u64 = 2 * 60 * 60; // 2 hours in seconds

    struct AirdropConfig has key {
        admin: address,
        amount_per_drop: u64,
    }

    struct UserLastClaim has key {
        last_claim_time: u64,
    }

    public entry fun initialize(admin: &signer, amount_per_drop: u64) {
        let admin_addr = signer::address_of(admin);
        assert!(admin_addr == @Moonverz, ENOT_AUTHORIZED);

        move_to(admin, AirdropConfig {
            admin: admin_addr,
            amount_per_drop,
        });
    }

    public entry fun claim_airdrop(admin: &signer, user: &signer) acquires AirdropConfig, UserLastClaim {
        let admin_addr = signer::address_of(admin);
        let user_addr = signer::address_of(user);
        let config = borrow_global<AirdropConfig>(@Moonverz);
        let current_time:u64 = timestamp::now_seconds();

        if (!exists<UserLastClaim>(user_addr)) {
            move_to(user, UserLastClaim { last_claim_time: 0 });
            
        };
        {
            let user_claim = borrow_global_mut<UserLastClaim>(user_addr);
            assert!(current_time >= user_claim.last_claim_time + AIRDROP_INTERVAL, ETOO_EARLY);
            m_coin::transfer(admin,admin_addr, user_addr, config.amount_per_drop);
            user_claim.last_claim_time = current_time;
        };
    }

    public entry fun update_amount(admin: &signer, new_amount: u64) acquires AirdropConfig {
        let config = borrow_global_mut<AirdropConfig>(@Moonverz);
        assert!(signer::address_of(admin) == config.admin, ENOT_AUTHORIZED);
        config.amount_per_drop = new_amount;
    }

    #[test(creator = @Moonverz, user = @0xface, aptos_framework = @aptos_framework)]
    fun test_basic_flow(aptos_framework: &signer, creator: &signer, user: &signer)acquires AirdropConfig, UserLastClaim{

    // Initialize m_coin module
    m_coin::init_module(creator);

    // Initialize airdrop module
    initialize(creator, 100);

    // Create test accounts
    account::create_account_for_test(signer::address_of(creator));
    account::create_account_for_test(signer::address_of(user));

    // Perform airdrop claim
    claim_airdrop(creator, user);

    // Assert the balance after airdrop
    let user_addr = signer::address_of(user);
    let asset = m_coin::get_metadata();
    assert!(primary_fungible_store::balance(user_addr, asset) == 100, 0);



    }

}