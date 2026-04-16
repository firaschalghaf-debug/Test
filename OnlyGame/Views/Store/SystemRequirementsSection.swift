import SwiftUI

struct SystemRequirementsSection: View {
    let gameId: UUID

    @State private var requirements: SystemRequirements? = nil
    @State private var isLoading = false

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            } else if let req = requirements, req.hasAnyData {
                content(req)
            }
            // Nothing rendered if no data — section is silently omitted
        }
        .task { await load() }
    }

    // MARK: - Table

    private func content(_ req: SystemRequirements) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("System Requirements")
                .font(.title2.bold())
                .foregroundStyle(.white)

            VStack(spacing: 0) {
                // Header row
                tableRow(
                    icon: nil, label: "",
                    min: "Minimum", rec: "Recommended",
                    isHeader: true
                )

                ForEach(rows(for: req), id: \.label) { row in
                    tableRow(
                        icon: row.icon, label: row.label,
                        min: row.min, rec: row.rec,
                        isHeader: false
                    )
                }
            }
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 1))
        }
    }

    @ViewBuilder
    private func tableRow(icon: String?, label: String, min: String?, rec: String?, isHeader: Bool) -> some View {
        HStack(spacing: 0) {
            // Label column
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.45))
                        .frame(width: 14)
                }
                Text(label)
                    .font(isHeader ? .caption.weight(.bold) : .caption.weight(.semibold))
                    .foregroundStyle(isHeader ? .clear : .white.opacity(0.55))
            }
            .frame(width: 110, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 13)

            Divider()
                .frame(width: 1)
                .background(Color.white.opacity(0.08))

            // Minimum column
            Text(min ?? "—")
                .font(isHeader ? .caption.weight(.bold) : .caption)
                .foregroundStyle(
                    isHeader ? .white.opacity(0.50) :
                    (min != nil ? .white.opacity(0.85) : .white.opacity(0.22))
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 13)

            Divider()
                .frame(width: 1)
                .background(Color.white.opacity(0.08))

            // Recommended column
            Text(rec ?? "—")
                .font(isHeader ? .caption.weight(.bold) : .caption)
                .foregroundStyle(
                    isHeader ? .white.opacity(0.50) :
                    (rec != nil ? .white.opacity(0.85) : .white.opacity(0.22))
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
        }
        .background(isHeader ? Color.white.opacity(0.05) : Color.clear)
        .overlay(alignment: .top) {
            if !isHeader {
                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 1)
            }
        }
    }

    // MARK: - Row data

    private struct RowData: Identifiable {
        var id: String { label }
        let icon: String
        let label: String
        let min: String?
        let rec: String?
    }

    private func rows(for req: SystemRequirements) -> [RowData] {
        var result: [RowData] = []
        if req.minOS != nil || req.recOS != nil {
            result.append(RowData(icon: "desktopcomputer", label: "OS",
                                  min: req.minOS, rec: req.recOS))
        }
        if req.minCPU != nil || req.recCPU != nil {
            result.append(RowData(icon: "cpu", label: "CPU",
                                  min: req.minCPU, rec: req.recCPU))
        }
        if req.minRAMGB != nil || req.recRAMGB != nil {
            result.append(RowData(icon: "memorychip", label: "RAM",
                                  min: req.minRAMGB.map { "\($0) GB" },
                                  rec: req.recRAMGB.map { "\($0) GB" }))
        }
        if req.minGPU != nil || req.recGPU != nil {
            result.append(RowData(icon: "display", label: "GPU",
                                  min: req.minGPU, rec: req.recGPU))
        }
        if req.minStorageGB != nil || req.recStorageGB != nil {
            result.append(RowData(icon: "internaldrive", label: "Storage",
                                  min: req.minStorageGB.map { "\($0) GB" },
                                  rec: req.recStorageGB.map { "\($0) GB" }))
        }
        return result
    }

    // MARK: - Load

    private func load() async {
        isLoading = true
        requirements = try? await SupabaseManager.shared.fetchSystemRequirements(gameId: gameId)
        isLoading = false
    }
}
