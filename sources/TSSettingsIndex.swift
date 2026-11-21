//
//  TSSettingsIndex.swift
//  TrollSpeed
//
//  Created by Lessica on 2024/1/25.
//

import Foundation

enum HUDQuotaInfo {

    static let gigabyte: Double = 1073741824.0

    private static let globalPlistPath = "/var/mobile/Library/Preferences/ch.xxtou.hudapp.quota.plist"

    private static var dictionary: [String: Any] {
        if let contents = NSDictionary(contentsOfFile: globalPlistPath) as? [String: Any] {
            return contents
        }
        if let library = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first {
            let fallback = library.appendingPathComponent("ch.xxtou.hudapp.quota.plist").path
            if let contents = NSDictionary(contentsOfFile: fallback) as? [String: Any] {
                return contents
            }
        }
        return [:]
    }

    static var isEnabled: Bool {
        (dictionary[HUDUserDefaultsKeyUsesDataQuota] as? NSNumber)?.boolValue ?? false
    }

    static var cellularTotalBytes: Double {
        (dictionary[HUDUserDefaultsKeyCellularQuotaTotalBytes] as? NSNumber)?.doubleValue ?? legacyTotalBytes
    }

    static var cellularUsedBytes: Double {
        (dictionary[HUDUserDefaultsKeyCellularQuotaUsedBytes] as? NSNumber)?.doubleValue ?? legacyUsedBytes
    }

    private static var legacyTotalBytes: Double {
        (dictionary[HUDUserDefaultsKeyDataQuotaTotalBytes] as? NSNumber)?.doubleValue ?? 0
    }

    private static var legacyUsedBytes: Double {
        (dictionary[HUDUserDefaultsKeyDataQuotaUsedBytes] as? NSNumber)?.doubleValue ?? 0
    }

    static var wifiProfiles: [String: [String: Any]] {
        (dictionary[HUDUserDefaultsKeyWifiQuotaProfiles] as? [String: [String: Any]]) ?? [:]
    }

    static var wifiProfileCount: Int {
        wifiProfiles.count
    }

    static var currentNetworkType: Int {
        (dictionary[HUDUserDefaultsKeyCurrentNetworkType] as? NSNumber)?.intValue ?? 0
    }

    static var currentSSID: String? {
        let ssid = dictionary[HUDUserDefaultsKeyCurrentWifiSSID] as? String
        return (ssid?.isEmpty == false) ? ssid : nil
    }

    static func wifiProfileTotal(_ ssid: String) -> Double {
        (wifiProfiles[ssid]?["total"] as? NSNumber)?.doubleValue ?? 0
    }

    static func wifiProfileUsed(_ ssid: String) -> Double {
        (wifiProfiles[ssid]?["used"] as? NSNumber)?.doubleValue ?? 0
    }

    static func formatted(_ bytes: Double) -> String {
        guard bytes > 0 else { return "0 KB" }
        if bytes >= gigabyte {
            return String(format: "%.2f GB", bytes / gigabyte)
        }
        if bytes >= 1048576.0 {
            return String(format: "%.0f MB", bytes / 1048576.0)
        }
        return String(format: "%.0f KB", bytes / 1024.0)
    }
}

enum TSSettingsIndex: Int, CaseIterable {
    case usesDataQuota = 0
    case cellularQuotaTotalBytes
    case wifiQuotaManage
    case resetDataQuotaUsage
    case freePosition
    case passthroughMode
    case keepInPlace
    case hideAtSnapshot
    case singleLineMode
    case usesInvertedColor
    case usesRotation
    case usesLargeFont
    case usesArrowPrefixes
    case usesBitrate

    var key: String {
        switch self {
        case .passthroughMode:
            return HUDUserDefaultsKeyPassthroughMode
        case .keepInPlace:
            return HUDUserDefaultsKeyKeepInPlace
        case .hideAtSnapshot:
            return HUDUserDefaultsKeyHideAtSnapshot
        case .singleLineMode:
            return HUDUserDefaultsKeySingleLineMode
        case .usesInvertedColor:
            return HUDUserDefaultsKeyUsesInvertedColor
        case .usesRotation:
            return HUDUserDefaultsKeyUsesRotation
        case .usesLargeFont:
            return HUDUserDefaultsKeyUsesLargeFont
        case .usesArrowPrefixes:
            return HUDUserDefaultsKeyUsesArrowPrefixes
        case .usesBitrate:
            return HUDUserDefaultsKeyUsesBitrate
        case .usesDataQuota:
            return HUDUserDefaultsKeyUsesDataQuota
        case .cellularQuotaTotalBytes:
            return HUDUserDefaultsKeyCellularQuotaTotalBytes
        case .wifiQuotaManage:
            return "wifiQuotaManage"
        case .resetDataQuotaUsage:
            return HUDUserDefaultsKeyResetAllDataQuotaUsage
        case .freePosition:
            return "freePosition"
        }
    }

