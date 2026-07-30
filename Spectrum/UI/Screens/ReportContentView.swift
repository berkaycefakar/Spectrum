import SwiftUI

/// The "Report" sheet. Required by App Store Review Guideline 1.2: an app with user-generated
/// content has to give people a way to flag what they see, and a stated response commitment.
struct ReportContentView: View {
    let contentType: ReportedContentType
    let contentRef: String?
    let reportedUserId: UUID?
    let reportedUsername: String?
    /// The text being reported, snapshotted into the report so it survives the author editing
    /// or deleting the row afterwards.
    let reportedText: String?
    /// Offered after a successful report — the two actions Apple expects to sit together.
    var onBlockRequested: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    @State private var reason: ReportReason?
    @State private var details = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var didSubmit = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if didSubmit {
                    confirmation
                } else {
                    form
                }
            }
            .navigationTitle(didSubmit ? "" : "Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !didSubmit {
                        Button("Cancel") { dismiss() }
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            }
            .preferredColorScheme(.dark)
        }
    }

    // MARK: - Form

    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(headline)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.horizontal)

                VStack(spacing: 8) {
                    ForEach(ReportReason.allCases) { option in
                        reasonRow(option)
                    }
                }
                .padding(.horizontal)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Anything else we should know? (optional)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                    TextField("Add details", text: $details, axis: .vertical)
                        .lineLimit(3...6)
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }

                Button {
                    Task { await submit() }
                } label: {
                    // Inside the label so the whole pill is tappable, not just the words.
                    HStack(spacing: 8) {
                        if isSubmitting { ProgressView().tint(.white) }
                        Text(isSubmitting ? "Sending…" : "Submit report")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(reason == nil ? Color.white.opacity(0.12) : Color(hex: "#FF00FF"))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .contentShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(reason == nil || isSubmitting)
                .padding(.horizontal)

                Text("Reports are reviewed within 24 hours. Content that breaks the rules is removed and repeat offenders lose access.")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.horizontal)
                    .padding(.bottom, 24)
            }
            .padding(.top, 12)
        }
    }

    private func reasonRow(_ option: ReportReason) -> some View {
        Button {
            reason = option
        } label: {
            HStack(spacing: 12) {
                Image(systemName: option.icon)
                    .font(.system(size: 15))
                    .foregroundStyle(reason == option ? Color(hex: "#FF00FF") : .white.opacity(0.5))
                    .frame(width: 24)
                Text(option.title)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                Spacer()
                if reason == option {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color(hex: "#FF00FF"))
                }
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 14)
            .background(.white.opacity(reason == option ? 0.10 : 0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private var headline: String {
        switch contentType {
        case .profile:
            return "Tell us what's wrong with \(reportedUsername.map { "@\($0)" } ?? "this profile")."
        default:
            return "Tell us what's wrong with this review."
        }
    }

    // MARK: - Confirmation

    private var confirmation: some View {
        VStack(spacing: 18) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 54))
                .foregroundStyle(Color(hex: "#FF00FF"))

            Text("Thanks — we're on it")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(.white)

            Text("We review reports within 24 hours. You won't be told who reported what.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            if let onBlockRequested, reportedUserId != nil {
                Button {
                    onBlockRequested()
                    dismiss()
                } label: {
                    Text("Also block \(reportedUsername.map { "@\($0)" } ?? "this user")")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.white.opacity(0.12))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .contentShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 24)
            }

            Button("Done") { dismiss() }
                .foregroundStyle(.white.opacity(0.7))
                .padding(.top, 4)
        }
        .padding()
    }

    // MARK: - Submit

    private func submit() async {
        guard let reason else { return }
        isSubmitting = true
        errorMessage = nil
        do {
            try await SupabaseManager.shared.submitReport(
                contentType: contentType,
                contentRef: contentRef,
                reportedUserId: reportedUserId,
                reason: reason,
                details: details,
                reportedText: reportedText
            )
            isSubmitting = false
            didSubmit = true
        } catch {
            isSubmitting = false
            errorMessage = error.localizedDescription
        }
    }
}
