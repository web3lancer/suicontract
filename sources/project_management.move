/// Module: project_management
/// Web3Lancer Project Management and Escrow Contract
module web3lancer::project_management {
    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::balance::{Self, Balance};
    use std::string::{Self, String};
    use std::vector;
    use sui::event;
    use web3lancer::user_profile::{Self, UserProfile};

    // ===== Errors =====
    const E_UNAUTHORIZED: u64 = 0;
    const E_INVALID_STATUS: u64 = 1;
    const E_INSUFFICIENT_FUNDS: u64 = 2;
    const E_PROJECT_NOT_ACTIVE: u64 = 3;
    const E_MILESTONE_NOT_FOUND: u64 = 4;
    const E_ALREADY_COMPLETED: u64 = 5;
    const E_DISPUTE_ACTIVE: u64 = 6;

    // ===== Enums =====
    const PROJECT_STATUS_OPEN: u8 = 0;
    const PROJECT_STATUS_ACTIVE: u8 = 1;
    const PROJECT_STATUS_COMPLETED: u8 = 2;
    const PROJECT_STATUS_CANCELLED: u8 = 3;
    const PROJECT_STATUS_DISPUTED: u8 = 4;

    const MILESTONE_STATUS_PENDING: u8 = 0;
    const MILESTONE_STATUS_IN_PROGRESS: u8 = 1;
    const MILESTONE_STATUS_SUBMITTED: u8 = 2;
    const MILESTONE_STATUS_APPROVED: u8 = 3;
    const MILESTONE_STATUS_DISPUTED: u8 = 4;

    // ===== Structs =====
    
    /// Milestone for project completion tracking
    public struct Milestone has store {
        id: u64,
        title: String,
        description: String,
        amount: u64,
        status: u8,
        deadline: u64,
        submitted_at: u64,
        approved_at: u64,
    }

    /// Project Object
    public struct Project has key, store {
        id: UID,
        client: address,
        freelancer: address,
        title: String,
        description: String,
        total_budget: u64,
        escrow_balance: Balance<SUI>,
        milestones: vector<Milestone>,
        status: u8,
        created_at: u64,
        started_at: u64,
        completed_at: u64,
        dispute_reason: String,
    }

    /// Project Registry
    public struct ProjectRegistry has key {
        id: UID,
        total_projects: u64,
        active_projects: u64,
        completed_projects: u64,
        disputed_projects: u64,
        platform_fee_rate: u64, // Basis points (100 = 1%)
        platform_balance: Balance<SUI>,
    }

    /// Dispute Resolution Object
    public struct Dispute has key, store {
        id: UID,
        project_id: address,
        initiator: address,
        reason: String,
        evidence: String,
        resolution: String,
        arbitrator: address,
        created_at: u64,
        resolved_at: u64,
        is_resolved: bool,
    }

    // ===== Events =====
    
    public struct ProjectCreated has copy, drop {
        project_id: address,
        client: address,
        title: String,
        budget: u64,
        timestamp: u64,
    }

    public struct ProjectStarted has copy, drop {
        project_id: address,
        client: address,
        freelancer: address,
        timestamp: u64,
    }

    public struct MilestoneSubmitted has copy, drop {
        project_id: address,
        milestone_id: u64,
        freelancer: address,
        timestamp: u64,
    }

    public struct MilestoneApproved has copy, drop {
        project_id: address,
        milestone_id: u64,
        amount: u64,
        timestamp: u64,
    }

    public struct ProjectCompleted has copy, drop {
        project_id: address,
        client: address,
        freelancer: address,
        total_amount: u64,
        timestamp: u64,
    }

    public struct DisputeRaised has copy, drop {
        project_id: address,
        dispute_id: address,
        initiator: address,
        reason: String,
        timestamp: u64,
    }

    // ===== Functions =====
    
    /// Initialize the project registry
    fun init(ctx: &mut TxContext) {
        let registry = ProjectRegistry {
            id: object::new(ctx),
            total_projects: 0,
            active_projects: 0,
            completed_projects: 0,
            disputed_projects: 0,
            platform_fee_rate: 250, // 2.5%
            platform_balance: balance::zero(),
        };
        transfer::share_object(registry);
    }

