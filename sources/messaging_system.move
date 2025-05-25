/// Module: messaging_system
/// Web3Lancer Messaging and Notification System
module web3lancer::messaging_system {
    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use std::string::{Self, String};
    use std::vector;
    use sui::event;

    // ===== Errors =====
    const E_UNAUTHORIZED: u64 = 0;
    const E_CONVERSATION_NOT_FOUND: u64 = 1;
    const E_MESSAGE_NOT_FOUND: u64 = 2;
    const E_CANNOT_MESSAGE_SELF: u64 = 3;

    // ===== Enums =====
    const MESSAGE_TYPE_TEXT: u8 = 0;
    const MESSAGE_TYPE_FILE: u8 = 1;
    const MESSAGE_TYPE_PROJECT_UPDATE: u8 = 2;
    const MESSAGE_TYPE_SYSTEM: u8 = 3;

    const NOTIFICATION_TYPE_MESSAGE: u8 = 0;
    const NOTIFICATION_TYPE_PROJECT: u8 = 1;
    const NOTIFICATION_TYPE_PAYMENT: u8 = 2;
    const NOTIFICATION_TYPE_REVIEW: u8 = 3;
    const NOTIFICATION_TYPE_SYSTEM: u8 = 4;

    // ===== Structs =====
    
    /// Message Object
    public struct Message has store {
        id: u64,
        sender: address,
        content: String,
        message_type: u8,
        file_url: String,
        timestamp: u64,
        is_read: bool,
        reply_to: u64, // ID of message being replied to, 0 if none
    }

    /// Conversation Object
    public struct Conversation has key, store {
        id: UID,
        participants: vector<address>,
        project_id: address, // Associated project, @0x0 if general conversation
        messages: vector<Message>,
        last_message_time: u64,
        created_at: u64,
        is_archived: bool,
        unread_count: vector<u64>, // Unread count for each participant
    }

    /// Notification Object
    public struct Notification has key, store {
        id: UID,
        recipient: address,
        sender: address,
        title: String,
        content: String,
        notification_type: u8,
        related_id: address, // ID of related object (project, message, etc.)
        is_read: bool,
        created_at: u64,
        action_url: String,
    }

    /// Messaging Registry
    public struct MessagingRegistry has key {
        id: UID,
        total_conversations: u64,
        total_messages: u64,
        total_notifications: u64,
    }

    // ===== Events =====
    
    public struct ConversationCreated has copy, drop {
        conversation_id: address,
        participants: vector<address>,
        project_id: address,
        timestamp: u64,
    }

    public struct MessageSent has copy, drop {
        conversation_id: address,
        message_id: u64,
        sender: address,
        recipient: address,
        timestamp: u64,
    }

    public struct NotificationCreated has copy, drop {
        notification_id: address,
        recipient: address,
        sender: address,
        notification_type: u8,
        timestamp: u64,
    }

    public struct MessageRead has copy, drop {
        conversation_id: address,
        message_id: u64,
        reader: address,
        timestamp: u64,
    }

    // ===== Functions =====
    
    /// Initialize the messaging registry
    fun init(ctx: &mut TxContext) {
        let registry = MessagingRegistry {
            id: object::new(ctx),
            total_conversations: 0,
            total_messages: 0,
            total_notifications: 0,
        };
        transfer::share_object(registry);
    }

    /// Create a new conversation
    public entry fun create_conversation(
        registry: &mut MessagingRegistry,
        other_participant: address,
        project_id: address,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        assert!(sender != other_participant, E_CANNOT_MESSAGE_SELF);

        let participants = vector::empty<address>();
        vector::push_back(&mut participants, sender);
        vector::push_back(&mut participants, other_participant);

        let unread_count = vector::empty<u64>();
        vector::push_back(&mut unread_count, 0);
        vector::push_back(&mut unread_count, 0);

        let conversation = Conversation {
            id: object::new(ctx),
            participants,
            project_id,
            messages: vector::empty(),
            last_message_time: tx_context::epoch_timestamp_ms(ctx),
            created_at: tx_context::epoch_timestamp_ms(ctx),
            is_archived: false,
            unread_count,
        };

        registry.total_conversations = registry.total_conversations + 1;

        event::emit(ConversationCreated {
            conversation_id: object::uid_to_address(&conversation.id),
            participants: conversation.participants,
            project_id,
            timestamp: tx_context::epoch_timestamp_ms(ctx),
        });

        transfer::share_object(conversation);
    }

    /// Send a message in a conversation
    public entry fun send_message(
        registry: &mut MessagingRegistry,
        conversation: &mut Conversation,
        content: vector<u8>,
        message_type: u8,
        file_url: vector<u8>,
        reply_to: u64,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        
        // Verify sender is a participant
        assert!(vector::contains(&conversation.participants, &sender), E_UNAUTHORIZED);

        let message_id = vector::length(&conversation.messages);
        let message = Message {
            id: message_id,
            sender,
            content: string::utf8(content),
            message_type,
            file_url: string::utf8(file_url),
            timestamp: tx_context::epoch_timestamp_ms(ctx),
            is_read: false,
            reply_to,
        };

        vector::push_back(&mut conversation.messages, message);
        conversation.last_message_time = tx_context::epoch_timestamp_ms(ctx);

        // Update unread count for other participants
        let mut i = 0;
        let len = vector::length(&conversation.participants);
        while (i < len) {
            let participant = *vector::borrow(&conversation.participants, i);
            if (participant != sender) {
                let unread_ref = vector::borrow_mut(&mut conversation.unread_count, i);
                *unread_ref = *unread_ref + 1;

                event::emit(MessageSent {
                    conversation_id: object::uid_to_address(&conversation.id),
                    message_id,
                    sender,
                    recipient: participant,
                    timestamp: tx_context::epoch_timestamp_ms(ctx),
                });
            };
            i = i + 1;
        };

        registry.total_messages = registry.total_messages + 1;
    }

