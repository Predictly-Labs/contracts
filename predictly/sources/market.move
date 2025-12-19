/// PredictionMarket Module for Predictly
/// Handles market creation, voting, resolution, and reward claims
module predictly::market {
    use std::string::String;
    use std::signer;
    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::timestamp;
    use aptos_framework::event;
    use aptos_std::simple_map::{Self, SimpleMap};

    // ==================== Constants ====================
    
    // Market Status
    const STATUS_ACTIVE: u8 = 0;
    const STATUS_RESOLVED: u8 = 1;
    const STATUS_CANCELLED: u8 = 2;

    // Market Outcome
    const OUTCOME_PENDING: u8 = 0;
    const OUTCOME_YES: u8 = 1;
    const OUTCOME_NO: u8 = 2;
    const OUTCOME_INVALID: u8 = 3;

    // Prediction Types
    const PREDICTION_YES: u8 = 1;
    const PREDICTION_NO: u8 = 2;

    // Market Types
    const MARKET_TYPE_STANDARD: u8 = 0;
    const MARKET_TYPE_NO_LOSS: u8 = 1;

    // Default lending protocol for no-loss markets
    const DEFAULT_LENDING_PROTOCOL: u8 = 0; // LayerBank

    // ==================== Error Codes ====================
    
    const E_NOT_ADMIN: u64 = 1;
    const E_NOT_RESOLVER: u64 = 2;
    const E_MARKET_NOT_ACTIVE: u64 = 3;
    const E_MARKET_NOT_ENDED: u64 = 4;
    const E_ALREADY_VOTED: u64 = 5;
    const E_STAKE_TOO_LOW: u64 = 6;
    const E_STAKE_TOO_HIGH: u64 = 7;
    const E_NOT_WINNER: u64 = 8;
    const E_ALREADY_CLAIMED: u64 = 9;
    const E_MARKET_PAUSED: u64 = 10;
    const E_INVALID_PREDICTION: u64 = 11;
    const E_INVALID_OUTCOME: u64 = 12;
    const E_MARKET_NOT_FOUND: u64 = 13;
    const E_VOTE_NOT_FOUND: u64 = 14;
    const E_ZERO_STAKE: u64 = 15;
    const E_MARKET_ENDED: u64 = 16;
    const E_NOT_RESOLVED: u64 = 17;

    // ==================== Structs ====================

    /// Global configuration for the market module
    struct MarketConfig has key {
        admin: address,
        market_count: u64,
    }

    /// Individual prediction market
    struct Market has key, store, copy, drop {
        id: u64,
        creator: address,
        title: String,
        description: String,
        end_time: u64,
        min_stake: u64,
        max_stake: u64,
        market_type: u8,
        resolver: address,
        status: u8,
        outcome: u8,
        yes_pool: u64,
        no_pool: u64,
        participant_count: u64,
        created_at: u64,
        resolved_at: u64,
        // No-loss market fields
        lending_protocol: u8,
        total_yield: u64,  // Populated after resolution
    }

    /// Registry to store all markets
    struct MarketRegistry has key {
        markets: SimpleMap<u64, Market>,
    }

    /// Individual vote record
    struct Vote has store, drop, copy {
        voter: address,
        prediction: u8,
        amount: u64,
        timestamp: u64,
        has_claimed: bool,
    }

    /// Registry to store votes for each market
    struct VoteRegistry has key {
        // market_id -> (voter_address -> Vote)
        votes: SimpleMap<u64, SimpleMap<address, Vote>>,
    }

    /// Vault to hold staked coins for each market
    struct MarketVault has key {
        // market_id -> Coin
        vaults: SimpleMap<u64, Coin<AptosCoin>>,
    }

    // ==================== Events ====================

    #[event]
    struct MarketCreated has drop, store {
        market_id: u64,
        creator: address,
        title: String,
        end_time: u64,
        market_type: u8,
    }

    #[event]
    struct VotePlaced has drop, store {
        market_id: u64,
        voter: address,
        prediction: u8,
        amount: u64,
        new_yes_pool: u64,
        new_no_pool: u64,
    }

