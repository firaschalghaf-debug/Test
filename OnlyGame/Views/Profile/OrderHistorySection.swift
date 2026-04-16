import SwiftUI

struct OrderHistorySection: View {
    let userId: UUID

    @State private var orders: [Order] = []
    @State private var isLoading = false

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Purchase History")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                if !orders.isEmpty {
                    Text("\(orders.count)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.50))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())
                }
                Spacer()
            }

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else if orders.isEmpty {
                emptyState
            } else {
                VStack(spacing: 12) {
                    ForEach(orders) { order in
                        OrderCard(order: order, dateFormatter: dateFormatter)
                    }
                }
            }
        }
        .task { await load() }
    }

    private var emptyState: some View {
        HStack {
            Spacer()
            VStack(spacing: 10) {
                Image(systemName: "bag")
                    .font(.system(size: 32))
                    .foregroundStyle(.white.opacity(0.22))
                Text("No purchases yet")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.40))
            }
            .padding(.vertical, 30)
            Spacer()
        }
    }

    private func load() async {
        isLoading = true
        orders = (try? await SupabaseManager.shared.fetchOrders(userId: userId)) ?? []
        isLoading = false
    }
}

// MARK: - Order card

private struct OrderCard: View {
    let order: Order
    let dateFormatter: DateFormatter

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Order header row
            Button {
                withAnimation(.easeInOut(duration: 0.20)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 14) {
                    // Icon
                    Image(systemName: "bag.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.cyan)
                        .frame(width: 36, height: 36)
                        .background(Color.cyan.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Order #\(order.id)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        Text(dateFormatter.string(from: order.orderDate))
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.45))
                    }

                    Spacer()

                    statusBadge(order.status)

                    Text(String(format: "$%.2f", order.totalAmount))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.40))
                }
                .padding(16)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Expanded items
            if isExpanded {
                Divider()
                    .background(Color.white.opacity(0.08))

                VStack(spacing: 0) {
                    ForEach(order.items) { item in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.gameTitle)
                                    .font(.subheadline)
                                    .foregroundStyle(.white)
                                Text(item.gameGenre)
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.45))
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                if item.discountApplied > 0 {
                                    Text(String(format: "$%.2f", item.unitPrice))
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.35))
                                        .strikethrough(true, color: .white.opacity(0.35))
                                }
                                Text(String(format: "$%.2f", item.subtotal))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(item.discountApplied > 0 ? .green : .white)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 11)

                        if item.id != order.items.last?.id {
                            Divider()
                                .background(Color.white.opacity(0.06))
                                .padding(.leading, 16)
                        }
                    }
                }
                .background(Color.white.opacity(0.03))
            }
        }
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    private func statusBadge(_ status: String) -> some View {
        let color: Color = switch status {
            case "Completed": .green
            case "Refunded":  .orange
            case "Cancelled": .red
            default:          .white.opacity(0.50)
        }
        return Text(status)
            .font(.caption.weight(.bold))
            .foregroundStyle(color)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }
}
