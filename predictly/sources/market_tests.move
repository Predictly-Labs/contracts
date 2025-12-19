#[test_only]
module predictly::market_tests {
    use std::string;
    use std::signer;
    use aptos_framework::account;
    use aptos_framework::coin;
    use aptos_framework::aptos_coin::{Self, AptosCoin};
    use aptos_framework::timestamp;
    use predictly::market;

    // Test constants
    const INITIAL_BALANCE: u64 = 1000000000; // 10 MOVE (8 decimals)
    const STAKE_AMOUNT: u64 = 100000000;     // 1 MOVE

    // Helper to setup test environment
    fun setup_test(aptos_framework: &signer, admin: &signer, user1: &signer, user2: &signer) {
        // Initialize timestamp
        timestamp::set_time_has_started_for_testing(aptos_framework);
        timestamp::fast_forward_seconds(1000);

        // Initialize AptosCoin
        let (burn_cap, mint_cap) = aptos_coin::initialize_for_test(aptos_framework);

        // Create accounts
        account::create_account_for_test(signer::address_of(admin));
        account::create_account_for_test(signer::address_of(user1));
        account::create_account_for_test(signer::address_of(user2));

        // Register and fund accounts
        coin::register<AptosCoin>(admin);
        coin::register<AptosCoin>(user1);
        coin::register<AptosCoin>(user2);

        let coins_admin = coin::mint<AptosCoin>(INITIAL_BALANCE, &mint_cap);
        let coins_user1 = coin::mint<AptosCoin>(INITIAL_BALANCE, &mint_cap);
        let coins_user2 = coin::mint<AptosCoin>(INITIAL_BALANCE, &mint_cap);

        coin::deposit(signer::address_of(admin), coins_admin);
        coin::deposit(signer::address_of(user1), coins_user1);
        coin::deposit(signer::address_of(user2), coins_user2);

        // Cleanup capabilities
        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);

