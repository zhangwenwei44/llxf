//
//  hudapp-bridging-header.h
//  TrollSpeed
//
//  Created by Lessica on 2024/1/25.
//

#ifndef hudapp_bridging_header_h
#define hudapp_bridging_header_h

#import <Foundation/Foundation.h>

#import "HUDHelper.h"

typedef NSString * HUDUserDefaultsKey;

static HUDUserDefaultsKey const HUDUserDefaultsKeySelectedMode = @"selectedMode";
static HUDUserDefaultsKey const HUDUserDefaultsKeySelectedModeLandscape = @"selectedModeLandscape";
static HUDUserDefaultsKey const HUDUserDefaultsKeyCurrentPositionY = @"currentPositionY";
static HUDUserDefaultsKey const HUDUserDefaultsKeyCurrentLandscapePositionY = @"currentLandscapePositionY";
static HUDUserDefaultsKey const HUDUserDefaultsKeyCurrentPositionX = @"currentPositionX";
static HUDUserDefaultsKey const HUDUserDefaultsKeyCurrentLandscapePositionX = @"currentLandscapePositionX";
static HUDUserDefaultsKey const HUDUserDefaultsKeyPassthroughMode = @"passthroughMode";
static HUDUserDefaultsKey const HUDUserDefaultsKeySingleLineMode = @"singleLineMode";
static HUDUserDefaultsKey const HUDUserDefaultsKeyUsesBitrate = @"usesBitrate";
static HUDUserDefaultsKey const HUDUserDefaultsKeyUsesArrowPrefixes = @"usesArrowPrefixes";
static HUDUserDefaultsKey const HUDUserDefaultsKeyUsesLargeFont = @"usesLargeFont";
static HUDUserDefaultsKey const HUDUserDefaultsKeyUsesRotation = @"usesRotation";
static HUDUserDefaultsKey const HUDUserDefaultsKeyUsesInvertedColor = @"usesInvertedColor";
static HUDUserDefaultsKey const HUDUserDefaultsKeyKeepInPlace = @"keepInPlace";
static HUDUserDefaultsKey const HUDUserDefaultsKeyHideAtSnapshot = @"hideAtSnapshot";

/* Data quota (stored in a standalone plist, not in the HUD user defaults) */
static HUDUserDefaultsKey const HUDUserDefaultsKeyUsesDataQuota = @"usesDataQuota";
static HUDUserDefaultsKey const HUDUserDefaultsKeyDataQuotaTotalBytes = @"dataQuotaTotalBytes";
static HUDUserDefaultsKey const HUDUserDefaultsKeyDataQuotaUsedBytes = @"dataQuotaUsedBytes";
static HUDUserDefaultsKey const HUDUserDefaultsKeyDataQuotaLastRawTotal = @"dataQuotaLastRawTotal";
static HUDUserDefaultsKey const HUDUserDefaultsKeyResetDataQuotaUsage = @"resetDataQuotaUsage";

/* Cellular (4G/5G) quota, counted on pdp_ip* interfaces only */
static HUDUserDefaultsKey const HUDUserDefaultsKeyCellularQuotaTotalBytes = @"cellularQuotaTotalBytes";
static HUDUserDefaultsKey const HUDUserDefaultsKeyCellularQuotaUsedBytes = @"cellularQuotaUsedBytes";
static HUDUserDefaultsKey const HUDUserDefaultsKeyCellularQuotaLastRaw = @"cellularQuotaLastRaw";

/* Wi-Fi quota, one profile per SSID: { SSID: { total, used, lastRaw } } */
static HUDUserDefaultsKey const HUDUserDefaultsKeyWifiQuotaProfiles = @"wifiQuotaProfiles";

/* Reset everything at once */
static HUDUserDefaultsKey const HUDUserDefaultsKeyResetAllDataQuotaUsage = @"resetAllDataQuotaUsage";

/* Currently connected network, published by the HUD for the app to read */
static HUDUserDefaultsKey const HUDUserDefaultsKeyCurrentNetworkType = @"currentNetworkType";
static HUDUserDefaultsKey const HUDUserDefaultsKeyCurrentWifiSSID = @"currentWifiSSID";

static HUDUserDefaultsKey const HUDUserDefaultsKeyUsesCustomFontSize = @"usesCustomFontSize";
static HUDUserDefaultsKey const HUDUserDefaultsKeyRealCustomFontSize = @"realCustomFontSize";
static HUDUserDefaultsKey const HUDUserDefaultsKeyUsesCustomOffset = @"usesCustomOffset";
static HUDUserDefaultsKey const HUDUserDefaultsKeyRealCustomOffsetX = @"realCustomOffsetX";
static HUDUserDefaultsKey const HUDUserDefaultsKeyRealCustomOffsetY = @"realCustomOffsetY";

#endif /* hudapp_bridging_header_h */
