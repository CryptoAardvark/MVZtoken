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
    const AIRDROP_INTERVAL: u64 = 7200; // 2 hours in seconds

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
        let user_addr = signer::address_of(user);
        let config = borrow_global<AirdropConfig>(@Moonverz);
        let current_time = timestamp::now_seconds();

        if (!exists<UserLastClaim>(user_addr)) {
            move_to(user, UserLastClaim { last_claim_time: 0 });
        };

        {
            let user_claim = borrow_global_mut<UserLastClaim>(user_addr);
            assert!(current_time >= user_claim.last_claim_time + AIRDROP_INTERVAL, ETOO_EARLY);
            m_coin::mint(admin, user_addr, config.amount_per_drop);
            user_claim.last_claim_time = current_time;
        };
    }

    public entry fun update_amount(admin: &signer, new_amount: u64) acquires AirdropConfig {
        let config = borrow_global_mut<AirdropConfig>(@Moonverz);
        assert!(signer::address_of(admin) == config.admin, ENOT_AUTHORIZED);
        config.amount_per_drop = new_amount;
    }
    
}