    var title: String {
        switch self {
        case .passthroughMode:
            return NSLocalizedString("Pass-through", comment: "TSSettingsIndex")
        case .keepInPlace:
            return NSLocalizedString("Keep In-place", comment: "TSSettingsIndex")
        case .hideAtSnapshot:
            return NSLocalizedString("Hide @snapshot", comment: "TSSettingsIndex")
        case .singleLineMode:
            return NSLocalizedString("Incoming Only", comment: "TSSettingsIndex")
        case .usesInvertedColor:
            return NSLocalizedString("Appearance", comment: "TSSettingsIndex")
        case .usesRotation:
            return NSLocalizedString("Landscape", comment: "TSSettingsIndex")
        case .usesLargeFont:
            return NSLocalizedString("Size", comment: "TSSettingsIndex")
        case .usesArrowPrefixes:
            return NSLocalizedString("Prefixes", comment: "TSSettingsIndex")
        case .usesBitrate:
            return NSLocalizedString("Unit", comment: "TSSettingsIndex")
        case .usesDataQuota:
            return "流量统计"
        case .cellularQuotaTotalBytes:
            return "4G 可用流量"
        case .wifiQuotaManage:
            return "WiFi 可用流量"
        case .resetDataQuotaUsage:
            return "清零全部用量"
        case .freePosition:
            return "自由位置"
        }
    }

    func subtitle(highlighted: Bool, restartRequired: Bool) -> String {
        switch self {
        case .passthroughMode:
            if restartRequired {
                return NSLocalizedString("Re-open to apply", comment: "TSSettingsIndex")
            } else {
                return highlighted ? NSLocalizedString("ON", comment: "TSSettingsIndex") : NSLocalizedString("OFF", comment: "TSSettingsIndex")
            }
        case .keepInPlace: fallthrough
        case .hideAtSnapshot: fallthrough
        case .singleLineMode:
            return highlighted ? NSLocalizedString("ON", comment: "TSSettingsIndex") : NSLocalizedString("OFF", comment: "TSSettingsIndex")
        case .usesInvertedColor:
            return highlighted ? NSLocalizedString("Inverted", comment: "TSSettingsIndex") : NSLocalizedString("Classic", comment: "TSSettingsIndex")
        case .usesRotation:
            return highlighted ? NSLocalizedString("Follow", comment: "TSSettingsIndex") : NSLocalizedString("Hide", comment: "TSSettingsIndex")
        case .usesLargeFont:
            return highlighted ? NSLocalizedString("Large", comment: "TSSettingsIndex") : NSLocalizedString("Standard", comment: "TSSettingsIndex")
        case .usesArrowPrefixes:
            return highlighted ? NSLocalizedString("↑↓", comment: "TSSettingsIndex") : NSLocalizedString("▲▼", comment: "TSSettingsIndex")
        case .usesBitrate:
            return highlighted ? NSLocalizedString("b/s", comment: "TSSettingsIndex") : NSLocalizedString("B/s", comment: "TSSettingsIndex")
        case .usesDataQuota:
            return highlighted ? "开" : "关"
        case .cellularQuotaTotalBytes:
            let total = HUDQuotaInfo.cellularTotalBytes
            if total > 0 {
                let remaining = max(total - HUDQuotaInfo.cellularUsedBytes, 0)
                return "剩余 \(HUDQuotaInfo.formatted(remaining))"
            }
            return "未设置"
        case .wifiQuotaManage:
            let count = HUDQuotaInfo.wifiProfileCount
            return count > 0 ? "\(count) 个 WiFi 已设置" : "未设置"
        case .resetDataQuotaUsage:
            return HUDQuotaInfo.formatted(HUDQuotaInfo.cellularUsedBytes)
        case .freePosition:
            return highlighted ? "已开启" : "关闭"
        }
    }
}