    #[event]
    struct MarketResolved has drop, store {
        market_id: u64,
        outcome: u8,
        resolver: address,
        total_pool: u64,
    }

    #[event]
    struct RewardClaimed has drop, store {
        market_id: u64,
        voter: address,
        amount: u64,
    }

    // ==================== Entry Functions ====================

    /// Initialize the market module (called once by admin)
    public entry fun initialize(admin: &signer) {
        let admin_addr = signer::address_of(admin);
        
        move_to(admin, MarketConfig {
            admin: admin_addr,
            market_count: 0,
        });

        move_to(admin, MarketRegistry {
            markets: simple_map::new(),
        });

        move_to(admin, VoteRegistry {
            votes: simple_map::new(),
        });

        move_to(admin, MarketVault {
            vaults: simple_map::new(),
        });
    }

    /// Create a new prediction market
    public entry fun create_market(
        creator: &signer,
        admin_addr: address,
        title: String,
        description: String,
        end_time: u64,
        min_stake: u64,
        max_stake: u64,
        resolver: address,
        market_type: u8,
    ) acquires MarketConfig, MarketRegistry, MarketVault, VoteRegistry {
        let creator_addr = signer::address_of(creator);
        
        // Validate market type
        assert!(market_type == MARKET_TYPE_STANDARD || market_type == MARKET_TYPE_NO_LOSS, E_INVALID_PREDICTION);
        
        // Get and update market config
        let config = borrow_global_mut<MarketConfig>(admin_addr);
        let market_id = config.market_count;
        config.market_count = market_id + 1;

        // Create new market
        let market = Market {
            id: market_id,
            creator: creator_addr,
            title,
            description,
            end_time,
            min_stake,
            max_stake,
            market_type,
            resolver,
            status: STATUS_ACTIVE,
            outcome: OUTCOME_PENDING,
            yes_pool: 0,
            no_pool: 0,
            participant_count: 0,
            created_at: timestamp::now_seconds(),
            resolved_at: 0,
            lending_protocol: DEFAULT_LENDING_PROTOCOL,
            total_yield: 0,
        };

        // Store market in registry
        let registry = borrow_global_mut<MarketRegistry>(admin_addr);
        simple_map::add(&mut registry.markets, market_id, market);

        // Initialize empty vault for this market
        let vault = borrow_global_mut<MarketVault>(admin_addr);
        simple_map::add(&mut vault.vaults, market_id, coin::zero<AptosCoin>());

        // Initialize empty vote map for this market
        let vote_registry = borrow_global_mut<VoteRegistry>(admin_addr);
        simple_map::add(&mut vote_registry.votes, market_id, simple_map::new());

        // Emit event
        event::emit(MarketCreated {
            market_id,
            creator: creator_addr,
            title: market.title,
            end_time,
            market_type,
        });
    }

