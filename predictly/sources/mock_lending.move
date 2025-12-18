/// MockLending Module for Predictly
/// Simulates DeFi lending protocols for no-loss prediction markets
/// In production, this would be replaced with real protocol integrations
module predictly::mock_lending {
    use std::string::{Self, String};
    use std::signer;
    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::timestamp;
    use aptos_framework::event;
    use aptos_std::simple_map::{Self, SimpleMap};

    // ==================== Constants ====================

    // Protocol IDs
    const PROTOCOL_LAYERBANK: u8 = 0;     // 5% APY (500 bps)
    const PROTOCOL_CANOPY: u8 = 1;        // 4% APY (400 bps)
    const PROTOCOL_MOVEPOSITION: u8 = 2;  // 6% APY (600 bps)

    // APY in basis points (100 bps = 1%)
    const APY_LAYERBANK: u64 = 500;       // 5%
    const APY_CANOPY: u64 = 400;          // 4%
    const APY_MOVEPOSITION: u64 = 600;    // 6%

    // Seconds in a year (for yield calculation)
    const SECONDS_PER_YEAR: u64 = 31536000;

    // Basis points denominator
    const BPS_DENOMINATOR: u64 = 10000;

    // ==================== Error Codes ====================

    const E_NOT_ADMIN: u64 = 100;
    const E_POOL_NOT_FOUND: u64 = 101;
    const E_POOL_ALREADY_EXISTS: u64 = 102;
    const E_DEPOSIT_NOT_FOUND: u64 = 103;
    const E_ZERO_AMOUNT: u64 = 104;
    const E_INVALID_PROTOCOL: u64 = 105;
    const E_INSUFFICIENT_BALANCE: u64 = 106;

    // ==================== Structs ====================

    /// Global configuration for mock lending
    struct LendingConfig has key {
        admin: address,
    }

    /// Individual lending pool (one per protocol)
    struct LendingPool has key, store, copy, drop {
        protocol_id: u8,
        name: String,
        apy_bps: u64,
        total_deposits: u64,
    }

    /// Registry of all lending pools
    struct PoolRegistry has key {
        pools: SimpleMap<u8, LendingPool>,
    }

    /// Vault holding actual coins for each pool
    struct PoolVault has key {
        // protocol_id -> Coin
        vaults: SimpleMap<u8, Coin<AptosCoin>>,
    }

    /// Individual deposit info
    struct DepositInfo has store, drop, copy {
        depositor: address,
        amount: u64,
        timestamp: u64,
    }

    /// Registry of deposits per pool
    struct DepositRegistry has key {
        // protocol_id -> (depositor -> DepositInfo)
        deposits: SimpleMap<u8, SimpleMap<address, DepositInfo>>,
    }

    // ==================== Events ====================

    #[event]
    struct PoolInitialized has drop, store {
        protocol_id: u8,
        name: String,
        apy_bps: u64,
    }

    #[event]
    struct Deposited has drop, store {
        protocol_id: u8,
        depositor: address,
        amount: u64,
    }

    #[event]
    struct Withdrawn has drop, store {
        protocol_id: u8,
        depositor: address,
        principal: u64,
        yield_amount: u64,
    }

    // ==================== Entry Functions ====================

    /// Initialize the mock lending module (called once by admin)
    public entry fun initialize(admin: &signer) {
        let admin_addr = signer::address_of(admin);

        move_to(admin, LendingConfig {
            admin: admin_addr,
        });

        move_to(admin, PoolRegistry {
            pools: simple_map::new(),
        });

        move_to(admin, PoolVault {
            vaults: simple_map::new(),
        });

        move_to(admin, DepositRegistry {
            deposits: simple_map::new(),
        });
    }