    /// Mark messages as read
    public entry fun mark_messages_read(
        conversation: &mut Conversation,
        up_to_message_id: u64,
        ctx: &mut TxContext
    ) {
        let reader = tx_context::sender(ctx);
        assert!(vector::contains(&conversation.participants, &reader), E_UNAUTHORIZED);

        // Find reader's index
        let reader_index = 0;
        let mut i = 0;
        let len = vector::length(&conversation.participants);
        while (i < len) {
            if (*vector::borrow(&conversation.participants, i) == reader) {
                reader_index = i;
                break
            };
            i = i + 1;
        };

        // Reset unread count for this participant
        let unread_ref = vector::borrow_mut(&mut conversation.unread_count, reader_index);
        *unread_ref = 0;

        // Mark individual messages as read
        let mut j = 0;
        let msg_len = vector::length(&conversation.messages);
        while (j <= up_to_message_id && j < msg_len) {
            let message = vector::borrow_mut(&mut conversation.messages, j);
            if (message.sender != reader) {
                message.is_read = true;
                
                event::emit(MessageRead {
                    conversation_id: object::uid_to_address(&conversation.id),
                    message_id: j,
                    reader,
                    timestamp: tx_context::epoch_timestamp_ms(ctx),
                });
            };
            j = j + 1;
        };
    }

    /// Create a notification
    public entry fun create_notification(
        registry: &mut MessagingRegistry,
        recipient: address,
        title: vector<u8>,
        content: vector<u8>,
        notification_type: u8,
        related_id: address,
        action_url: vector<u8>,
        ctx: &mut TxContext
    ) {
        let notification = Notification {
            id: object::new(ctx),
            recipient,
            sender: tx_context::sender(ctx),
            title: string::utf8(title),
            content: string::utf8(content),
            notification_type,
            related_id,
            is_read: false,
            created_at: tx_context::epoch_timestamp_ms(ctx),
            action_url: string::utf8(action_url),
        };

        registry.total_notifications = registry.total_notifications + 1;

        event::emit(NotificationCreated {
            notification_id: object::uid_to_address(&notification.id),
            recipient,
            sender: notification.sender,
            notification_type,
            timestamp: tx_context::epoch_timestamp_ms(ctx),
        });

        transfer::transfer(notification, recipient);
    }

    /// Mark notification as read
    public entry fun mark_notification_read(
        notification: &mut Notification,
        ctx: &mut TxContext
    ) {
        assert!(notification.recipient == tx_context::sender(ctx), E_UNAUTHORIZED);
        notification.is_read = true;
    }

    /// Archive conversation
    public entry fun archive_conversation(
        conversation: &mut Conversation,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        assert!(vector::contains(&conversation.participants, &sender), E_UNAUTHORIZED);
        conversation.is_archived = true;
    }

    // ===== Helper Functions =====
    
    public fun send_system_notification(
        registry: &mut MessagingRegistry,
        recipient: address,
        title: vector<u8>,
        content: vector<u8>,
        related_id: address,
        ctx: &mut TxContext
    ) {
        let notification = Notification {
            id: object::new(ctx),
            recipient,
            sender: @0x0, // System sender
            title: string::utf8(title),
            content: string::utf8(content),
            notification_type: NOTIFICATION_TYPE_SYSTEM,
            related_id,
            is_read: false,
            created_at: tx_context::epoch_timestamp_ms(ctx),
            action_url: string::utf8(b""),
        };

        registry.total_notifications = registry.total_notifications + 1;

        event::emit(NotificationCreated {
            notification_id: object::uid_to_address(&notification.id),
            recipient,
            sender: @0x0,
            notification_type: NOTIFICATION_TYPE_SYSTEM,
            timestamp: tx_context::epoch_timestamp_ms(ctx),
        });

        transfer::transfer(notification, recipient);
    }

    // ===== View Functions =====
    
    public fun get_conversation_participants(conversation: &Conversation): &vector<address> {
        &conversation.participants
    }

    public fun get_message_count(conversation: &Conversation): u64 {
        vector::length(&conversation.messages)
    }

    public fun get_unread_count(conversation: &Conversation, participant_index: u64): u64 {
        *vector::borrow(&conversation.unread_count, participant_index)
    }

    public fun get_last_message_time(conversation: &Conversation): u64 {
        conversation.last_message_time
    }

    public fun is_conversation_archived(conversation: &Conversation): bool {
        conversation.is_archived
    }

    public fun get_notification_details(notification: &Notification): (String, String, u8, bool) {
        (notification.title, notification.content, notification.notification_type, notification.is_read)
    }

    public fun get_registry_stats(registry: &MessagingRegistry): (u64, u64, u64) {
        (registry.total_conversations, registry.total_messages, registry.total_notifications)
    }

    public fun get_message_details(conversation: &Conversation, message_id: u64): (address, String, u64, bool) {
        let message = vector::borrow(&conversation.messages, message_id);
        (message.sender, message.content, message.timestamp, message.is_read)
    }
}