    /// Place a vote on a market
    public entry fun place_vote(
        voter: &signer,
        admin_addr: address,
        market_id: u64,
        prediction: u8,
        amount: u64,
    ) acquires MarketRegistry, VoteRegistry, MarketVault {
        let voter_addr = signer::address_of(voter);
        
        // Validate prediction type
        assert!(prediction == PREDICTION_YES || prediction == PREDICTION_NO, E_INVALID_PREDICTION);
        
        // Validate amount
        assert!(amount > 0, E_ZERO_STAKE);

        // Get market and validate
        let registry = borrow_global_mut<MarketRegistry>(admin_addr);
        assert!(simple_map::contains_key(&registry.markets, &market_id), E_MARKET_NOT_FOUND);
        let market = simple_map::borrow_mut(&mut registry.markets, &market_id);
        
        // Check market is active
        assert!(market.status == STATUS_ACTIVE, E_MARKET_NOT_ACTIVE);
        
        // Check market hasn't ended
        let current_time = timestamp::now_seconds();
        assert!(current_time < market.end_time, E_MARKET_ENDED);

        // Check stake limits
        assert!(amount >= market.min_stake, E_STAKE_TOO_LOW);
        assert!(market.max_stake == 0 || amount <= market.max_stake, E_STAKE_TOO_HIGH);

        // Check voter hasn't already voted
        let vote_registry = borrow_global_mut<VoteRegistry>(admin_addr);
        let market_votes = simple_map::borrow_mut(&mut vote_registry.votes, &market_id);
        assert!(!simple_map::contains_key(market_votes, &voter_addr), E_ALREADY_VOTED);

        // Transfer coins from voter to vault
        let stake_coins = coin::withdraw<AptosCoin>(voter, amount);
        let vault = borrow_global_mut<MarketVault>(admin_addr);
        let market_vault = simple_map::borrow_mut(&mut vault.vaults, &market_id);
        coin::merge(market_vault, stake_coins);

        // Update pool
        if (prediction == PREDICTION_YES) {
            market.yes_pool = market.yes_pool + amount;
        } else {
            market.no_pool = market.no_pool + amount;
        };
        market.participant_count = market.participant_count + 1;

        // Record vote
        let vote = Vote {
            voter: voter_addr,
            prediction,
            amount,
            timestamp: current_time,
            has_claimed: false,
        };
        simple_map::add(market_votes, voter_addr, vote);

        // Emit event
        event::emit(VotePlaced {
            market_id,
            voter: voter_addr,
            prediction,
            amount,
            new_yes_pool: market.yes_pool,
            new_no_pool: market.no_pool,
        });
    }

    /// Resolve a market (only resolver can call)
    /// For NO_LOSS markets, this also withdraws funds from lending protocol
    public entry fun resolve(
        resolver: &signer,
        admin_addr: address,
        market_id: u64,
        outcome: u8,
    ) acquires MarketRegistry {
        let resolver_addr = signer::address_of(resolver);
        
        // Validate outcome
        assert!(
            outcome == OUTCOME_YES || outcome == OUTCOME_NO || outcome == OUTCOME_INVALID,
            E_INVALID_OUTCOME
        );

        // Get market
        let registry = borrow_global_mut<MarketRegistry>(admin_addr);
        assert!(simple_map::contains_key(&registry.markets, &market_id), E_MARKET_NOT_FOUND);
        let market = simple_map::borrow_mut(&mut registry.markets, &market_id);

        // Verify caller is resolver
        assert!(resolver_addr == market.resolver, E_NOT_RESOLVER);

        // Verify market is active
        assert!(market.status == STATUS_ACTIVE, E_MARKET_NOT_ACTIVE);

        // Verify market has ended
        let current_time = timestamp::now_seconds();
        assert!(current_time >= market.end_time, E_MARKET_NOT_ENDED);

        // Set outcome and status
        market.outcome = outcome;
        market.status = STATUS_RESOLVED;
        market.resolved_at = current_time;

        // For NO_LOSS markets, we would withdraw from lending protocol here
        // and set total_yield. In this simplified version, we simulate yield.
        if (market.market_type == MARKET_TYPE_NO_LOSS) {
            // Simulate yield: 5% APY prorated by market duration
            let market_duration = market.end_time - market.created_at;
            let total_pool = market.yes_pool + market.no_pool;
            // yield = total_pool * 5% * (duration / year)
            // Simplified: yield = total_pool * 500 * duration / (10000 * 31536000)
            let simulated_yield = (total_pool * 500 * market_duration) / (10000 * 31536000);
            market.total_yield = simulated_yield;
        };

        // Emit event
        event::emit(MarketResolved {
            market_id,
            outcome,
            resolver: resolver_addr,
            total_pool: market.yes_pool + market.no_pool,
        });
    }

