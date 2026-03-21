import SwiftUI

struct ChatView: View {
    @Bindable var viewModel: ChatViewModel

    var body: some View {
        let activeApproval = viewModel.conversationState.pendingApproval
        let inputLocked = viewModel.conversationState.isLoading || activeApproval != nil

        VStack(spacing: 0) {
            messageList
            approvalBanner
            progressBanner
            InputBar(
                text: $viewModel.messageText,
                isLoading: inputLocked,
                isRecording: viewModel.isRecording,
                onSend: viewModel.sendMessage,
                onVoice: viewModel.toggleRecording,
                onCamera: { viewModel.showCamera = true }
            )
        }
        .navigationTitle("Vesper")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: viewModel.startNewSession) {
                    Image(systemName: "plus.message")
                }
            }
        }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.conversationState.messages) { message in
                        MessageBubble(
                            message: message,
                            approval: viewModel.conversationState.pendingApproval,
                            onApprove: { id in viewModel.approveCommand(id) },
                            onDeny: { id in viewModel.denyCommand(id) }
                        )
                        .id(message.id)
                    }
                }
                .padding(.vertical, 12)
            }
            .onChange(of: viewModel.conversationState.messages.count) { _, _ in
                if let lastMessage = viewModel.conversationState.messages.last {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var approvalBanner: some View {
        if let error = viewModel.conversationState.error {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Retry") {
                    viewModel.retryLastMessage()
                }
                .font(.caption.bold())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.orange.opacity(0.1))
        } else if let approval = viewModel.conversationState.pendingApproval {
            HStack(spacing: 8) {
                Image(systemName: "lock.shield")
                    .foregroundStyle(.orange)
                Text("Approval required: \(approval.riskAssessment.reason)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.orange.opacity(0.08))
        }
    }

    @ViewBuilder
    private var progressBanner: some View {
        if viewModel.conversationState.isLoading, let progress = viewModel.conversationState.progress {
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text(progress.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(.bar)
        }
    }
}