    /// Initialize a lending pool for a specific protocol
    public entry fun initialize_pool(
        admin: &signer,
        protocol_id: u8,
    ) acquires LendingConfig, PoolRegistry, PoolVault, DepositRegistry {
        let admin_addr = signer::address_of(admin);
        
        // Verify admin
        let config = borrow_global<LendingConfig>(admin_addr);
        assert!(admin_addr == config.admin, E_NOT_ADMIN);

        // Validate protocol ID
        assert!(
            protocol_id == PROTOCOL_LAYERBANK || 
            protocol_id == PROTOCOL_CANOPY || 
            protocol_id == PROTOCOL_MOVEPOSITION,
            E_INVALID_PROTOCOL
        );

        // Get pool name and APY based on protocol
        let (name, apy_bps) = get_protocol_info(protocol_id);

        // Check pool doesn't already exist
        let pool_registry = borrow_global_mut<PoolRegistry>(admin_addr);
        assert!(!simple_map::contains_key(&pool_registry.pools, &protocol_id), E_POOL_ALREADY_EXISTS);

        // Create pool
        let pool = LendingPool {
            protocol_id,
            name,
            apy_bps,
            total_deposits: 0,
        };
        simple_map::add(&mut pool_registry.pools, protocol_id, pool);

        // Initialize vault for this pool
        let vault = borrow_global_mut<PoolVault>(admin_addr);
        simple_map::add(&mut vault.vaults, protocol_id, coin::zero<AptosCoin>());

        // Initialize deposit map for this pool
        let deposit_registry = borrow_global_mut<DepositRegistry>(admin_addr);
        simple_map::add(&mut deposit_registry.deposits, protocol_id, simple_map::new());

        // Emit event
        event::emit(PoolInitialized {
            protocol_id,
            name: pool.name,
            apy_bps,
        });
    }

    /// Deposit funds into a lending pool
    public entry fun deposit(
        depositor: &signer,
        admin_addr: address,
        protocol_id: u8,
        amount: u64,
    ) acquires PoolRegistry, PoolVault, DepositRegistry {
        let depositor_addr = signer::address_of(depositor);
        
        // Validate amount
        assert!(amount > 0, E_ZERO_AMOUNT);

        // Verify pool exists
        let pool_registry = borrow_global_mut<PoolRegistry>(admin_addr);
        assert!(simple_map::contains_key(&pool_registry.pools, &protocol_id), E_POOL_NOT_FOUND);

        // Transfer coins to vault
        let coins = coin::withdraw<AptosCoin>(depositor, amount);
        let vault = borrow_global_mut<PoolVault>(admin_addr);
        let pool_vault = simple_map::borrow_mut(&mut vault.vaults, &protocol_id);
        coin::merge(pool_vault, coins);

        // Update pool total
        let pool = simple_map::borrow_mut(&mut pool_registry.pools, &protocol_id);
        pool.total_deposits = pool.total_deposits + amount;

        // Record deposit
        let deposit_registry = borrow_global_mut<DepositRegistry>(admin_addr);
        let pool_deposits = simple_map::borrow_mut(&mut deposit_registry.deposits, &protocol_id);
        
        let current_time = timestamp::now_seconds();
        
        // If depositor already has a deposit, add to it
        if (simple_map::contains_key(pool_deposits, &depositor_addr)) {
            let existing = simple_map::borrow_mut(pool_deposits, &depositor_addr);
            // Calculate pending yield on existing deposit first
            let pending_yield = calculate_yield_internal(existing.amount, existing.timestamp, current_time, pool.apy_bps);
            // Add new amount + pending yield to principal
            existing.amount = existing.amount + amount + pending_yield;
            existing.timestamp = current_time;
        } else {
            let deposit_info = DepositInfo {
                depositor: depositor_addr,
                amount,
                timestamp: current_time,
            };
            simple_map::add(pool_deposits, depositor_addr, deposit_info);
        };

        // Emit event
        event::emit(Deposited {
            protocol_id,
            depositor: depositor_addr,
            amount,
        });
    }

    /// Withdraw funds from a lending pool (principal + yield)
    public entry fun withdraw(
        depositor: &signer,
        admin_addr: address,
        protocol_id: u8,
    ) acquires PoolRegistry, PoolVault, DepositRegistry {
        let depositor_addr = signer::address_of(depositor);

        // Verify pool exists
        let pool_registry = borrow_global_mut<PoolRegistry>(admin_addr);
        assert!(simple_map::contains_key(&pool_registry.pools, &protocol_id), E_POOL_NOT_FOUND);
        let pool = simple_map::borrow_mut(&mut pool_registry.pools, &protocol_id);

        // Get deposit info
        let deposit_registry = borrow_global_mut<DepositRegistry>(admin_addr);
        let pool_deposits = simple_map::borrow_mut(&mut deposit_registry.deposits, &protocol_id);
        assert!(simple_map::contains_key(pool_deposits, &depositor_addr), E_DEPOSIT_NOT_FOUND);

        let deposit_info = simple_map::borrow(pool_deposits, &depositor_addr);
        let principal = deposit_info.amount;
        let deposit_time = deposit_info.timestamp;

        // Calculate yield
        let current_time = timestamp::now_seconds();
        let yield_amount = calculate_yield_internal(principal, deposit_time, current_time, pool.apy_bps);
        let total_amount = principal + yield_amount;

        // Update pool total (only subtract principal, yield is "generated")
        pool.total_deposits = pool.total_deposits - principal;

        // Remove deposit record
        simple_map::remove(pool_deposits, &depositor_addr);

        // Transfer coins from vault
        let vault = borrow_global_mut<PoolVault>(admin_addr);
        let pool_vault = simple_map::borrow_mut(&mut vault.vaults, &protocol_id);
        
        // For mock purposes, we mint the yield (in real DeFi, yield comes from protocol)
        // Here we just transfer what's available (principal) and the yield is simulated
        let available = coin::value(pool_vault);
        let transfer_amount = if (total_amount > available) { available } else { total_amount };
        
        let coins = coin::extract(pool_vault, transfer_amount);
        coin::deposit(depositor_addr, coins);

        // Emit event
        event::emit(Withdrawn {
            protocol_id,
            depositor: depositor_addr,
            principal,
            yield_amount,
        });
    }