    /// Claim reward from a resolved market
    public entry fun claim_reward(
        voter: &signer,
        admin_addr: address,
        market_id: u64,
    ) acquires MarketRegistry, VoteRegistry, MarketVault {
        let voter_addr = signer::address_of(voter);

        // Get market
        let registry = borrow_global<MarketRegistry>(admin_addr);
        assert!(simple_map::contains_key(&registry.markets, &market_id), E_MARKET_NOT_FOUND);
        let market = simple_map::borrow(&registry.markets, &market_id);

        // Verify market is resolved
        assert!(market.status == STATUS_RESOLVED, E_NOT_RESOLVED);

        // Get vote
        let vote_registry = borrow_global_mut<VoteRegistry>(admin_addr);
        let market_votes = simple_map::borrow_mut(&mut vote_registry.votes, &market_id);
        assert!(simple_map::contains_key(market_votes, &voter_addr), E_VOTE_NOT_FOUND);
        let vote = simple_map::borrow_mut(market_votes, &voter_addr);

        // Check not already claimed
        assert!(!vote.has_claimed, E_ALREADY_CLAIMED);

        // Calculate reward
        let reward_amount = calculate_reward_internal(market, vote);

        // For STANDARD markets: If reward is 0 (loser), reject
        // For NO_LOSS markets: Everyone can claim (at least principal)
        // For INVALID outcome: Everyone can claim (refund)
        if (market.market_type == MARKET_TYPE_STANDARD && market.outcome != OUTCOME_INVALID) {
            assert!(reward_amount > 0, E_NOT_WINNER);
        };

        // Mark as claimed
        vote.has_claimed = true;

        // Transfer reward from vault
        let vault = borrow_global_mut<MarketVault>(admin_addr);
        let market_vault = simple_map::borrow_mut(&mut vault.vaults, &market_id);
        
        // For no-loss markets, we may need to handle the case where vault doesn't have enough
        // (yield is simulated). In production, this would come from actual DeFi yields.
        let available = coin::value(market_vault);
        let transfer_amount = if (reward_amount > available) { available } else { reward_amount };
        
        if (transfer_amount > 0) {
            let reward_coins = coin::extract(market_vault, transfer_amount);
            coin::deposit(voter_addr, reward_coins);
        };

        // Emit event
        event::emit(RewardClaimed {
            market_id,
            voter: voter_addr,
            amount: reward_amount,
        });
    }

    // ==================== View Functions ====================

    #[view]
    /// Get market state
    public fun get_market_state(admin_addr: address, market_id: u64): Market acquires MarketRegistry {
        let registry = borrow_global<MarketRegistry>(admin_addr);
        assert!(simple_map::contains_key(&registry.markets, &market_id), E_MARKET_NOT_FOUND);
        *simple_map::borrow(&registry.markets, &market_id)
    }

    #[view]
    /// Get vote for a specific voter
    public fun get_vote(admin_addr: address, market_id: u64, voter: address): Vote acquires VoteRegistry {
        let vote_registry = borrow_global<VoteRegistry>(admin_addr);
        assert!(simple_map::contains_key(&vote_registry.votes, &market_id), E_MARKET_NOT_FOUND);
        let market_votes = simple_map::borrow(&vote_registry.votes, &market_id);
        assert!(simple_map::contains_key(market_votes, &voter), E_VOTE_NOT_FOUND);
        *simple_map::borrow(market_votes, &voter)
    }

    #[view]
    /// Get market count
    public fun get_market_count(admin_addr: address): u64 acquires MarketConfig {
        let config = borrow_global<MarketConfig>(admin_addr);
        config.market_count
    }

    #[view]
    /// Calculate potential reward for a voter
    public fun calculate_reward(admin_addr: address, market_id: u64, voter: address): u64 acquires MarketRegistry, VoteRegistry {
        let registry = borrow_global<MarketRegistry>(admin_addr);
        assert!(simple_map::contains_key(&registry.markets, &market_id), E_MARKET_NOT_FOUND);
        let market = simple_map::borrow(&registry.markets, &market_id);

        let vote_registry = borrow_global<VoteRegistry>(admin_addr);
        let market_votes = simple_map::borrow(&vote_registry.votes, &market_id);
        assert!(simple_map::contains_key(market_votes, &voter), E_VOTE_NOT_FOUND);
        let vote = simple_map::borrow(market_votes, &voter);

        calculate_reward_internal(market, vote)
    }

