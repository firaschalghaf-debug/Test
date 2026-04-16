import Foundation

struct SystemRequirements {
    let minOS: String?
    let minCPU: String?
    let minRAMGB: Int?
    let minGPU: String?
    let minStorageGB: Int?
    let recOS: String?
    let recCPU: String?
    let recRAMGB: Int?
    let recGPU: String?
    let recStorageGB: Int?

    var hasAnyData: Bool {
        minOS != nil || minCPU != nil || minRAMGB != nil ||
        minGPU != nil || minStorageGB != nil ||
        recOS != nil || recCPU != nil || recRAMGB != nil ||
        recGPU != nil || recStorageGB != nil
    }
}
