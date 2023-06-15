//
//  BotMessage.swift
//  
//
//  Created by Vincent Kwok on 22/11/22.
//

import Foundation
import DiscordKitCore

/// A Discord message, with convenience methods.
public struct Message: Identifiable {
    /// ID of the message
    public let id: Snowflake

    /// Channel the message was sent in
    public var channel: TextChannel {
        get async throws {
             return try await TextChannel(from: coreMessage.channel_id)
        }
    }

    /// ID of the channel the message was sent in
    private let channelID: Snowflake

    /// The guild the message was sent in
    public var guild: Guild? {
        get async throws {
            if let guildID = coreMessage.guild_id {
                return try await Guild(id: guildID)
            }
            return nil
        }
    }

    /// The author of this message (not guaranteed to be a valid user, see discussion)
    ///
    /// Will not be a valid user if the message was sent by a webhook.
    /// > The author object follows the structure of the user object,
    /// > but is only a valid user in the case where the message is generated
    /// > by a user or bot user. If the message is generated by a webhook, the
    /// > author object corresponds to the webhook's id, username, and avatar.
    /// > You can tell if a message is generated by a webhook by checking for
    /// > the webhook_id on the message object.
    public var author: User

    /// Member properties for this message's author
    public var member: Member? {
        get async throws {
            if let messageMember = coreMessage.member {
                return Member(from: messageMember, rest: rest)
            }
            return nil
        }
    }

    /// Contents of the message
    ///
    /// Up to 2000 characters for non-premium users.
    public var content: String

    /// When this message was sent
    public let timestamp: Date

    /// When this message was edited (or null if never)
    public var editedTimestamp: Date?

    /// If this was a TTS message
    public var tts: Bool

    /// Whether this message mentions everyone
    public var mentionEveryone: Bool

    /// Users specifically mentioned in the message
    public var mentions: [User]

    /// Roles specifically mentioned in this message
    public var mentionRoles: [Snowflake]

    /// Channels specifically mentioned in this message
    public var mentionChannels: [ChannelMention]?

    /// Any attached files
    public var attachments: [Attachment]

    /// Any embedded content
    public var embeds: [Embed]

    /// Reactions to the message
    public var reactions: [Reaction]?
    // Nonce can either be string or int and isn't important so I'm not including it for now

    /// If this message is pinned
    public var pinned: Bool

    /// If the message is generated by a webhook, this is the webhook's ID
    ///
    /// Use this to check if the message is sent by a webhook. ``author``
    /// will not be valid if this is not nil (was sent by a webhook).
    public var webhookID: Snowflake?

    /// Type of message
    ///
    /// Refer to ``MessageType`` for possible values.
    public let type: MessageType

    /// Sent with Rich Presence-related chat embeds
    public var activity: MessageActivity?

    /// Sent with Rich Presence-related chat embeds
    public var application: Application?

    /// If the message is an Interaction or application-owned webhook, this is the ID of the application
    public var application_id: Snowflake?

    /// Data showing the source of a crosspost, channel follow add, pin, or reply message
    public var messageReference: MessageReference?

    /// Message flags
    public var flags: Int?

    /// The message associated with the message\_reference
    ///
    /// This field is only returned for messages with a type of ``MessageType/reply``
    /// or ``MessageType/threadStarterMsg``. If the message is a reply but the
    /// referenced\_message field is not present, the backend did not attempt to
    /// fetch the message that was being replied to, so its state is unknown. If
    /// the field exists but is null, the referenced message was deleted.
    ///
    /// > Currently, it is not possible to distinguish between the field being `nil`
    /// > or the field not being present. This is due to limitations with the built-in
    /// > `Decodable` type.
    public let referencedMessage: DiscordKitCore.Message?

    /// Present if the message is a response to an Interaction
    public var interaction: MessageInteraction?

    /// The thread that was started from this message, includes thread member object
    public var thread: Channel?

    /// Present if the message contains components like buttons, action rows, or other interactive components
    public var components: [MessageComponent]?