    // ==================== View Functions ====================

    #[view]
    /// Get current balance (principal only)
    public fun get_balance(admin_addr: address, protocol_id: u8, depositor: address): u64 acquires DepositRegistry {
        let deposit_registry = borrow_global<DepositRegistry>(admin_addr);
        
        if (!simple_map::contains_key(&deposit_registry.deposits, &protocol_id)) {
            return 0
        };
        
        let pool_deposits = simple_map::borrow(&deposit_registry.deposits, &protocol_id);
        
        if (!simple_map::contains_key(pool_deposits, &depositor)) {
            return 0
        };
        
        let deposit_info = simple_map::borrow(pool_deposits, &depositor);
        deposit_info.amount
    }

    #[view]
    /// Get pending yield for a depositor
    public fun get_pending_yield(admin_addr: address, protocol_id: u8, depositor: address): u64 acquires PoolRegistry, DepositRegistry {
        let deposit_registry = borrow_global<DepositRegistry>(admin_addr);
        
        if (!simple_map::contains_key(&deposit_registry.deposits, &protocol_id)) {
            return 0
        };
        
        let pool_deposits = simple_map::borrow(&deposit_registry.deposits, &protocol_id);
        
        if (!simple_map::contains_key(pool_deposits, &depositor)) {
            return 0
        };
        
        let deposit_info = simple_map::borrow(pool_deposits, &depositor);
        
        // Get pool APY
        let pool_registry = borrow_global<PoolRegistry>(admin_addr);
        let pool = simple_map::borrow(&pool_registry.pools, &protocol_id);
        
        let current_time = timestamp::now_seconds();
        calculate_yield_internal(deposit_info.amount, deposit_info.timestamp, current_time, pool.apy_bps)
    }

    #[view]
    /// Get total with yield (principal, yield)
    public fun get_total_with_yield(admin_addr: address, protocol_id: u8, depositor: address): (u64, u64) acquires PoolRegistry, DepositRegistry {
        let principal = get_balance(admin_addr, protocol_id, depositor);
        let yield_amount = get_pending_yield(admin_addr, protocol_id, depositor);
        (principal, yield_amount)
    }

    #[view]
    /// Get pool info
    public fun get_pool_info(admin_addr: address, protocol_id: u8): LendingPool acquires PoolRegistry {
        let pool_registry = borrow_global<PoolRegistry>(admin_addr);
        assert!(simple_map::contains_key(&pool_registry.pools, &protocol_id), E_POOL_NOT_FOUND);
        *simple_map::borrow(&pool_registry.pools, &protocol_id)
    }

    // ==================== Internal Functions ====================

    /// Get protocol name and APY based on protocol ID
    fun get_protocol_info(protocol_id: u8): (String, u64) {
        if (protocol_id == PROTOCOL_LAYERBANK) {
            (string::utf8(b"LayerBank"), APY_LAYERBANK)
        } else if (protocol_id == PROTOCOL_CANOPY) {
            (string::utf8(b"Canopy"), APY_CANOPY)
        } else {
            (string::utf8(b"MovePosition"), APY_MOVEPOSITION)
        }
    }

