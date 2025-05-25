/// Module: reputation_system
/// Web3Lancer Reputation and Review Management Contract
module web3lancer::reputation_system {
    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use std::string::{Self, String};
    use std::vector;
    use sui::event;

    // ===== Errors =====
    const E_UNAUTHORIZED: u64 = 0;
    const E_INVALID_RATING: u64 = 1;
    const E_REVIEW_ALREADY_EXISTS: u64 = 2;
    const E_CANNOT_REVIEW_SELF: u64 = 3;
    const E_PROJECT_NOT_COMPLETED: u64 = 4;

    // ===== Structs =====
    
    /// Review Object
    public struct Review has key, store {
        id: UID,
        project_id: address,
        reviewer: address,
        reviewee: address,
        rating: u64, // 1-5 stars
        comment: String,
        skills_rating: u64, // 1-5
        communication_rating: u64, // 1-5
        timeliness_rating: u64, // 1-5
        quality_rating: u64, // 1-5
        is_client_review: bool, // true if client reviewing freelancer
        created_at: u64,
        is_disputed: bool,
        dispute_reason: String,
    }

    /// Reputation Badge
    public struct ReputationBadge has key, store {
        id: UID,
        owner: address,
        badge_type: String,
        level: u64,
        earned_at: u64,
        criteria_met: String,
    }

    /// Reputation Registry
    public struct ReputationRegistry has key {
        id: UID,
        total_reviews: u64,
        total_badges_issued: u64,
        average_platform_rating: u64, // 0-500 (5.00 max * 100)
    }

    /// Skill Verification
    public struct SkillVerification has key, store {
        id: UID,
        user: address,
        skill: String,
        verifier: address,
        verification_type: String, // "project", "certification", "peer"
        evidence_url: String,
        verified_at: u64,
        expiry_date: u64,
    }

    // ===== Events =====
    
    public struct ReviewSubmitted has copy, drop {
        review_id: address,
        project_id: address,
        reviewer: address,
        reviewee: address,
        rating: u64,
        timestamp: u64,
    }

    public struct BadgeEarned has copy, drop {
        badge_id: address,
        owner: address,
        badge_type: String,
        level: u64,
        timestamp: u64,
    }

    public struct SkillVerified has copy, drop {
        verification_id: address,
        user: address,
        skill: String,
        verifier: address,
        timestamp: u64,
    }

    public struct ReviewDisputed has copy, drop {
        review_id: address,
        disputer: address,
        reason: String,
        timestamp: u64,
    }

    // ===== Functions =====
    
    /// Initialize the reputation registry
    fun init(ctx: &mut TxContext) {
        let registry = ReputationRegistry {
            id: object::new(ctx),
            total_reviews: 0,
            total_badges_issued: 0,
            average_platform_rating: 0,
        };
        transfer::share_object(registry);
    }

    /// Submit a review for a completed project
    public entry fun submit_review(
        registry: &mut ReputationRegistry,
        project_id: address,
        reviewee: address,
        rating: u64,
        comment: vector<u8>,
        skills_rating: u64,
        communication_rating: u64,
        timeliness_rating: u64,
        quality_rating: u64,
        is_client_review: bool,
        ctx: &mut TxContext
    ) {
        let reviewer = tx_context::sender(ctx);
        
        // Validation
        assert!(reviewer != reviewee, E_CANNOT_REVIEW_SELF);
        assert!(rating >= 1 && rating <= 5, E_INVALID_RATING);
        assert!(skills_rating >= 1 && skills_rating <= 5, E_INVALID_RATING);
        assert!(communication_rating >= 1 && communication_rating <= 5, E_INVALID_RATING);
        assert!(timeliness_rating >= 1 && timeliness_rating <= 5, E_INVALID_RATING);
        assert!(quality_rating >= 1 && quality_rating <= 5, E_INVALID_RATING);

        let review = Review {
            id: object::new(ctx),
            project_id,
            reviewer,
            reviewee,
            rating,
            comment: string::utf8(comment),
            skills_rating,
            communication_rating,
            timeliness_rating,
            quality_rating,
            is_client_review,
            created_at: tx_context::epoch_timestamp_ms(ctx),
            is_disputed: false,
            dispute_reason: string::utf8(b""),
        };

        // Update registry stats
        registry.total_reviews = registry.total_reviews + 1;
        update_platform_average(registry, rating);

        event::emit(ReviewSubmitted {
            review_id: object::uid_to_address(&review.id),
            project_id,
            reviewer,
            reviewee,
            rating,
            timestamp: tx_context::epoch_timestamp_ms(ctx),
        });

        // Check for badge eligibility
        check_and_award_badges(registry, reviewee, ctx);

        transfer::share_object(review);
    }

