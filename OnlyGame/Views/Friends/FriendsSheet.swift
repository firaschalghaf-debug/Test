import SwiftUI

struct FriendsSheet: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var friends: [Friend] = []
    @State private var isLoading = false
    @State private var searchUsername = ""
    @State private var searchResult: (id: UUID, username: String)? = nil
    @State private var isSearching = false
    @State private var searchError = ""
    @State private var actionError = ""

    private var accepted: [Friend]  { friends.filter { $0.status == "Accepted" } }
    private var incoming: [Friend]  { friends.filter { $0.status == "Pending" && !$0.isSentByMe } }
    private var outgoing: [Friend]  { friends.filter { $0.status == "Pending" &&  $0.isSentByMe } }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text("Friends")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)
                if !accepted.isEmpty {
                    Text("\(accepted.count) friend\(accepted.count == 1 ? "" : "s")")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.50))
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 20)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    addFriendSection
                    if !actionError.isEmpty {
                        Text(actionError)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(.horizontal, 24)
                    }
                    if isLoading {
                        ProgressView().frame(maxWidth: .infinity).padding(.vertical, 20)
                    } else {
                        if !incoming.isEmpty { requestsSection }
                        if !outgoing.isEmpty { outgoingSection }
                        friendsListSection
                    }
                }
                .padding(.bottom, 24)
            }
        }
        .task { await load() }
    }

    // MARK: - Add Friend

    private var addFriendSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Add Friend")
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 24)

            HStack(spacing: 10) {
                TextField("Search by username", text: $searchUsername)
                    .textFieldStyle(.plain)
                    .foregroundStyle(.white)
                    .onSubmit { Task { await search() } }

                Button {
                    Task { await search() }
                } label: {
                    Group {
                        if isSearching { ProgressView().controlSize(.small) }
                        else { Text("Find") }
                    }
                    .frame(width: 48)
                }
                .buttonStyle(.borderedProminent)
                .tint(.cyan)
                .disabled(searchUsername.trimmingCharacters(in: .whitespaces).isEmpty || isSearching)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 24)

            if !searchError.isEmpty {
                Text(searchError)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 24)
            }

            if let result = searchResult {
                HStack {
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 28))
                        .foregroundStyle(.white.opacity(0.60))
                    Text(result.username)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    Button("Send Request") {
                        Task { await sendRequest(to: result.id) }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.cyan)
                    .controlSize(.small)
                }
                .padding(14)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 24)
            }
        }
    }

    // MARK: - Incoming requests

    private var requestsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Pending Requests", count: incoming.count, color: .orange)

            VStack(spacing: 0) {
                ForEach(incoming) { friend in
                    HStack(spacing: 14) {
                        personIcon
                        Text(friend.username)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        Spacer()
                        Button {
                            Task { await respond(friend: friend, accept: true) }
                        } label: {
                            Image(systemName: "checkmark")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.green)
                                .frame(width: 30, height: 30)
                                .background(Color.green.opacity(0.15))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)

                        Button {
                            Task { await respond(friend: friend, accept: false) }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.red)
                                .frame(width: 30, height: 30)
                                .background(Color.red.opacity(0.12))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    if friend.id != incoming.last?.id {
                        Divider().background(Color.white.opacity(0.06)).padding(.leading, 58)
                    }
                }
            }
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.orange.opacity(0.20), lineWidth: 1))
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Outgoing requests

    private var outgoingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Sent Requests", count: outgoing.count, color: .white.opacity(0.40))

            VStack(spacing: 0) {
                ForEach(outgoing) { friend in
                    HStack(spacing: 14) {
                        personIcon
                        Text(friend.username)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.80))
                        Spacer()
                        Text("Pending")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.40))
                        Button {
                            Task { await cancel(friend: friend) }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white.opacity(0.45))
                                .frame(width: 28, height: 28)
                                .background(Color.white.opacity(0.08))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    if friend.id != outgoing.last?.id {
                        Divider().background(Color.white.opacity(0.06)).padding(.leading, 58)
                    }
                }
            }
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 1))
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Friends list

    private var friendsListSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Friends", count: accepted.count, color: .cyan)

            if accepted.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 10) {
                        Image(systemName: "person.2")
                            .font(.system(size: 30))
                            .foregroundStyle(.white.opacity(0.22))
                        Text("No friends yet — search above to add someone")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.38))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, 30)
                    Spacer()
                }
            } else {
                VStack(spacing: 0) {
                    ForEach(accepted) { friend in
                        HStack(spacing: 14) {
                            personIcon
                            Text(friend.username)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                            Spacer()
                            Button {
                                Task { await remove(friend: friend) }
                            } label: {
                                Image(systemName: "person.badge.minus")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.white.opacity(0.38))
                                    .frame(width: 30, height: 30)
                                    .background(Color.white.opacity(0.07))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)

                        if friend.id != accepted.last?.id {
                            Divider().background(Color.white.opacity(0.06)).padding(.leading, 58)
                        }
                    }
                }
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 1))
                .padding(.horizontal, 24)
            }
        }
    }

    // MARK: - Helpers

    private var personIcon: some View {
        Image(systemName: "person.crop.circle.fill")
            .font(.system(size: 28))
            .foregroundStyle(.white.opacity(0.45))
    }

    private func sectionHeader(_ title: String, count: Int, color: Color) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)
            if count > 0 {
                Text("\(count)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(color.opacity(0.12))
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Actions

    private func load() async {
        guard let uid = authVM.userId else { return }
        isLoading = true
        friends = (try? await SupabaseManager.shared.fetchFriends(userId: uid)) ?? []
        isLoading = false
    }

    private func search() async {
        let query = searchUsername.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return }
        isSearching = true
        searchError = ""
        searchResult = nil
        if let result = try? await SupabaseManager.shared.searchProfile(username: query) {
            if result.id == authVM.userId {
                searchError = "That's you!"
            } else if friends.contains(where: { $0.userId == result.id }) {
                searchError = "Already friends or request pending."
            } else {
                searchResult = result
            }
        } else {
            searchError = "No user found with that username."
        }
        isSearching = false
    }

    private func sendRequest(to targetId: UUID) async {
        guard let uid = authVM.userId else { return }
        do {
            try await SupabaseManager.shared.sendFriendRequest(fromUserId: uid, toUserId: targetId)
            searchResult = nil
            searchUsername = ""
            await load()
        } catch {
            actionError = "Could not send request."
        }
    }

    private func respond(friend: Friend, accept: Bool) async {
        do {
            try await SupabaseManager.shared.respondToFriendRequest(friendshipId: friend.id, accept: accept)
            await load()
            await authVM.refreshPendingFriends()
        } catch {
            actionError = "Could not respond to request."
        }
    }

    private func cancel(friend: Friend) async {
        do {
            try await SupabaseManager.shared.removeFriend(friendshipId: friend.id)
            await load()
        } catch {
            actionError = "Could not cancel request."
        }
    }

    private func remove(friend: Friend) async {
        do {
            try await SupabaseManager.shared.removeFriend(friendshipId: friend.id)
            await load()
        } catch {
            actionError = "Could not remove friend."
        }
    }
}