    /// Create a new project
    public entry fun create_project(
        registry: &mut ProjectRegistry,
        title: vector<u8>,
        description: vector<u8>,
        payment: Coin<SUI>,
        milestone_titles: vector<vector<u8>>,
        milestone_descriptions: vector<vector<u8>>,
        milestone_amounts: vector<u64>,
        milestone_deadlines: vector<u64>,
        ctx: &mut TxContext
    ) {
        let total_budget = coin::value(&payment);
        let escrow_balance = coin::into_balance(payment);
        
        // Create milestones
        let milestones = vector::empty<Milestone>();
        let mut i = 0;
        let len = vector::length(&milestone_titles);
        
        while (i < len) {
            let milestone = Milestone {
                id: i,
                title: string::utf8(*vector::borrow(&milestone_titles, i)),
                description: string::utf8(*vector::borrow(&milestone_descriptions, i)),
                amount: *vector::borrow(&milestone_amounts, i),
                status: MILESTONE_STATUS_PENDING,
                deadline: *vector::borrow(&milestone_deadlines, i),
                submitted_at: 0,
                approved_at: 0,
            };
            vector::push_back(&mut milestones, milestone);
            i = i + 1;
        };

        let project = Project {
            id: object::new(ctx),
            client: tx_context::sender(ctx),
            freelancer: @0x0, // Will be set when freelancer accepts
            title: string::utf8(title),
            description: string::utf8(description),
            total_budget,
            escrow_balance,
            milestones,
            status: PROJECT_STATUS_OPEN,
            created_at: tx_context::epoch_timestamp_ms(ctx),
            started_at: 0,
            completed_at: 0,
            dispute_reason: string::utf8(b""),
        };

        registry.total_projects = registry.total_projects + 1;

        event::emit(ProjectCreated {
            project_id: object::uid_to_address(&project.id),
            client: tx_context::sender(ctx),
            title: project.title,
            budget: total_budget,
            timestamp: tx_context::epoch_timestamp_ms(ctx),
        });

        transfer::share_object(project);
    }

    /// Accept project as freelancer
    public entry fun accept_project(
        registry: &mut ProjectRegistry,
        project: &mut Project,
        ctx: &mut TxContext
    ) {
        assert!(project.status == PROJECT_STATUS_OPEN, E_INVALID_STATUS);
        
        project.freelancer = tx_context::sender(ctx);
        project.status = PROJECT_STATUS_ACTIVE;
        project.started_at = tx_context::epoch_timestamp_ms(ctx);
        
        registry.active_projects = registry.active_projects + 1;

        event::emit(ProjectStarted {
            project_id: object::uid_to_address(&project.id),
            client: project.client,
            freelancer: project.freelancer,
            timestamp: tx_context::epoch_timestamp_ms(ctx),
        });
    }

    /// Submit milestone completion
    public entry fun submit_milestone(
        project: &mut Project,
        milestone_id: u64,
        ctx: &mut TxContext
    ) {
        assert!(project.freelancer == tx_context::sender(ctx), E_UNAUTHORIZED);
        assert!(project.status == PROJECT_STATUS_ACTIVE, E_PROJECT_NOT_ACTIVE);
        
        let milestone = vector::borrow_mut(&mut project.milestones, milestone_id);
        assert!(milestone.status == MILESTONE_STATUS_PENDING || milestone.status == MILESTONE_STATUS_IN_PROGRESS, E_INVALID_STATUS);
        
        milestone.status = MILESTONE_STATUS_SUBMITTED;
        milestone.submitted_at = tx_context::epoch_timestamp_ms(ctx);

        event::emit(MilestoneSubmitted {
            project_id: object::uid_to_address(&project.id),
            milestone_id,
            freelancer: project.freelancer,
            timestamp: tx_context::epoch_timestamp_ms(ctx),
        });
    }