    /// Present if the message contains stickers
    public var stickers: [StickerItem]?

    /// Present if the message is a call in DM
    public var call: CallMessageComponent?

    /// The url to jump to this message
    public var jumpURL: URL?

    // The REST handler associated with this message, used for message actions
    private var rest: DiscordREST

    private var coreMessage: DiscordKitCore.Message

    internal init(from message: DiscordKitCore.Message, rest: DiscordREST) async {
        content = message.content
        channelID = message.channel_id
        id = message.id
        author = message.author
        timestamp = message.timestamp
        editedTimestamp = message.edited_timestamp
        tts = message.tts
        mentionEveryone = message.mention_everyone
        mentions = message.mentions
        mentionRoles = message.mention_roles
        mentionChannels = message.mention_channels
        attachments = message.attachments
        embeds = message.embeds
        reactions = message.reactions
        pinned = message.pinned
        webhookID = message.webhook_id
        type = MessageType(message.type)!
        activity = message.activity
        application = message.application
        application_id = message.application_id
        messageReference = message.message_reference
        flags = message.flags
        referencedMessage = message.referenced_message
        interaction = message.interaction
        thread = message.thread
        components = message.components
        stickers = message.sticker_items
        call = message.call

        self.rest = rest
        self.coreMessage = message

        // jumpURL = nil
    }
}

public extension Message {
    /// Sends a reply to the message
    /// 
    /// - Parameter content: The content of the reply message
    func reply(_ content: String) async throws -> DiscordKitBot.Message {
        let coreMessage = try await rest.createChannelMsg(
            message: .init(content: content, message_reference: .init(message_id: id), components: []),
            id: channelID
        )

        return await Message(from: coreMessage, rest: rest)
    }

    /// Deletes the message.
    /// 
    /// You can always delete your own messages, but deleting other people's messages requires the `manage_messages` guild permission.
    func delete() async throws {
        try await rest.deleteMsg(id: channelID, msgID: id)
    }

    /// Edits the message
    ///
    /// You can only edit your own messages.
    /// 
    /// - Parameter content: The content of the edited message
    func edit(content: String?) async throws {
        try await rest.editMessage(channelID, id, DiscordKitCore.NewMessage(content: content))
    }

    /// Add a reaction emoji to the message.
    ///
    /// - Parameter emoji: The emote in the form `:emote_name:emote_id`
    func addReaction(emoji: String) async throws {
        try await rest.createReaction(channelID, id, emoji)
    }

    /// Removes your own reaction from a message
    /// 
    /// - Parameter emoji: The emote in the form `:emote_name:emote_id`
    func removeReaction(emoji: Snowflake) async throws {
        try await rest.deleteOwnReaction(channelID, id, emoji)
    }

    /// Clear all reactions from a message
    /// 
    /// Requires the the `manage_messages` guild permission.
    func clearAllReactions() async throws {
        try await rest.deleteAllReactions(channelID, id)
    }
    /// Clear all reactions from a message of a specific emoji
    /// 
    /// Requires the the `manage_messages` guild permission.
    /// 
    /// - Parameter emoji: The emote in the form `:emote_name:emote_id`
    func clearAllReactions(for emoji: Snowflake) async throws {
        try await rest.deleteAllReactionsforEmoji(channelID, id, emoji)
    }

    /// Starts a thread from the message
    /// 
    /// Requires the `create_public_threads`` guild permission.
    func createThread(name: String, autoArchiveDuration: Int?, rateLimitPerUser: Int?) async throws -> Channel {
        let body = CreateThreadRequest(name: name, auto_archive_duration: autoArchiveDuration, rate_limit_per_user: rateLimitPerUser)
        return try await rest.startThreadfromMessage(channelID, id, body)
    }

    /// Pins the message.
    /// 
    /// Requires the `manage_messages` guild permission to do this in a non-private channel context.
    func pin() async throws {
        try await rest.pinMessage(channelID, id)
    }