    /// Award reputation badge
    public entry fun award_badge(
        registry: &mut ReputationRegistry,
        user: address,
        badge_type: vector<u8>,
        level: u64,
        criteria_met: vector<u8>,
        ctx: &mut TxContext
    ) {
        let badge = ReputationBadge {
            id: object::new(ctx),
            owner: user,
            badge_type: string::utf8(badge_type),
            level,
            earned_at: tx_context::epoch_timestamp_ms(ctx),
            criteria_met: string::utf8(criteria_met),
        };

        registry.total_badges_issued = registry.total_badges_issued + 1;

        event::emit(BadgeEarned {
            badge_id: object::uid_to_address(&badge.id),
            owner: user,
            badge_type: badge.badge_type,
            level,
            timestamp: tx_context::epoch_timestamp_ms(ctx),
        });

        transfer::transfer(badge, user);
    }

    /// Verify a skill
    public entry fun verify_skill(
        user: address,
        skill: vector<u8>,
        verification_type: vector<u8>,
        evidence_url: vector<u8>,
        expiry_date: u64,
        ctx: &mut TxContext
    ) {
        let verification = SkillVerification {
            id: object::new(ctx),
            user,
            skill: string::utf8(skill),
            verifier: tx_context::sender(ctx),
            verification_type: string::utf8(verification_type),
            evidence_url: string::utf8(evidence_url),
            verified_at: tx_context::epoch_timestamp_ms(ctx),
            expiry_date,
        };

        event::emit(SkillVerified {
            verification_id: object::uid_to_address(&verification.id),
            user,
            skill: verification.skill,
            verifier: verification.verifier,
            timestamp: tx_context::epoch_timestamp_ms(ctx),
        });

        transfer::transfer(verification, user);
    }

    /// Dispute a review
    public entry fun dispute_review(
        review: &mut Review,
        reason: vector<u8>,
        ctx: &mut TxContext
    ) {
        let disputer = tx_context::sender(ctx);
        assert!(disputer == review.reviewee, E_UNAUTHORIZED);
        assert!(!review.is_disputed, E_REVIEW_ALREADY_EXISTS);

        review.is_disputed = true;
        review.dispute_reason = string::utf8(reason);

        event::emit(ReviewDisputed {
            review_id: object::uid_to_address(&review.id),
            disputer,
            reason: string::utf8(reason),
            timestamp: tx_context::epoch_timestamp_ms(ctx),
        });
    }

    // ===== Helper Functions =====
    
    fun update_platform_average(registry: &mut ReputationRegistry, new_rating: u64) {
        let current_total = registry.average_platform_rating * (registry.total_reviews - 1);
        registry.average_platform_rating = (current_total + (new_rating * 100)) / registry.total_reviews;
    }

    fun check_and_award_badges(
        registry: &mut ReputationRegistry,
        user: address,
        ctx: &mut TxContext
    ) {
        // This function would contain logic to check various criteria
        // and automatically award badges based on achievements
        // For example: "First Review", "5-Star Rating", "Expert Level", etc.
        
        // Example: Award "Newcomer" badge for first review
        if (registry.total_reviews == 1) {
            let badge = ReputationBadge {
                id: object::new(ctx),
                owner: user,
                badge_type: string::utf8(b"Newcomer"),
                level: 1,
                earned_at: tx_context::epoch_timestamp_ms(ctx),
                criteria_met: string::utf8(b"Received first review"),
            };

            registry.total_badges_issued = registry.total_badges_issued + 1;

            event::emit(BadgeEarned {
                badge_id: object::uid_to_address(&badge.id),
                owner: user,
                badge_type: badge.badge_type,
                level: 1,
                timestamp: tx_context::epoch_timestamp_ms(ctx),
            });

            transfer::transfer(badge, user);
        }
    }

    // ===== View Functions =====
    
    public fun get_review_rating(review: &Review): u64 {
        review.rating
    }

    public fun get_review_details(review: &Review): (address, address, u64, bool) {
        (review.reviewer, review.reviewee, review.rating, review.is_disputed)
    }

    public fun get_skill_verification_details(verification: &SkillVerification): (address, String, address, u64) {
        (verification.user, verification.skill, verification.verifier, verification.verified_at)
    }

    public fun get_badge_details(badge: &ReputationBadge): (String, u64, u64) {
        (badge.badge_type, badge.level, badge.earned_at)
    }

    public fun get_registry_stats(registry: &ReputationRegistry): (u64, u64, u64) {
        (registry.total_reviews, registry.total_badges_issued, registry.average_platform_rating)
    }

    public fun is_review_disputed(review: &Review): bool {
        review.is_disputed
    }

    public fun get_detailed_ratings(review: &Review): (u64, u64, u64, u64) {
        (review.skills_rating, review.communication_rating, review.timeliness_rating, review.quality_rating)
    }
}