    /// Approve milestone and release payment
    public entry fun approve_milestone(
        registry: &mut ProjectRegistry,
        project: &mut Project,
        freelancer_profile: &mut UserProfile,
        milestone_id: u64,
        ctx: &mut TxContext
    ) {
        assert!(project.client == tx_context::sender(ctx), E_UNAUTHORIZED);
        assert!(project.status == PROJECT_STATUS_ACTIVE, E_PROJECT_NOT_ACTIVE);
        
        let milestone = vector::borrow_mut(&mut project.milestones, milestone_id);
        assert!(milestone.status == MILESTONE_STATUS_SUBMITTED, E_INVALID_STATUS);
        
        milestone.status = MILESTONE_STATUS_APPROVED;
        milestone.approved_at = tx_context::epoch_timestamp_ms(ctx);

        // Calculate platform fee
        let platform_fee = (milestone.amount * registry.platform_fee_rate) / 10000;
        let freelancer_payment = milestone.amount - platform_fee;

        // Transfer platform fee
        let fee_balance = balance::split(&mut project.escrow_balance, platform_fee);
        balance::join(&mut registry.platform_balance, fee_balance);

        // Transfer payment to freelancer
        let payment_balance = balance::split(&mut project.escrow_balance, freelancer_payment);
        let payment_coin = coin::from_balance(payment_balance, ctx);
        transfer::public_transfer(payment_coin, project.freelancer);

        // Update freelancer profile
        user_profile::update_reputation(freelancer_profile, 500); // 5.0 rating for approved milestone

        event::emit(MilestoneApproved {
            project_id: object::uid_to_address(&project.id),
            milestone_id,
            amount: freelancer_payment,
            timestamp: tx_context::epoch_timestamp_ms(ctx),
        });

        // Check if all milestones are completed
        if (all_milestones_approved(project)) {
            complete_project(registry, project, ctx);
        }
    }

    /// Complete project
    fun complete_project(
        registry: &mut ProjectRegistry,
        project: &mut Project,
        ctx: &mut TxContext
    ) {
        project.status = PROJECT_STATUS_COMPLETED;
        project.completed_at = tx_context::epoch_timestamp_ms(ctx);
        
        registry.active_projects = registry.active_projects - 1;
        registry.completed_projects = registry.completed_projects + 1;

        event::emit(ProjectCompleted {
            project_id: object::uid_to_address(&project.id),
            client: project.client,
            freelancer: project.freelancer,
            total_amount: project.total_budget,
            timestamp: tx_context::epoch_timestamp_ms(ctx),
        });
    }

    /// Raise a dispute
    public entry fun raise_dispute(
        registry: &mut ProjectRegistry,
        project: &mut Project,
        reason: vector<u8>,
        evidence: vector<u8>,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        assert!(sender == project.client || sender == project.freelancer, E_UNAUTHORIZED);
        assert!(project.status == PROJECT_STATUS_ACTIVE, E_PROJECT_NOT_ACTIVE);
        
        project.status = PROJECT_STATUS_DISPUTED;
        project.dispute_reason = string::utf8(reason);
        
        registry.disputed_projects = registry.disputed_projects + 1;
        registry.active_projects = registry.active_projects - 1;

        let dispute = Dispute {
            id: object::new(ctx),
            project_id: object::uid_to_address(&project.id),
            initiator: sender,
            reason: string::utf8(reason),
            evidence: string::utf8(evidence),
            resolution: string::utf8(b""),
            arbitrator: @0x0,
            created_at: tx_context::epoch_timestamp_ms(ctx),
            resolved_at: 0,
            is_resolved: false,
        };

        event::emit(DisputeRaised {
            project_id: object::uid_to_address(&project.id),
            dispute_id: object::uid_to_address(&dispute.id),
            initiator: sender,
            reason: string::utf8(reason),
            timestamp: tx_context::epoch_timestamp_ms(ctx),
        });

        transfer::share_object(dispute);
    }

    // ===== Helper Functions =====
    
    fun all_milestones_approved(project: &Project): bool {
        let mut i = 0;
        let len = vector::length(&project.milestones);
        
        while (i < len) {
            let milestone = vector::borrow(&project.milestones, i);
            if (milestone.status != MILESTONE_STATUS_APPROVED) {
                return false
            };
            i = i + 1;
        };
        
        true
    }

    // ===== View Functions =====
    
    public fun get_project_status(project: &Project): u8 {
        project.status
    }

    public fun get_project_budget(project: &Project): u64 {
        project.total_budget
    }

    public fun get_escrow_balance(project: &Project): u64 {
        balance::value(&project.escrow_balance)
    }

    public fun get_milestone_count(project: &Project): u64 {
        vector::length(&project.milestones)
    }

    public fun get_registry_stats(registry: &ProjectRegistry): (u64, u64, u64, u64) {
        (registry.total_projects, registry.active_projects, registry.completed_projects, registry.disputed_projects)
    }
}