    #[view]
    /// Get YES/NO percentages (returns basis points, e.g., 5000 = 50%)
    public fun get_percentages(admin_addr: address, market_id: u64): (u64, u64) acquires MarketRegistry {
        let registry = borrow_global<MarketRegistry>(admin_addr);
        assert!(simple_map::contains_key(&registry.markets, &market_id), E_MARKET_NOT_FOUND);
        let market = simple_map::borrow(&registry.markets, &market_id);

        let total = market.yes_pool + market.no_pool;
        if (total == 0) {
            return (5000, 5000) // 50-50 if no votes
        };

        let yes_pct = (market.yes_pool * 10000) / total;
        let no_pct = 10000 - yes_pct;
        (yes_pct, no_pct)
    }

    // ==================== Getter Functions for Testing ====================

    #[view]
    /// Get market status
    public fun get_market_status(admin_addr: address, market_id: u64): u8 acquires MarketRegistry {
        let market = get_market_state(admin_addr, market_id);
        market.status
    }

    #[view]
    /// Get market outcome
    public fun get_market_outcome(admin_addr: address, market_id: u64): u8 acquires MarketRegistry {
        let market = get_market_state(admin_addr, market_id);
        market.outcome
    }

    #[view]
    /// Get market pools (yes_pool, no_pool)
    public fun get_market_pools(admin_addr: address, market_id: u64): (u64, u64) acquires MarketRegistry {
        let market = get_market_state(admin_addr, market_id);
        (market.yes_pool, market.no_pool)
    }

    #[view]
    /// Get market participant count
    public fun get_participant_count(admin_addr: address, market_id: u64): u64 acquires MarketRegistry {
        let market = get_market_state(admin_addr, market_id);
        market.participant_count
    }

    #[view]
    /// Get vote prediction
    public fun get_vote_prediction(admin_addr: address, market_id: u64, voter: address): u8 acquires VoteRegistry {
        let vote = get_vote(admin_addr, market_id, voter);
        vote.prediction
    }

    #[view]
    /// Get vote amount
    public fun get_vote_amount(admin_addr: address, market_id: u64, voter: address): u64 acquires VoteRegistry {
        let vote = get_vote(admin_addr, market_id, voter);
        vote.amount
    }

    // ==================== Internal Functions ====================

    /// Internal function to calculate reward
    fun calculate_reward_internal(market: &Market, vote: &Vote): u64 {
        // If market not resolved, return 0
        if (market.status != STATUS_RESOLVED) {
            return 0
        };

        let total_pool = market.yes_pool + market.no_pool;

        // If INVALID outcome, return original stake
        if (market.outcome == OUTCOME_INVALID) {
            return vote.amount
        };

        // Determine if voter is winner
        let is_winner = (market.outcome == OUTCOME_YES && vote.prediction == PREDICTION_YES) ||
                        (market.outcome == OUTCOME_NO && vote.prediction == PREDICTION_NO);

        // Handle NO_LOSS market type
        if (market.market_type == MARKET_TYPE_NO_LOSS) {
            // Everyone gets their principal back
            let principal = vote.amount;
            
            if (!is_winner) {
                // Losers get principal only
                return principal
            };
            
            // Winners get principal + proportional yield
            let winning_pool = if (market.outcome == OUTCOME_YES) {
                market.yes_pool
            } else {
                market.no_pool
            };
            
            if (winning_pool == 0) {
                return principal
            };
            
            // Winner's share of yield = (vote.amount / winning_pool) * total_yield
            let yield_share = (vote.amount * market.total_yield) / winning_pool;
            return principal + yield_share
        };

        // STANDARD market type
        if (!is_winner) {
            return 0
        };

        // Calculate winner reward: (voter_stake / winning_pool) * total_pool
        let winning_pool = if (market.outcome == OUTCOME_YES) {
            market.yes_pool
        } else {
            market.no_pool
        };

        if (winning_pool == 0) {
            return 0
        };

        // Reward = (vote.amount * total_pool) / winning_pool
        (vote.amount * total_pool) / winning_pool
    }
}
