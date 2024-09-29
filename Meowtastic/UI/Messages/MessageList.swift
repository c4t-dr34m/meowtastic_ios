import CoreData
import FirebaseAnalytics
import MeshtasticProtobufs
import OSLog
import SwiftUI

struct MessageList: View {
	private let channel: ChannelEntity?
	private let user: UserEntity?
	private let myInfo: MyInfoEntity?
	private let textFieldPlaceholderID = "text_field_placeholder"
	private let debounce = Debounce<() async -> Void>(duration: .milliseconds(250)) { action in
		await action()
	}

	@Environment(\.managedObjectContext)
	private var context
	@AppStorage("preferredPeripheralNum")
	private var preferredPeripheralNum = -1
	@EnvironmentObject
	private var connectedDevice: CurrentDevice
	@StateObject
	private var appState = AppState.shared
	@FocusState
	private var messageFieldFocused: Bool
	@State
	private var nodeDetail: NodeInfoEntity?
	@State
	private var replyMessageId: Int64 = 0

	@FetchRequest(
		sortDescriptors: [
			NSSortDescriptor(key: "favorite", ascending: false),
			NSSortDescriptor(key: "lastHeard", ascending: false),
			NSSortDescriptor(key: "user.longName", ascending: true)
		]
	)
	private var nodes: FetchedResults<NodeInfoEntity>

	@FetchRequest(
		sortDescriptors: [
			NSSortDescriptor(key: "messageTimestamp", ascending: true)
		]
	)
	private var messages: FetchedResults<MessageEntity>

	private var filteredMessages: [MessageEntity] {
		if let channel {
			return messages.filter { message in
				message.channel == channel.index && message.toUser == nil
			} as [MessageEntity]
		}
		else if let user {
			return messages.filter { message in
				message.toUser != nil && message.fromUser != nil
				&& (message.toUser?.num == user.num || message.fromUser?.num == user.num)
				&& !message.admin
				&& message.portNum != 10
			} as [MessageEntity]
		}

		return [MessageEntity]()
	}
	private var firstUnreadMessage: MessageEntity? {
		filteredMessages.first(where: { message in
			!message.read
		})
	}
	private var destination: MessageDestination? {
		if let channel {
			return .channel(channel)
		}
		else if let user {
			return .user(user)
		}

		return nil
	}
	private var screenTitle: String {
		if let channel {
			if let name = channel.name, !name.isEmpty {
				return name.camelCaseToWords()
			}
			else {
				if channel.role == 1 {
					return "Primary Channel"
				}
				else {
					return "Channel #\(channel.index)"
				}
			}
		}
		else if let user {
			if let name = user.longName {
				return name
			}
			else {
				return "DM"
			}
		}

		return ""
	}

	var body: some View {
		ZStack(alignment: .bottom) {
			ScrollViewReader { scrollView in
				if !filteredMessages.isEmpty {
					messageList
						.scrollDismissesKeyboard(.interactively)
						.scrollIndicators(.hidden)
						.onChange(of: filteredMessages, initial: true) {
							if let firstUnreadMessage {
								scrollView.scrollTo(firstUnreadMessage.messageId)
							}
							else {
								scrollView.scrollTo(textFieldPlaceholderID)
							}
						}
				}
				else {
					ContentUnavailableView(
						"No Messages",
						systemImage: channel != nil ? "bubble.left.and.bubble.right" : "bubble"
					)
				}
			}
			.onAppear {
				Analytics.logEvent(
					AnalyticEvents.messageList.id,
					parameters: [
						"kind": channel != nil ? "channel" : "user",
						"messages_in_list": filteredMessages.count
					]
				)
			}

			if let destination {
				TextMessageField(
					destination: destination,
					onSubmit: {
						if let channel {
							context.refresh(channel, mergeChanges: true)
						}
						else if let user {
							context.refresh(user, mergeChanges: true)
						}
					},
					replyMessageId: $replyMessageId,
					isFocused: $messageFieldFocused
				)
				.frame(alignment: .bottom)
				.padding(.horizontal, 16)
				.padding(.bottom, 8)
			}
			else {
				EmptyView()
			}
		}
		.navigationBarTitleDisplayMode(.inline)
		.toolbar {
			ToolbarItem(placement: .principal) {
				Text(screenTitle)
					.font(.headline)
			}

			ToolbarItem(placement: .navigationBarTrailing) {
				if let channel {
					ConnectionInfo(
						mqttUplinkEnabled: channel.uplinkEnabled,
						mqttDownlinkEnabled: channel.downlinkEnabled
					)
				}
				else {
					ConnectionInfo()
				}
			}
		}
		.sheet(item: $nodeDetail) { node in
			NodeDetail(
				node: node,
				isInSheet: true
			)
				.presentationDragIndicator(.visible)
				.presentationDetents([.medium])
		}
	}

	@ViewBuilder
	private var messageList: some View {
		List {
			ForEach(filteredMessages, id: \.messageId) { message in
				messageView(for: message)
					.listRowSeparator(.hidden)
					.listRowBackground(Color.clear)
					.scrollContentBackground(.hidden)
			}

			Rectangle()
				.id(textFieldPlaceholderID)
				.foregroundColor(.clear)
				.frame(height: 48)
				.listRowSeparator(.hidden)
				.listRowBackground(Color.clear)
				.scrollContentBackground(.hidden)
		}
		.listStyle(.plain)
	}