    /// Calculate yield based on principal, time, and APY
    /// yield = principal * (apy_bps / 10000) * (seconds_staked / 31536000)
    fun calculate_yield_internal(principal: u64, deposit_time: u64, current_time: u64, apy_bps: u64): u64 {
        if (current_time <= deposit_time) {
            return 0
        };
        
        let seconds_staked = current_time - deposit_time;
        
        // To avoid overflow, we calculate: (principal * apy_bps * seconds_staked) / (BPS_DENOMINATOR * SECONDS_PER_YEAR)
        // Rearranged: (principal * seconds_staked / SECONDS_PER_YEAR) * apy_bps / BPS_DENOMINATOR
        
        // First calculate time fraction (scaled by 1e6 for precision)
        let time_fraction_scaled = (seconds_staked * 1000000) / SECONDS_PER_YEAR;
        
        // Then calculate yield
        let yield_amount = (principal * apy_bps * time_fraction_scaled) / (BPS_DENOMINATOR * 1000000);
        
        yield_amount
    }

    // ==================== Public Functions for Market Module ====================

    /// Deposit from market module (for no-loss markets)
    public fun deposit_from_market(
        market_coins: Coin<AptosCoin>,
        admin_addr: address,
        protocol_id: u8,
        market_addr: address,
    ) acquires PoolRegistry, PoolVault, DepositRegistry {
        let amount = coin::value(&market_coins);
        assert!(amount > 0, E_ZERO_AMOUNT);

        // Verify pool exists
        let pool_registry = borrow_global_mut<PoolRegistry>(admin_addr);
        assert!(simple_map::contains_key(&pool_registry.pools, &protocol_id), E_POOL_NOT_FOUND);

        // Transfer coins to vault
        let vault = borrow_global_mut<PoolVault>(admin_addr);
        let pool_vault = simple_map::borrow_mut(&mut vault.vaults, &protocol_id);
        coin::merge(pool_vault, market_coins);

        // Update pool total
        let pool = simple_map::borrow_mut(&mut pool_registry.pools, &protocol_id);
        pool.total_deposits = pool.total_deposits + amount;

        // Record deposit using market address as depositor
        let deposit_registry = borrow_global_mut<DepositRegistry>(admin_addr);
        let pool_deposits = simple_map::borrow_mut(&mut deposit_registry.deposits, &protocol_id);
        
        let current_time = timestamp::now_seconds();
        
        if (simple_map::contains_key(pool_deposits, &market_addr)) {
            let existing = simple_map::borrow_mut(pool_deposits, &market_addr);
            let pending_yield = calculate_yield_internal(existing.amount, existing.timestamp, current_time, pool.apy_bps);
            existing.amount = existing.amount + amount + pending_yield;
            existing.timestamp = current_time;
        } else {
            let deposit_info = DepositInfo {
                depositor: market_addr,
                amount,
                timestamp: current_time,
            };
            simple_map::add(pool_deposits, market_addr, deposit_info);
        };
    }

    /// Withdraw from market module (for no-loss markets)
    /// Returns (principal, yield) as separate coin amounts
    public fun withdraw_to_market(
        admin_addr: address,
        protocol_id: u8,
        market_addr: address,
    ): (Coin<AptosCoin>, u64) acquires PoolRegistry, PoolVault, DepositRegistry {
        // Verify pool exists
        let pool_registry = borrow_global_mut<PoolRegistry>(admin_addr);
        assert!(simple_map::contains_key(&pool_registry.pools, &protocol_id), E_POOL_NOT_FOUND);
        let pool = simple_map::borrow_mut(&mut pool_registry.pools, &protocol_id);

        // Get deposit info
        let deposit_registry = borrow_global_mut<DepositRegistry>(admin_addr);
        let pool_deposits = simple_map::borrow_mut(&mut deposit_registry.deposits, &protocol_id);
        assert!(simple_map::contains_key(pool_deposits, &market_addr), E_DEPOSIT_NOT_FOUND);

        let deposit_info = simple_map::borrow(pool_deposits, &market_addr);
        let principal = deposit_info.amount;
        let deposit_time = deposit_info.timestamp;

        // Calculate yield
        let current_time = timestamp::now_seconds();
        let yield_amount = calculate_yield_internal(principal, deposit_time, current_time, pool.apy_bps);

        // Update pool total
        pool.total_deposits = pool.total_deposits - principal;

        // Remove deposit record
        simple_map::remove(pool_deposits, &market_addr);

        // Extract coins from vault (principal only, yield is simulated)
        let vault = borrow_global_mut<PoolVault>(admin_addr);
        let pool_vault = simple_map::borrow_mut(&mut vault.vaults, &protocol_id);
        let coins = coin::extract(pool_vault, principal);

        (coins, yield_amount)
    }
}