    /// Unpins the message.
    /// 
    /// Requires the `manage_messages` guild permission to do this in a non-private channel context.
    func unpin() async throws {
        try await rest.unpinMessage(channelID, id)
    }

    /// Publishes a message in an announcement channel to it's followers.
    /// 
    /// Requires the `SEND_MESSAGES` permission, if the bot sent the message, or the `MANAGE_MESSAGES` permission for all other messages
    func publish() async throws -> Message {
        let coreMessage: DiscordKitCore.Message = try await rest.crosspostMessage(channelID, id)
        return await Message(from: coreMessage, rest: rest)
    }

    static func ==(lhs: Message, rhs: Message) -> Bool {
        return lhs.id == rhs.id
    }

    static func !=(lhs: Message, rhs: Message) -> Bool {
        return lhs.id != rhs.id
    }
}

/// An `enum` representing message types.
/// 
/// Some of these descriptions were taken from [The Discord.py documentation](https://discordpy.readthedocs.io/en/stable/api.html?#discord.MessageType), 
/// which is licensed under the MIT license.
public enum MessageType: Int, Codable {
    /// Default text message
    case defaultMsg = 0

    /// Sent when a member joins a group DM
    case recipientAdd = 1

    /// Sent when a member is removed from a group DM
    case recipientRemove = 2

    /// Incoming call
    case call = 3

    /// Channel name changes
    case chNameChange = 4

    /// Channel icon changes
    case chIconChange = 5

    /// Pinned message add/remove
    case chPinnedMsg = 6

    /// Sent when a user joins a server
    case guildMemberJoin = 7

    /// Sent when a user boosts a server
    case userPremiumGuildSub = 8

    /// Sent when a user boosts a server and that server reaches boost level 1
    case userPremiumGuildSubTier1 = 9

    /// Sent when a user boosts a server and that server reaches boost level 2
    case userPremiumGuildSubTier2 = 10

    /// Sent when a user boosts a server and that server reaches boost level 3
    case userPremiumGuildSubTier3 = 11

    /// Sent when an announcement channel has been followed
    case chFollowAdd = 12

    /// Sent when a server is no longer eligible for server discovery
    case guildDiscoveryDisqualified = 14

    /// Sent when a server is eligible for server discovery
    case guildDiscoveryRequalified = 15

    /// Sent when a server has not met the Server Discovery requirements for 1 week
    case guildDiscoveryGraceInitial = 16

    /// Sent when a server has not met the Server Discovery requirements for 3 weeks in a row
    case guildDiscoveryGraceFinal = 17

    /// Sent when a thread has been created on an old message
    /// 
    /// What qualifies as an "old message" is not defined, and is decided by discord.
    /// It should not be something you rely upon.
    case threadCreated = 18

    /// A message replying to another message
    case reply = 19

    /// The system message denoting that a slash command was executed.
    case chatInputCmd = 20

    /// The system message denoting the message in the thread that is the one that started the thread’s conversation topic.
    case threadStarterMsg = 21

    /// The system message reminding you to invite people to the guild.
    case guildInviteReminder = 22

    /// The system message denoting that a context menu command was executed.
    case contextMenuCmd = 23

    /// A message detailing an action taken by automod
    case autoModAct = 24

    /// The system message sent when a user purchases or renews a role subscription.
    case roleSubscriptionPurchase = 25

    /// The system message sent when a user is given an advertisement to purchase a premium tier for an application during an interaction.
    case interactionPremiumUpsell = 26

    /// The system message sent when the stage starts.
    case stageStart = 27

    /// The system message sent when the stage ends.
    case stageEnd = 28

    /// The system message sent when the stage speaker changes.
    case stageSpeaker = 29

    /// The system message sent when the stage topic changes.
    case stageTopic = 31

    /// The system message sent when an application’s premium subscription is purchased for the guild.
    case guildApplicationPremiumSubscription = 32

    init?(_ coreMessageType: DiscordKitCore.MessageType) {
        self.init(rawValue: coreMessageType.rawValue)
    }
}