	init(
		channel: ChannelEntity,
		myInfo: MyInfoEntity?
	) {
		self.channel = channel
		self.user = nil
		self.myInfo = myInfo
	}

	init(
		user: UserEntity,
		myInfo: MyInfoEntity?
	) {
		self.channel = nil
		self.user = user
		self.myInfo = myInfo
	}

	@ViewBuilder
	private func messageView(for message: MessageEntity) -> some View {
		let isCurrentUser = isCurrentUser(message: message, preferredNum: preferredPeripheralNum)

		HStack(alignment: isCurrentUser ? .bottom : .top, spacing: 8) {
			leadingAvatar(for: message)
			content(for: message)
			trailingAvatar(for: message)
		}
		.frame(maxWidth: .infinity)
		.onAppear {
			var didRead = 0
			for displayedMessage in filteredMessages.filter({ msg in
				msg.messageTimestamp <= message.messageTimestamp
			}) where !displayedMessage.read {
				displayedMessage.read.toggle()
				didRead += 1
			}

			guard didRead > 0 else {
				return
			}

			Logger.app.info("Marking \(didRead) message(s) as read")

			debounce.emit {
				await self.saveData()
			}

			if let myInfo {
				appState.unreadChannelMessages = myInfo.unreadMessages
				context.refresh(myInfo, mergeChanges: true)
			}
		}
	}

	@ViewBuilder
	private func leadingAvatar(for message: MessageEntity) -> some View {
		let isCurrentUser = isCurrentUser(message: message, preferredNum: preferredPeripheralNum)

		if isCurrentUser {
			Spacer()
		}
		else {
			VStack(alignment: .center) {
				if let node = message.fromUser?.userNode {
					AvatarNode(
						node,
						ignoreOffline: true,
						showLastHeard: node.isOnline,
						size: 64,
						corners: isCurrentUser ? (true, true, false, true) : nil
					)
				}
				else {
					AvatarAbstract(
						color: .gray,
						size: 64,
						corners: isCurrentUser ? (true, true, false, true) : nil
					)
				}
			}
			.frame(width: 64)
			.onTapGesture {
				if let sourceNode = message.fromUser?.userNode {
					nodeDetail = sourceNode
				}
			}
		}
	}

	@ViewBuilder
	private func trailingAvatar(for message: MessageEntity) -> some View {
		let isCurrentUser = isCurrentUser(message: message, preferredNum: preferredPeripheralNum)

		if isCurrentUser {
			if let node = message.fromUser?.userNode {
				AvatarNode(
					node,
					ignoreOffline: true,
					size: 64
				)
			}
			else {
				AvatarAbstract(
					size: 64
				)
			}
		}
		else {
			Spacer()
		}
	}

	@ViewBuilder
	private func content(for message: MessageEntity) -> some View {
		let isCurrentUser = isCurrentUser(message: message, preferredNum: preferredPeripheralNum)

		VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 2) {
			if !isCurrentUser {
				HStack(spacing: 4) {
					if message.fromUser != nil {
						Image(systemName: "person")
							.font(.caption)
							.foregroundColor(.gray)

						Text(getSenderName(message: message))
							.font(.caption)
							.lineLimit(1)
							.foregroundColor(.gray)

						if let node = message.fromUser?.userNode, let nodeNum = connectedDevice.device?.num {
							NodeIconsCompactView(
								connectedNode: nodeNum,
								node: node
							)
						}
					}
					else {
						Image(systemName: "person.fill.questionmark")
							.font(.caption)
							.foregroundColor(.gray)
					}
				}
			}
			else {
				EmptyView()
			}

			if let destination {
				HStack(spacing: 0) {
					MessageView(
						message: message,
						originalMessage: getOriginalMessage(for: message),
						tapBackDestination: destination,
						isCurrentUser: isCurrentUser
					) {
						replyMessageId = message.messageId
						messageFieldFocused = true
					}

					if isCurrentUser && message.canRetry {
						RetryButton(message: message, destination: destination)
					}
				}
			}
		}
	}

	private func getOriginalMessage(for message: MessageEntity) -> MessageEntity? {
		if
			message.replyID > 0,
			let messageReply = filteredMessages.first(where: { msg in
				msg.messageId == message.replyID
			}),
			messageReply.messagePayload != nil
		{
			return messageReply
		}

		return nil
	}

	private func isCurrentUser(message: MessageEntity, preferredNum: Int) -> Bool {
		Int64(preferredNum) == message.fromUser?.num
	}

	private func getUserColor(for node: NodeInfoEntity?) -> Color {
		if let node, node.isOnline {
			return Color(
				UIColor(hex: UInt32(node.num))
			)
		}
		else {
			return Color.gray.opacity(0.7)
		}
	}

	private func getSenderName(message: MessageEntity, short: Bool = false) -> String {
		let shortName = message.fromUser?.shortName
		let longName = message.fromUser?.longName

		if short {
			if let shortName {
				return shortName
			}
			else {
				return ""
			}
		}
		else {
			if let longName {
				return longName
			}
			else {
				return "Unknown Name"
			}
		}
	}

	@discardableResult
	func saveData() async -> Bool {
		context.performAndWait {
			guard context.hasChanges else {
				return false
			}

			do {
				try context.save()

				return true
			}
			catch let error {
				context.rollback()

				return false
			}
		}
	}
}
