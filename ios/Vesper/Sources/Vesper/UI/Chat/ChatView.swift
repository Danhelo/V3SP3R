import SwiftUI

struct ChatView: View {
    @Bindable var viewModel: ChatViewModel

    var body: some View {
        VStack(spacing: 0) {
            messageList
            approvalBanner
            progressBanner
            InputBar(
                text: $viewModel.messageText,
                isLoading: viewModel.conversationState.isLoading,
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
                            onApprove: { id in viewModel.approveCommand(id) },
                            onDeny: { id in viewModel.denyCommand(id) }
                        )
                        .id(message.id)
                    }
                }
                .padding(.vertical, 12)
            }
            .scrollDismissesKeyboard(.interactively)
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
        if let approval = viewModel.conversationState.pendingApproval {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: approval.riskAssessment.level == .high
                          ? "exclamationmark.shield.fill"
                          : "shield.lefthalf.filled")
                        .foregroundStyle(approval.riskAssessment.level == .high ? .red : .orange)
                    Text("\(approval.riskAssessment.level.rawValue.uppercased()) Risk")
                        .font(.caption.bold())
                        .foregroundStyle(approval.riskAssessment.level == .high ? .red : .orange)
                    Spacer()
                }

                Text(approval.command.action.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.subheadline.bold())

                Text(approval.riskAssessment.reason)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if !approval.command.justification.isEmpty {
                    Text(approval.command.justification)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .italic()
                }

                if let diff = approval.diff {
                    Text(diff.unifiedDiff)
                        .font(.system(.caption2, design: .monospaced))
                        .padding(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .lineLimit(10)
                }

                HStack(spacing: 12) {
                    Button(role: .destructive) {
                        viewModel.denyCommand(approval.id)
                    } label: {
                        Text("Deny")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        viewModel.approveCommand(approval.id)
                    } label: {
                        Text("Approve")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(approval.riskAssessment.level == .high ? .red : .orange)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                (approval.riskAssessment.level == .high ? Color.red : Color.orange)
                    .opacity(0.08)
            )
        }

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
