/// Module: user_profile
/// Web3Lancer User Profile Management Contract
module web3lancer::user_profile {
    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use std::string::{Self, String};
    use std::vector;
    use sui::event;

    // ===== Errors =====
    const E_PROFILE_ALREADY_EXISTS: u64 = 0;
    const E_PROFILE_NOT_FOUND: u64 = 1;
    const E_UNAUTHORIZED: u64 = 2;
    const E_INVALID_RATING: u64 = 3;

    // ===== Structs =====
    
    /// User Profile Object
    public struct UserProfile has key, store {
        id: UID,
        owner: address,
        username: String,
        email: String,
        bio: String,
        skills: vector<String>,
        portfolio_links: vector<String>,
        hourly_rate: u64,
        total_earnings: u64,
        projects_completed: u64,
        reputation_score: u64, // 0-500 (5.00 max rating * 100)
        total_reviews: u64,
        is_verified: bool,
        created_at: u64,
        updated_at: u64,
    }

    /// Profile Registry - keeps track of all profiles
    public struct ProfileRegistry has key {
        id: UID,
        total_profiles: u64,
        verified_profiles: u64,
    }

    // ===== Events =====
    
    public struct ProfileCreated has copy, drop {
        profile_id: address,
        owner: address,
        username: String,
        timestamp: u64,
    }

    public struct ProfileUpdated has copy, drop {
        profile_id: address,
        owner: address,
        timestamp: u64,
    }

    public struct ProfileVerified has copy, drop {
        profile_id: address,
        owner: address,
        timestamp: u64,
    }

    // ===== Functions =====
    
    /// Initialize the profile registry
    fun init(ctx: &mut TxContext) {
        let registry = ProfileRegistry {
            id: object::new(ctx),
            total_profiles: 0,
            verified_profiles: 0,
        };
        transfer::share_object(registry);
    }

    /// Create a new user profile
    public entry fun create_profile(
        registry: &mut ProfileRegistry,
        username: vector<u8>,
        email: vector<u8>,
        bio: vector<u8>,
        hourly_rate: u64,
        ctx: &mut TxContext
    ) {
        let profile = UserProfile {
            id: object::new(ctx),
            owner: tx_context::sender(ctx),
            username: string::utf8(username),
            email: string::utf8(email),
            bio: string::utf8(bio),
            skills: vector::empty(),
            portfolio_links: vector::empty(),
            hourly_rate,
            total_earnings: 0,
            projects_completed: 0,
            reputation_score: 0,
            total_reviews: 0,
            is_verified: false,
            created_at: tx_context::epoch_timestamp_ms(ctx),
            updated_at: tx_context::epoch_timestamp_ms(ctx),
        };

        registry.total_profiles = registry.total_profiles + 1;

        event::emit(ProfileCreated {
            profile_id: object::uid_to_address(&profile.id),
            owner: tx_context::sender(ctx),
            username: profile.username,
            timestamp: tx_context::epoch_timestamp_ms(ctx),
        });

        transfer::transfer(profile, tx_context::sender(ctx));
    }

    /// Update profile information
    public entry fun update_profile(
        profile: &mut UserProfile,
        bio: vector<u8>,
        hourly_rate: u64,
        ctx: &mut TxContext
    ) {
        assert!(profile.owner == tx_context::sender(ctx), E_UNAUTHORIZED);
        
        profile.bio = string::utf8(bio);
        profile.hourly_rate = hourly_rate;
        profile.updated_at = tx_context::epoch_timestamp_ms(ctx);

        event::emit(ProfileUpdated {
            profile_id: object::uid_to_address(&profile.id),
            owner: profile.owner,
            timestamp: tx_context::epoch_timestamp_ms(ctx),
        });
    }

    /// Add a skill to the profile
    public entry fun add_skill(
        profile: &mut UserProfile,
        skill: vector<u8>,
        ctx: &mut TxContext
    ) {
        assert!(profile.owner == tx_context::sender(ctx), E_UNAUTHORIZED);
        vector::push_back(&mut profile.skills, string::utf8(skill));
        profile.updated_at = tx_context::epoch_timestamp_ms(ctx);
    }

    /// Add a portfolio link
    public entry fun add_portfolio_link(
        profile: &mut UserProfile,
        link: vector<u8>,
        ctx: &mut TxContext
    ) {
        assert!(profile.owner == tx_context::sender(ctx), E_UNAUTHORIZED);
        vector::push_back(&mut profile.portfolio_links, string::utf8(link));
        profile.updated_at = tx_context::epoch_timestamp_ms(ctx);
    }

    /// Update reputation score (called by project contract)
    public(package) fun update_reputation(
        profile: &mut UserProfile,
        rating: u64, // 0-500 (representing 0.00-5.00)
    ) {
        assert!(rating <= 500, E_INVALID_RATING);
        
        let current_total = profile.reputation_score * profile.total_reviews;
        profile.total_reviews = profile.total_reviews + 1;
        profile.reputation_score = (current_total + rating) / profile.total_reviews;
    }

    /// Mark profile as verified (admin function)
    public entry fun verify_profile(
        registry: &mut ProfileRegistry,
        profile: &mut UserProfile,
        _admin_cap: &AdminCap,
        ctx: &mut TxContext
    ) {
        if (!profile.is_verified) {
            profile.is_verified = true;
            registry.verified_profiles = registry.verified_profiles + 1;
            
            event::emit(ProfileVerified {
                profile_id: object::uid_to_address(&profile.id),
                owner: profile.owner,
                timestamp: tx_context::epoch_timestamp_ms(ctx),
            });
        }
    }

    /// Admin capability for profile verification
    public struct AdminCap has key {
        id: UID,
    }

    /// Create admin capability (one-time function)
    public entry fun create_admin_cap(ctx: &mut TxContext) {
        let admin_cap = AdminCap {
            id: object::new(ctx),
        };
        transfer::transfer(admin_cap, tx_context::sender(ctx));
    }

    // ===== View Functions =====
    
    public fun get_profile_owner(profile: &UserProfile): address {
        profile.owner
    }

    public fun get_username(profile: &UserProfile): &String {
        &profile.username
    }

    public fun get_reputation_score(profile: &UserProfile): u64 {
        profile.reputation_score
    }

    public fun get_total_earnings(profile: &UserProfile): u64 {
        profile.total_earnings
    }

    public fun get_projects_completed(profile: &UserProfile): u64 {
        profile.projects_completed
    }

    public fun is_verified(profile: &UserProfile): bool {
        profile.is_verified
    }

    public fun get_registry_stats(registry: &ProfileRegistry): (u64, u64) {
        (registry.total_profiles, registry.verified_profiles)
    }
}