        // Initialize market module
        market::initialize(admin);
    }

    #[test(aptos_framework = @0x1, admin = @0xCAFE, user1 = @0x123, user2 = @0x456)]
    fun test_initialize(aptos_framework: &signer, admin: &signer, user1: &signer, user2: &signer) {
        setup_test(aptos_framework, admin, user1, user2);
        
        // Verify market count is 0
        let count = market::get_market_count(signer::address_of(admin));
        assert!(count == 0, 1);
    }

    #[test(aptos_framework = @0x1, admin = @0xCAFE, user1 = @0x123, user2 = @0x456)]
    fun test_create_market(aptos_framework: &signer, admin: &signer, user1: &signer, user2: &signer) {
        setup_test(aptos_framework, admin, user1, user2);
        
        let admin_addr = signer::address_of(admin);
        
        // Create a market
        market::create_market(
            admin,
            admin_addr,
            string::utf8(b"Will BTC reach 100k?"),
            string::utf8(b"Bitcoin price prediction"),
            2000, // end_time
            10000000,  // min_stake: 0.1 MOVE
            500000000, // max_stake: 5 MOVE
            admin_addr,
            0, // STANDARD market type
        );

        // Verify market count increased
        let count = market::get_market_count(admin_addr);
        assert!(count == 1, 2);

        // Verify market state using getter functions
        let status = market::get_market_status(admin_addr, 0);
        assert!(status == 0, 3); // STATUS_ACTIVE
        
        let (yes_pool, no_pool) = market::get_market_pools(admin_addr, 0);
        assert!(yes_pool == 0, 4);
        assert!(no_pool == 0, 5);
    }

    #[test(aptos_framework = @0x1, admin = @0xCAFE, user1 = @0x123, user2 = @0x456)]
    fun test_place_vote_yes(aptos_framework: &signer, admin: &signer, user1: &signer, user2: &signer) {
        setup_test(aptos_framework, admin, user1, user2);
        
        let admin_addr = signer::address_of(admin);
        let user1_addr = signer::address_of(user1);
        
        // Create market
        market::create_market(
            admin,
            admin_addr,
            string::utf8(b"Test Market"),
            string::utf8(b"Description"),
            2000,
            10000000,
            500000000,
            admin_addr,
            0,
        );

        // User1 votes YES
        let balance_before = coin::balance<AptosCoin>(user1_addr);
        market::place_vote(user1, admin_addr, 0, 1, STAKE_AMOUNT); // 1 = YES
        let balance_after = coin::balance<AptosCoin>(user1_addr);

        // Verify balance decreased
        assert!(balance_before - balance_after == STAKE_AMOUNT, 6);

        // Verify pool updated
        let (yes_pool, no_pool) = market::get_market_pools(admin_addr, 0);
        assert!(yes_pool == STAKE_AMOUNT, 7);
        assert!(no_pool == 0, 8);
        
        let participant_count = market::get_participant_count(admin_addr, 0);
        assert!(participant_count == 1, 9);

        // Verify vote recorded
        let prediction = market::get_vote_prediction(admin_addr, 0, user1_addr);
        let amount = market::get_vote_amount(admin_addr, 0, user1_addr);
        assert!(prediction == 1, 10);
        assert!(amount == STAKE_AMOUNT, 11);
    }

    #[test(aptos_framework = @0x1, admin = @0xCAFE, user1 = @0x123, user2 = @0x456)]
    fun test_place_vote_no(aptos_framework: &signer, admin: &signer, user1: &signer, user2: &signer) {
        setup_test(aptos_framework, admin, user1, user2);
        
        let admin_addr = signer::address_of(admin);
        
        // Create market
        market::create_market(
            admin,
            admin_addr,
            string::utf8(b"Test Market"),
            string::utf8(b"Description"),
            2000,
            10000000,
            500000000,
            admin_addr,
            0,
        );

        // User2 votes NO
        market::place_vote(user2, admin_addr, 0, 2, STAKE_AMOUNT); // 2 = NO

        // Verify pool updated
        let (yes_pool, no_pool) = market::get_market_pools(admin_addr, 0);
        assert!(yes_pool == 0, 12);
        assert!(no_pool == STAKE_AMOUNT, 13);
    }

    #[test(aptos_framework = @0x1, admin = @0xCAFE, user1 = @0x123, user2 = @0x456)]
    #[expected_failure(abort_code = 5)] // E_ALREADY_VOTED
    fun test_double_vote_fails(aptos_framework: &signer, admin: &signer, user1: &signer, user2: &signer) {
        setup_test(aptos_framework, admin, user1, user2);
        
        let admin_addr = signer::address_of(admin);
        
        // Create market
        market::create_market(
            admin,
            admin_addr,
            string::utf8(b"Test Market"),
            string::utf8(b"Description"),
            2000,
            10000000,
            500000000,
            admin_addr,
            0,
        );

        // User1 votes YES
        market::place_vote(user1, admin_addr, 0, 1, STAKE_AMOUNT);
        
        // User1 tries to vote again - should fail
        market::place_vote(user1, admin_addr, 0, 2, STAKE_AMOUNT);
    }

    #[test(aptos_framework = @0x1, admin = @0xCAFE, user1 = @0x123, user2 = @0x456)]
    fun test_resolve_market(aptos_framework: &signer, admin: &signer, user1: &signer, user2: &signer) {
        setup_test(aptos_framework, admin, user1, user2);
        
        let admin_addr = signer::address_of(admin);
        
        // Create market
        market::create_market(
            admin,
            admin_addr,
            string::utf8(b"Test Market"),
            string::utf8(b"Description"),
            2000,
            10000000,
            500000000,
            admin_addr,
            0,
        );

        // Place votes
        market::place_vote(user1, admin_addr, 0, 1, STAKE_AMOUNT); // YES
        market::place_vote(user2, admin_addr, 0, 2, STAKE_AMOUNT); // NO

        // Fast forward time past end_time
        timestamp::fast_forward_seconds(2000);

        // Resolve market as YES
        market::resolve(admin, admin_addr, 0, 1); // 1 = OUTCOME_YES

        // Verify market resolved
        let status = market::get_market_status(admin_addr, 0);
        let outcome = market::get_market_outcome(admin_addr, 0);
        assert!(status == 1, 14); // STATUS_RESOLVED
        assert!(outcome == 1, 15); // OUTCOME_YES
    }

    #[test(aptos_framework = @0x1, admin = @0xCAFE, user1 = @0x123, user2 = @0x456)]
    #[expected_failure(abort_code = 2)] // E_NOT_RESOLVER
    fun test_resolve_non_resolver_fails(aptos_framework: &signer, admin: &signer, user1: &signer, user2: &signer) {
        setup_test(aptos_framework, admin, user1, user2);
        
        let admin_addr = signer::address_of(admin);
        
        // Create market with admin as resolver
        market::create_market(
            admin,
            admin_addr,
            string::utf8(b"Test Market"),
            string::utf8(b"Description"),
            2000,
            10000000,
            500000000,
            admin_addr,
            0,
        );

        // Fast forward time
        timestamp::fast_forward_seconds(2000);

        // User1 tries to resolve - should fail
        market::resolve(user1, admin_addr, 0, 1);
    }

    #[test(aptos_framework = @0x1, admin = @0xCAFE, user1 = @0x123, user2 = @0x456)]
    #[expected_failure(abort_code = 4)] // E_MARKET_NOT_ENDED
    fun test_resolve_before_end_fails(aptos_framework: &signer, admin: &signer, user1: &signer, user2: &signer) {
        setup_test(aptos_framework, admin, user1, user2);
        
        let admin_addr = signer::address_of(admin);
        
        // Create market
        market::create_market(
            admin,
            admin_addr,
            string::utf8(b"Test Market"),
            string::utf8(b"Description"),
            2000,
            10000000,
            500000000,
            admin_addr,
            0,
        );

        // Try to resolve before end_time - should fail
        market::resolve(admin, admin_addr, 0, 1);
    }

    #[test(aptos_framework = @0x1, admin = @0xCAFE, user1 = @0x123, user2 = @0x456)]
    fun test_claim_reward_winner(aptos_framework: &signer, admin: &signer, user1: &signer, user2: &signer) {
        setup_test(aptos_framework, admin, user1, user2);
        
        let admin_addr = signer::address_of(admin);
        let user1_addr = signer::address_of(user1);
        
        // Create market
        market::create_market(
            admin,
            admin_addr,
            string::utf8(b"Test Market"),
            string::utf8(b"Description"),
            2000,
            10000000,
            500000000,
            admin_addr,
            0,
        );

        // User1 votes YES, User2 votes NO
        market::place_vote(user1, admin_addr, 0, 1, STAKE_AMOUNT);
        market::place_vote(user2, admin_addr, 0, 2, STAKE_AMOUNT);

        // Fast forward and resolve as YES
        timestamp::fast_forward_seconds(2000);
        market::resolve(admin, admin_addr, 0, 1);

        // User1 (winner) claims reward
        let balance_before = coin::balance<AptosCoin>(user1_addr);
        market::claim_reward(user1, admin_addr, 0);
        let balance_after = coin::balance<AptosCoin>(user1_addr);

        // Winner should get total pool (2 MOVE)
        let reward = balance_after - balance_before;
        assert!(reward == STAKE_AMOUNT * 2, 16);
    }

    #[test(aptos_framework = @0x1, admin = @0xCAFE, user1 = @0x123, user2 = @0x456)]
    #[expected_failure(abort_code = 8)] // E_NOT_WINNER
    fun test_claim_reward_loser_fails(aptos_framework: &signer, admin: &signer, user1: &signer, user2: &signer) {
        setup_test(aptos_framework, admin, user1, user2);
        
        let admin_addr = signer::address_of(admin);
        
        // Create market
        market::create_market(
            admin,
            admin_addr,
            string::utf8(b"Test Market"),
            string::utf8(b"Description"),
            2000,
            10000000,
            500000000,
            admin_addr,
            0,
        );

        // User1 votes YES, User2 votes NO
        market::place_vote(user1, admin_addr, 0, 1, STAKE_AMOUNT);
        market::place_vote(user2, admin_addr, 0, 2, STAKE_AMOUNT);

        // Resolve as YES (User2 loses)
        timestamp::fast_forward_seconds(2000);
        market::resolve(admin, admin_addr, 0, 1);

        // User2 (loser) tries to claim - should fail
        market::claim_reward(user2, admin_addr, 0);
    }

    #[test(aptos_framework = @0x1, admin = @0xCAFE, user1 = @0x123, user2 = @0x456)]
    #[expected_failure(abort_code = 9)] // E_ALREADY_CLAIMED
    fun test_double_claim_fails(aptos_framework: &signer, admin: &signer, user1: &signer, user2: &signer) {
        setup_test(aptos_framework, admin, user1, user2);
        
        let admin_addr = signer::address_of(admin);
        
        // Create market
        market::create_market(
            admin,
            admin_addr,
            string::utf8(b"Test Market"),
            string::utf8(b"Description"),
            2000,
            10000000,
            500000000,
            admin_addr,
            0,
        );

        // User1 votes YES
        market::place_vote(user1, admin_addr, 0, 1, STAKE_AMOUNT);

        // Resolve as YES
        timestamp::fast_forward_seconds(2000);
        market::resolve(admin, admin_addr, 0, 1);

        // User1 claims
        market::claim_reward(user1, admin_addr, 0);
        
        // User1 tries to claim again - should fail
        market::claim_reward(user1, admin_addr, 0);
    }

    #[test(aptos_framework = @0x1, admin = @0xCAFE, user1 = @0x123, user2 = @0x456)]
    fun test_invalid_outcome_refund(aptos_framework: &signer, admin: &signer, user1: &signer, user2: &signer) {
        setup_test(aptos_framework, admin, user1, user2);
        
        let admin_addr = signer::address_of(admin);
        let user1_addr = signer::address_of(user1);
        let user2_addr = signer::address_of(user2);
        
        // Create market
        market::create_market(
            admin,
            admin_addr,
            string::utf8(b"Test Market"),
            string::utf8(b"Description"),
            2000,
            10000000,
            500000000,
            admin_addr,
            0,
        );

        // Both users vote
        market::place_vote(user1, admin_addr, 0, 1, STAKE_AMOUNT);
        market::place_vote(user2, admin_addr, 0, 2, STAKE_AMOUNT);

        // Resolve as INVALID
        timestamp::fast_forward_seconds(2000);
        market::resolve(admin, admin_addr, 0, 3); // 3 = OUTCOME_INVALID

        // Both users should get refund
        let balance1_before = coin::balance<AptosCoin>(user1_addr);
        market::claim_reward(user1, admin_addr, 0);
        let balance1_after = coin::balance<AptosCoin>(user1_addr);
        assert!(balance1_after - balance1_before == STAKE_AMOUNT, 17);

        let balance2_before = coin::balance<AptosCoin>(user2_addr);
        market::claim_reward(user2, admin_addr, 0);
        let balance2_after = coin::balance<AptosCoin>(user2_addr);
        assert!(balance2_after - balance2_before == STAKE_AMOUNT, 18);
    }

    #[test(aptos_framework = @0x1, admin = @0xCAFE, user1 = @0x123, user2 = @0x456)]
    fun test_get_percentages(aptos_framework: &signer, admin: &signer, user1: &signer, user2: &signer) {
        setup_test(aptos_framework, admin, user1, user2);
        
        let admin_addr = signer::address_of(admin);
        
        // Create market
        market::create_market(
            admin,
            admin_addr,
            string::utf8(b"Test Market"),
            string::utf8(b"Description"),
            2000,
            10000000,
            500000000,
            admin_addr,
            0,
        );

        // No votes - should be 50-50
        let (yes_pct, no_pct) = market::get_percentages(admin_addr, 0);
        assert!(yes_pct == 5000, 19); // 50%
        assert!(no_pct == 5000, 20);

        // User1 votes YES with 3x stake
        market::place_vote(user1, admin_addr, 0, 1, STAKE_AMOUNT * 3);
        // User2 votes NO with 1x stake
        market::place_vote(user2, admin_addr, 0, 2, STAKE_AMOUNT);

        // Should be 75-25
        let (yes_pct2, no_pct2) = market::get_percentages(admin_addr, 0);
        assert!(yes_pct2 == 7500, 21); // 75%
        assert!(no_pct2 == 2500, 22);  // 25%
    }

    #[test(aptos_framework = @0x1, admin = @0xCAFE, user1 = @0x123, user2 = @0x456)]
    #[expected_failure(abort_code = 6)] // E_STAKE_TOO_LOW
    fun test_stake_below_minimum_fails(aptos_framework: &signer, admin: &signer, user1: &signer, user2: &signer) {
        setup_test(aptos_framework, admin, user1, user2);
        
        let admin_addr = signer::address_of(admin);
        
        // Create market with min_stake = 0.1 MOVE
        market::create_market(
            admin,
            admin_addr,
            string::utf8(b"Test Market"),
            string::utf8(b"Description"),
            2000,
            10000000,  // min_stake: 0.1 MOVE
            500000000,
            admin_addr,
            0,
        );

        // Try to stake below minimum - should fail
        market::place_vote(user1, admin_addr, 0, 1, 1000000); // 0.01 MOVE
    }

    #[test(aptos_framework = @0x1, admin = @0xCAFE, user1 = @0x123, user2 = @0x456)]
    #[expected_failure(abort_code = 7)] // E_STAKE_TOO_HIGH
    fun test_stake_above_maximum_fails(aptos_framework: &signer, admin: &signer, user1: &signer, user2: &signer) {
        setup_test(aptos_framework, admin, user1, user2);
        
        let admin_addr = signer::address_of(admin);
        
        // Create market with max_stake = 5 MOVE
        market::create_market(
            admin,
            admin_addr,
            string::utf8(b"Test Market"),
            string::utf8(b"Description"),
            2000,
            10000000,
            500000000, // max_stake: 5 MOVE
            admin_addr,
            0,
        );

        // Try to stake above maximum - should fail
        market::place_vote(user1, admin_addr, 0, 1, 600000000); // 6 MOVE
    }
}
