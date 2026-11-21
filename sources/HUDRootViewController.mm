//
//  HUDRootViewController.mm
//  TrollSpeed
//
//  Created by Lessica on 2024/1/24.
//

#import <notify.h>
#import <net/if.h>
#import <ifaddrs.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <dlfcn.h>
#import <mach/vm_param.h>
#import <unistd.h>

#import "HUDPresetPosition.h"
#import "HUDRootViewController.h"
#import "HUDBackdropLabel.h"
#import "TrollSpeed-Swift.h"

#pragma mark -

#if !NO_TROLL
#import "FBSOrientationUpdate.h"
#import "FBSOrientationObserver.h"
#import "UIApplication+Private.h"
#import "LSApplicationProxy.h"
#import "LSApplicationWorkspace.h"
#import "SpringBoardServices.h"

#define NOTIFY_UI_LOCKSTATE    "com.apple.springboard.lockstate"
#define NOTIFY_LS_APP_CHANGED  "com.apple.LaunchServices.ApplicationsChanged"

static void LaunchServicesApplicationStateChanged
(CFNotificationCenterRef center,
 void *observer,
 CFStringRef name,
 const void *object,
 CFDictionaryRef userInfo)
{
    /* Application installed or uninstalled */

    BOOL isAppInstalled = NO;
    
    for (LSApplicationProxy *app in [[objc_getClass("LSApplicationWorkspace") defaultWorkspace] allApplications])
    {
        if ([app.applicationIdentifier isEqualToString:@"ch.xxtou.hudapp"])
        {
            isAppInstalled = YES;
            break;
        }
    }

    if (!isAppInstalled)
    {
        UIApplication *app = [UIApplication sharedApplication];
        [app terminateWithSuccess];
    }
}

static void SpringBoardLockStatusChanged
(CFNotificationCenterRef center,
 void *observer,
 CFStringRef name,
 const void *object,
 CFDictionaryRef userInfo)
{
    HUDRootViewController *rootViewController = (__bridge HUDRootViewController *)observer;
    NSString *lockState = (__bridge NSString *)name;
    if ([lockState isEqualToString:@NOTIFY_UI_LOCKSTATE])
    {
        mach_port_t sbsPort = SBSSpringBoardServerPort();
        
        if (sbsPort == MACH_PORT_NULL)
            return;
        
        BOOL isLocked;
        BOOL isPasscodeSet;
        SBGetScreenLockStatus(sbsPort, &isLocked, &isPasscodeSet);

        if (!isLocked)
        {
            [rootViewController.view setHidden:NO];
            [rootViewController resetLoopTimer];
        }
        else
        {
            [rootViewController stopLoopTimer];
            [rootViewController.view setHidden:YES];
        }
    }
}
#endif

#pragma mark - NetworkSpeed13

#define KILOBITS 1000
#define MEGABITS 1000000
#define GIGABITS 1000000000
#define KILOBYTES (1 << 10)
#define MEGABYTES (1 << 20)
#define GIGABYTES (1 << 30)
#define UPDATE_INTERVAL 1.0
#define SHOW_ALWAYS 1
#define INLINE_SEPARATOR "\t"
#define IDLE_INTERVAL 3.0

static const double HUD_MIN_FONT_SIZE = 9.0;
static const double HUD_MAX_FONT_SIZE = 10.0;
static const double HUD_MIN_CORNER_RADIUS = 4.5;
static const double HUD_MAX_CORNER_RADIUS = 5.0;
static double HUD_FONT_SIZE = 8.0;
static UIFontWeight HUD_FONT_WEIGHT = UIFontWeightRegular;
static CGFloat HUD_INACTIVE_OPACITY = 0.667;
static uint8_t HUD_DATA_UNIT = 0;
static uint8_t HUD_SHOW_UPLOAD_SPEED = 1;
static uint8_t HUD_SHOW_DOWNLOAD_SPEED = 1;
static uint8_t HUD_SHOW_DOWNLOAD_SPEED_FIRST = 1;
static uint8_t HUD_SHOW_SECOND_SPEED_IN_NEW_LINE = 0;
static const char *HUD_UPLOAD_PREFIX = "▲";
static const char *HUD_DOWNLOAD_PREFIX = "▼";

typedef struct {
    uint64_t inputBytes;
    uint64_t outputBytes;
} UpDownBytes;

static NSString *formattedSpeed(uint64_t bytes, BOOL isFocused)
{
    if (isFocused)
    {
        if (0 == HUD_DATA_UNIT)
        {
            if (bytes < KILOBYTES) {
                static NSString *_string = nil;
                static dispatch_once_t onceToken;
                dispatch_once(&onceToken, ^{
                    _string = NSLocalizedString(@"0 KB", @"formattedSpeed");
                });
                return _string;
            }
            else if (bytes < MEGABYTES) {
                static NSString *_string = nil;
                static dispatch_once_t onceToken;
                dispatch_once(&onceToken, ^{
                    _string = NSLocalizedString(@"%.0f KB", @"formattedSpeed");
                });
                return [NSString stringWithFormat:_string, (double)bytes / KILOBYTES];
            }
            else if (bytes < GIGABYTES) {
                static NSString *_string = nil;
                static dispatch_once_t onceToken;
                dispatch_once(&onceToken, ^{
                    _string = NSLocalizedString(@"%.2f MB", @"formattedSpeed");
                });
                return [NSString stringWithFormat:_string, (double)bytes / MEGABYTES];
            }
            else {
                static NSString *_string = nil;
                static dispatch_once_t onceToken;
                dispatch_once(&onceToken, ^{
                    _string = NSLocalizedString(@"%.2f GB", @"formattedSpeed");
                });
                return [NSString stringWithFormat:_string, (double)bytes / GIGABYTES];
            }
        }
        else
        {
            if (bytes < KILOBITS) {
                static NSString *_string = nil;
                static dispatch_once_t onceToken;
                dispatch_once(&onceToken, ^{
                    _string = NSLocalizedString(@"0 Kb", @"formattedSpeed");
                });
                return _string;
            }
            else if (bytes < MEGABITS) {
                static NSString *_string = nil;
                static dispatch_once_t onceToken;
                dispatch_once(&onceToken, ^{
                    _string = NSLocalizedString(@"%.0f Kb", @"formattedSpeed");
                });
                return [NSString stringWithFormat:_string, (double)bytes / KILOBITS];
            }
            else if (bytes < GIGABITS) {
                static NSString *_string = nil;
                static dispatch_once_t onceToken;
                dispatch_once(&onceToken, ^{
                    _string = NSLocalizedString(@"%.2f Mb", @"formattedSpeed");
                });
                return [NSString stringWithFormat:_string, (double)bytes / MEGABITS];
            }
            else {
                static NSString *_string = nil;
                static dispatch_once_t onceToken;
                dispatch_once(&onceToken, ^{
                    _string = NSLocalizedString(@"%.2f Gb", @"formattedSpeed");
                });
                return [NSString stringWithFormat:_string, (double)bytes / GIGABITS];
            }
        }
    }
    else {
        if (0 == HUD_DATA_UNIT)
        {
            if (bytes < KILOBYTES) {
                static NSString *_string = nil;
                static dispatch_once_t onceToken;
                dispatch_once(&onceToken, ^{
                    _string = NSLocalizedString(@"0 KB/s", @"formattedSpeed");
                });
                return _string;
            }
            else if (bytes < MEGABYTES) {
                static NSString *_string = nil;
                static dispatch_once_t onceToken;
                dispatch_once(&onceToken, ^{
                    _string = NSLocalizedString(@"%.0f KB/s", @"formattedSpeed");
                });
                return [NSString stringWithFormat:_string, (double)bytes / KILOBYTES];
            }
            else if (bytes < GIGABYTES) {
                static NSString *_string = nil;
                static dispatch_once_t onceToken;
                dispatch_once(&onceToken, ^{
                    _string = NSLocalizedString(@"%.2f MB/s", @"formattedSpeed");
                });
                return [NSString stringWithFormat:_string, (double)bytes / MEGABYTES];
            }
            else {
                static NSString *_string = nil;
                static dispatch_once_t onceToken;
                dispatch_once(&onceToken, ^{
                    _string = NSLocalizedString(@"%.2f GB/s", @"formattedSpeed");
                });
                return [NSString stringWithFormat:_string, (double)bytes / GIGABYTES];
            }
        }
        else
        {
            if (bytes < KILOBITS) {
                static NSString *_string = nil;
                static dispatch_once_t onceToken;
                dispatch_once(&onceToken, ^{
                    _string = NSLocalizedString(@"0 Kb/s", @"formattedSpeed");
                });
                return _string;
            }
            else if (bytes < MEGABITS) {
                static NSString *_string = nil;
                static dispatch_once_t onceToken;
                dispatch_once(&onceToken, ^{
                    _string = NSLocalizedString(@"%.0f Kb/s", @"formattedSpeed");
                });
                return [NSString stringWithFormat:_string, (double)bytes / KILOBITS];
            }
            else if (bytes < GIGABITS) {
                static NSString *_string = nil;
                static dispatch_once_t onceToken;
                dispatch_once(&onceToken, ^{
                    _string = NSLocalizedString(@"%.2f Mb/s", @"formattedSpeed");
                });
                return [NSString stringWithFormat:_string, (double)bytes / MEGABITS];
            }
            else {
                static NSString *_string = nil;
                static dispatch_once_t onceToken;
                dispatch_once(&onceToken, ^{
                    _string = NSLocalizedString(@"%.2f Gb/s", @"formattedSpeed");
                });
                return [NSString stringWithFormat:_string, (double)bytes / GIGABITS];
            }
        }
    }
}

typedef struct {
    uint64_t wifiInputBytes;
    uint64_t wifiOutputBytes;
    uint64_t cellularInputBytes;
    uint64_t cellularOutputBytes;
} SeparatedBytes;

static SeparatedBytes getSeparatedBytes(void)
{
    struct ifaddrs *ifa_list = 0, *ifa;
    SeparatedBytes bytes;
    memset(&bytes, 0, sizeof(bytes));

    if (getifaddrs(&ifa_list) == -1) return bytes;

    for (ifa = ifa_list; ifa; ifa = ifa->ifa_next)
    {
        /* Skip invalid interfaces */
        if (ifa->ifa_name == NULL || ifa->ifa_addr == NULL || ifa->ifa_data == NULL)
            continue;

        /* Skip interfaces that are not link level interfaces */
        if (AF_LINK != ifa->ifa_addr->sa_family)
            continue;

        /* Skip interfaces that are not up or running */
        if (!(ifa->ifa_flags & IFF_UP) && !(ifa->ifa_flags & IFF_RUNNING))
            continue;

        struct if_data *if_data = (struct if_data *)ifa->ifa_data;

        if (strncmp(ifa->ifa_name, "en", 2) == 0)
        {
            bytes.wifiInputBytes += if_data->ifi_ibytes;
            bytes.wifiOutputBytes += if_data->ifi_obytes;
        }
        else if (strncmp(ifa->ifa_name, "pdp_ip", 6) == 0)
        {
            bytes.cellularInputBytes += if_data->ifi_ibytes;
            bytes.cellularOutputBytes += if_data->ifi_obytes;
        }
    }

    freeifaddrs(ifa_list);
    return bytes;
}

static UpDownBytes getUpDownBytes()
{
    SeparatedBytes separatedBytes = getSeparatedBytes();
    UpDownBytes upDownBytes;
    upDownBytes.inputBytes = separatedBytes.wifiInputBytes + separatedBytes.cellularInputBytes;
    upDownBytes.outputBytes = separatedBytes.wifiOutputBytes + separatedBytes.cellularOutputBytes;
    return upDownBytes;
}

#pragma mark - Data Quota

#define HUD_QUOTA_PERSIST_INTERVAL 10.0
#define HUD_QUOTA_SSID_REFRESH_INTERVAL 6.0
#define HUD_QUOTA_SSID_UNKNOWN @"__unknown_wifi__"
#define HUD_QUOTA_PROFILE_TOTAL_KEY @"total"
#define HUD_QUOTA_PROFILE_USED_KEY @"used"

typedef NS_ENUM(NSInteger, HUDNetworkKind) {
    HUDNetworkKindNone = 0,
    HUDNetworkKindWiFi = 1,
    HUDNetworkKindCellular = 2,
};

static NSString *formattedQuotaBytes(double bytes)
{
    if (bytes <= 0) {
        return NSLocalizedString(@"0 KB", @"formattedQuotaBytes");
    }
    if (bytes >= GIGABYTES) {
        return [NSString stringWithFormat:@"%.2f GB", bytes / GIGABYTES];
    }
    if (bytes >= MEGABYTES) {
        return [NSString stringWithFormat:@"%.0f MB", bytes / MEGABYTES];
    }
    return [NSString stringWithFormat:@"%.0f KB", bytes / KILOBYTES];
}

static NSMutableDictionary *loadQuotaDictionary(void)
{
    NSDictionary *dictionary = [NSDictionary dictionaryWithContentsOfFile:(HUD_QUOTA_PLIST_PATH)];
    return dictionary ? [dictionary mutableCopy] : [NSMutableDictionary dictionary];
}

static void saveQuotaDictionary(NSDictionary *dictionary)
{
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:dictionary
                                                              format:NSPropertyListBinaryFormat_v1_0
                                                             options:0
                                                               error:NULL];
    if (data) {
        [data writeToFile:(HUD_QUOTA_PLIST_PATH) atomically:YES];
    }

    NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
    attributes[NSFilePosixPermissions] = @0644;
    if (geteuid() == 0) {
        attributes[NSFileOwnerAccountID] = @501;
        attributes[NSFileGroupOwnerAccountID] = @501;
    }
    [[NSFileManager defaultManager] setAttributes:attributes ofItemAtPath:(HUD_QUOTA_PLIST_PATH) error:NULL];
}

static BOOL HUDInterfaceHasIPv4(const char *prefix, size_t prefixLength)
{
    struct ifaddrs *list = NULL, *ifa;
    if (getifaddrs(&list) == -1) {
        return NO;
    }

    BOOL found = NO;
    for (ifa = list; ifa != NULL; ifa = ifa->ifa_next) {
        if (ifa->ifa_name == NULL || ifa->ifa_addr == NULL) {
            continue;
        }
        if (strncmp(ifa->ifa_name, prefix, prefixLength) != 0) {
            continue;
        }
        if (ifa->ifa_addr->sa_family != AF_INET) {
            continue;
        }
        found = YES;
        break;
    }

    freeifaddrs(list);
    return found;
}

/* Wi-Fi wins when both Wi-Fi and cellular have an address: that is the interface
   the system is actually routing traffic through. */
static HUDNetworkKind HUDCurrentNetworkKind(void)
{
    if (HUDInterfaceHasIPv4("en", 2)) {
        return HUDNetworkKindWiFi;
    }
    if (HUDInterfaceHasIPv4("pdp_ip", 6)) {
        return HUDNetworkKindCellular;
    }
    return HUDNetworkKindNone;
}

/* Only the public CaptiveNetwork API is used here. The HUD runs as root
   (platform-application), and the app carries the Wi-Fi info entitlement; when the
   system still refuses to hand it over we simply fall back to a generic name
   instead of risking a crash in a private framework. */
static NSString *HUDReadWiFiSSID(void)
{
    typedef CFDictionaryRef (*HUDCopyNetworkInfoFunc)(CFStringRef);
    static HUDCopyNetworkInfoFunc copyNetworkInfo = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        void *captiveHandle = dlopen("/System/Library/Frameworks/CaptiveNetwork.framework/CaptiveNetwork", RTLD_LAZY);
        if (!captiveHandle) {
            captiveHandle = dlopen("/System/Library/PrivateFrameworks/CaptiveNetwork.framework/CaptiveNetwork", RTLD_LAZY);
        }
        if (captiveHandle) {
            copyNetworkInfo = (HUDCopyNetworkInfoFunc)dlsym(captiveHandle, "CNCopyCurrentNetworkInfo");
        }
    });

    if (!copyNetworkInfo) {
        return nil;
    }

    NSString *name = nil;
    @try {
        CFDictionaryRef info = copyNetworkInfo(CFSTR("en0"));
        if (info) {
            id ssid = [(__bridge NSDictionary *)info objectForKey:@"SSID"];
            if ([ssid isKindOfClass:[NSString class]] && [ssid length] > 0) {
                name = [ssid copy];
            }
            CFRelease(info);
        }
    } @catch (__unused NSException *exception) {
        name = nil;
    }

    return name;
}

@interface HUDQuotaStore : NSObject

@property (nonatomic, assign) BOOL enabled;
@property (nonatomic, assign) HUDNetworkKind networkKind;
@property (nonatomic, copy) NSString *ssid;
@property (nonatomic, strong) NSMutableDictionary *wifiProfiles;
@property (nonatomic, assign) double cellularTotalBytes;
@property (nonatomic, assign) double cellularUsedBytes;
@property (nonatomic, assign) double cellularLastRawBytes;
@property (nonatomic, assign) double wifiLastRawBytes;
@property (nonatomic, assign) NSTimeInterval lastPersistTime;
@property (nonatomic, assign) BOOL needsPersist;

- (void)reload;
- (void)refreshNetworkContext;
- (void)accumulateSeparatedBytes:(SeparatedBytes)bytes;
- (BOOL)activeHasQuota;
- (double)activeRemainingBytes;
- (double)activeRemainingFraction;
- (NSString *)activeNetworkName;
- (void)persistIfNeeded:(BOOL)force;

@end

@implementation HUDQuotaStore

- (void)reload
{
    NSDictionary *dictionary = [NSDictionary dictionaryWithContentsOfFile:(HUD_QUOTA_PLIST_PATH)];
    self.enabled = [[dictionary objectForKey:HUDUserDefaultsKeyUsesDataQuota] boolValue];

    /* Old keys (single shared quota) are migrated into the cellular slot the
       first time the new build runs, so nobody loses the numbers they already had. */
    double legacyTotal = [[dictionary objectForKey:HUDUserDefaultsKeyDataQuotaTotalBytes] doubleValue];
    double legacyUsed = [[dictionary objectForKey:HUDUserDefaultsKeyDataQuotaUsedBytes] doubleValue];

    self.cellularTotalBytes = [[dictionary objectForKey:HUDUserDefaultsKeyCellularQuotaTotalBytes] doubleValue];
    if (self.cellularTotalBytes <= 0 && legacyTotal > 0) {
        self.cellularTotalBytes = legacyTotal;
    }

    self.cellularUsedBytes = [[dictionary objectForKey:HUDUserDefaultsKeyCellularQuotaUsedBytes] doubleValue];
    if (self.cellularUsedBytes <= 0 && legacyUsed > 0) {
        self.cellularUsedBytes = legacyUsed;
    }

    self.cellularLastRawBytes = [[dictionary objectForKey:HUDUserDefaultsKeyCellularQuotaLastRaw] doubleValue];

    NSDictionary *profiles = [dictionary objectForKey:HUDUserDefaultsKeyWifiQuotaProfiles];
    self.wifiProfiles = [profiles isKindOfClass:[NSDictionary class]] ? [profiles mutableCopy] : [NSMutableDictionary dictionary];

    self.wifiLastRawBytes = 0.0;
    self.needsPersist = NO;

    [self refreshNetworkContext];
}

- (NSMutableDictionary *)wifiProfileForSSID:(NSString *)ssid create:(BOOL)create
{
    if (ssid.length == 0) {
        return nil;
    }

    /* Values read from the plist are immutable, so always hand out a mutable copy
       and put it back; writing into a plist-owned dictionary would crash the HUD. */
    id stored = [self.wifiProfiles objectForKey:ssid];
    if (stored) {
        if ([stored isKindOfClass:[NSMutableDictionary class]]) {
            return stored;
        }
        NSMutableDictionary *mutableProfile = [stored isKindOfClass:[NSDictionary class]] ? [stored mutableCopy] : [NSMutableDictionary dictionary];
        [self.wifiProfiles setObject:mutableProfile forKey:ssid];
        return mutableProfile;
    }

    if (!create) {
        return nil;
    }

    NSMutableDictionary *profile = [NSMutableDictionary dictionary];
    [self.wifiProfiles setObject:profile forKey:ssid];
    return profile;
}

- (NSMutableDictionary *)currentWiFiProfile:(BOOL)create
{
    if (self.networkKind != HUDNetworkKindWiFi) {
        return nil;
    }
    NSString *ssid = self.ssid.length > 0 ? self.ssid : HUD_QUOTA_SSID_UNKNOWN;
    return [self wifiProfileForSSID:ssid create:create];
}

- (void)refreshNetworkContext
{
    HUDNetworkKind kind = HUDCurrentNetworkKind();
    NSString *ssid = nil;
    if (kind == HUDNetworkKindWiFi) {
        ssid = HUDReadWiFiSSID();
    }

    BOOL changed = (kind != self.networkKind);
    if (!changed && kind == HUDNetworkKindWiFi) {
        changed = (ssid.length > 0 && ![ssid isEqualToString:self.ssid]);
    }

    self.networkKind = kind;
    self.ssid = ssid;

    if (changed) {
        /* Never carry a byte baseline across networks, otherwise the jump in the
           raw counters would be booked as usage on the wrong network. */
        self.wifiLastRawBytes = 0.0;
        self.needsPersist = YES;
    }
}

- (void)accumulateSeparatedBytes:(SeparatedBytes)bytes
{
    double cellularRaw = (double)(bytes.cellularInputBytes + bytes.cellularOutputBytes);
    double wifiRaw = (double)(bytes.wifiInputBytes + bytes.wifiOutputBytes);

    if (!self.enabled) {
        self.cellularLastRawBytes = cellularRaw;
        self.wifiLastRawBytes = wifiRaw;
        return;
    }

    /* Cellular: counted only when a cellular quota has been configured */
    if (self.cellularLastRawBytes > 0.0 && cellularRaw >= self.cellularLastRawBytes) {
        double delta = cellularRaw - self.cellularLastRawBytes;
        if (delta > 0 && self.cellularTotalBytes > 0) {
            self.cellularUsedBytes += delta;
            self.needsPersist = YES;
        }
    }
    self.cellularLastRawBytes = cellularRaw;

    /* Wi-Fi: counted only for the SSID the user has configured */
    if (wifiRaw > 0) {
        NSMutableDictionary *profile = [self currentWiFiProfile:YES];
        double profileTotal = profile ? [[profile objectForKey:HUD_QUOTA_PROFILE_TOTAL_KEY] doubleValue] : 0.0;
        if (profile && profileTotal > 0 && self.wifiLastRawBytes > 0.0 && wifiRaw >= self.wifiLastRawBytes) {
            double delta = wifiRaw - self.wifiLastRawBytes;
            if (delta > 0) {
                double used = [[profile objectForKey:HUD_QUOTA_PROFILE_USED_KEY] doubleValue] + delta;
                [profile setObject:@(used) forKey:HUD_QUOTA_PROFILE_USED_KEY];
                self.needsPersist = YES;
            }
        }
        self.wifiLastRawBytes = wifiRaw;
    }
}

- (BOOL)activeHasQuota
{
    if (!self.enabled) {
        return NO;
    }
    if (self.networkKind == HUDNetworkKindCellular) {
        return self.cellularTotalBytes > 0;
    }
    if (self.networkKind == HUDNetworkKindWiFi) {
        NSMutableDictionary *profile = [self currentWiFiProfile:NO];
        return profile != nil && [[profile objectForKey:HUD_QUOTA_PROFILE_TOTAL_KEY] doubleValue] > 0;
    }
    return NO;
}

- (double)activeTotalBytes
{
    if (self.networkKind == HUDNetworkKindCellular) {
        return self.cellularTotalBytes;
    }
    NSMutableDictionary *profile = [self currentWiFiProfile:NO];
    return profile ? [[profile objectForKey:HUD_QUOTA_PROFILE_TOTAL_KEY] doubleValue] : 0.0;
}

- (double)activeUsedBytes
{
    if (self.networkKind == HUDNetworkKindCellular) {
        return self.cellularUsedBytes;
    }
    NSMutableDictionary *profile = [self currentWiFiProfile:NO];
    return profile ? [[profile objectForKey:HUD_QUOTA_PROFILE_USED_KEY] doubleValue] : 0.0;
}

- (double)activeRemainingBytes
{
    return MAX([self activeTotalBytes] - [self activeUsedBytes], 0.0);
}

- (double)activeRemainingFraction
{
    double total = [self activeTotalBytes];
    if (total <= 0) {
        return 0.0;
    }
    double fraction = [self activeRemainingBytes] / total;
    return MIN(MAX(fraction, 0.0), 1.0);
}

- (NSString *)activeNetworkName
{
    if (self.networkKind == HUDNetworkKindWiFi) {
        return self.ssid.length > 0 ? self.ssid : @"Wi-Fi";
    }
    if (self.networkKind == HUDNetworkKindCellular) {
        return @"4G网络";
    }
    return nil;
}

- (void)persistIfNeeded:(BOOL)force
{
    if (!force && !self.needsPersist) {
        return;
    }

    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    if (!force && (now - self.lastPersistTime) < HUD_QUOTA_PERSIST_INTERVAL) {
        return;
    }

    NSMutableDictionary *dictionary = loadQuotaDictionary();
    [dictionary setObject:@(self.enabled) forKey:HUDUserDefaultsKeyUsesDataQuota];
    [dictionary setObject:@(self.cellularTotalBytes) forKey:HUDUserDefaultsKeyCellularQuotaTotalBytes];
    [dictionary setObject:@(self.cellularUsedBytes) forKey:HUDUserDefaultsKeyCellularQuotaUsedBytes];
    [dictionary setObject:@(self.cellularLastRawBytes) forKey:HUDUserDefaultsKeyCellularQuotaLastRaw];
    [dictionary setObject:(self.wifiProfiles ?: @{}) forKey:HUDUserDefaultsKeyWifiQuotaProfiles];
    [dictionary setObject:@(self.networkKind) forKey:HUDUserDefaultsKeyCurrentNetworkType];
    if (self.ssid.length > 0) {
        [dictionary setObject:self.ssid forKey:HUDUserDefaultsKeyCurrentWifiSSID];
    } else {
        [dictionary removeObjectForKey:HUDUserDefaultsKeyCurrentWifiSSID];
    }
    saveQuotaDictionary(dictionary);

    self.lastPersistTime = now;
    self.needsPersist = NO;
}

@end

@class HUDQuotaLiquidView;

/* The liquid tank that lives behind the speed label:
   the fill height represents the remaining data quota. */
@interface HUDQuotaLiquidView : UIView

@property (nonatomic, assign) double level;
@property (nonatomic, assign) double displayedLevel;
@property (nonatomic, assign) CGFloat wavePhase;

- (void)setLevel:(double)level animated:(BOOL)animated;
- (void)stepAnimation;
- (void)startAnimating;
- (void)stopAnimating;

@end

@interface HUDQuotaDisplayLinkProxy : NSObject
@property (nonatomic, weak) HUDQuotaLiquidView *view;
@end

@implementation HUDQuotaDisplayLinkProxy
- (void)tick:(CADisplayLink *)displayLink
{
    HUDQuotaLiquidView *view = self.view;
    if (view) {
        [view stepAnimation];
    }
}
@end

@implementation HUDQuotaLiquidView {
    CADisplayLink *_displayLink;
    HUDQuotaDisplayLinkProxy *_displayLinkProxy;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.opaque = NO;
        self.backgroundColor = [UIColor clearColor];
        self.userInteractionEnabled = NO;
        self.clipsToBounds = YES;
        self.displayedLevel = 0.0;
    }
    return self;
}

- (void)dealloc
{
    [_displayLink invalidate];
}

- (void)didMoveToWindow
{
    [super didMoveToWindow];
    if (self.window && !self.hidden) {
        [self startAnimating];
    } else {
        [self stopAnimating];
    }
}

- (void)setHidden:(BOOL)hidden
{
    [super setHidden:hidden];
    if (hidden) {
        [self stopAnimating];
    } else if (self.window) {
        [self startAnimating];
    }
}

- (void)startAnimating
{
    if (_displayLink) {
        return;
    }
    if (!_displayLinkProxy) {
        _displayLinkProxy = [[HUDQuotaDisplayLinkProxy alloc] init];
        _displayLinkProxy.view = self;
    }
    _displayLink = [CADisplayLink displayLinkWithTarget:_displayLinkProxy selector:@selector(tick:)];
    _displayLink.preferredFramesPerSecond = 30;
    [_displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)stopAnimating
{
    [_displayLink invalidate];
    _displayLink = nil;
}

- (void)setLevel:(double)level animated:(BOOL)animated
{
    self.level = MIN(MAX(level, 0.0), 1.0);
    if (!animated) {
        self.displayedLevel = self.level;
        [self setNeedsDisplay];
    }
}

- (void)stepAnimation
{
    self.wavePhase += 0.06;
    if (self.wavePhase > (CGFloat)(2 * M_PI)) {
        self.wavePhase -= (CGFloat)(2 * M_PI);
    }

    double difference = self.level - self.displayedLevel;
    if (fabs(difference) > 0.0004) {
        self.displayedLevel += difference * 0.10;
    } else {
        self.displayedLevel = self.level;
    }

    [self setNeedsDisplay];
}

- (CGFloat)edgeXForY:(CGFloat)y width:(CGFloat)width level:(CGFloat)level amplitude:(CGFloat)amplitude
{
    CGFloat x = width * level
              + sin((y / 3.2) + self.wavePhase) * amplitude
              + sin((y / 1.6) - self.wavePhase * 1.3) * (amplitude * 0.45);
    return MIN(MAX(x, 0.0), width);
}

- (void)drawRect:(CGRect)rect
{
    CGRect bounds = self.bounds;
    CGFloat width = CGRectGetWidth(bounds);
    CGFloat height = CGRectGetHeight(bounds);
    if (width <= 0 || height <= 0) {
        return;
    }

    double level = MIN(MAX(self.displayedLevel, 0.0), 1.0);
    CGFloat fillX = width * (CGFloat)level;
    CGFloat amplitude = 0.0;
    if (level > 0.02) {
        /* The edge only wobbles sideways, never up and down */
        amplitude = MIN(MIN(height * 0.14, 1.8), fillX * 0.16);
    }

    CGFloat step = 1.0;

    UIBezierPath *liquidPath = [UIBezierPath bezierPath];
    [liquidPath moveToPoint:CGPointMake(0, 0)];
    for (CGFloat y = 0; y <= height; y += step) {
        CGFloat x = [self edgeXForY:y width:width level:(CGFloat)level amplitude:amplitude];
        [liquidPath addLineToPoint:CGPointMake(x, y)];
    }
    [liquidPath addLineToPoint:CGPointMake(0, height)];
    [liquidPath closePath];

    CGContextRef context = UIGraphicsGetCurrentContext();
    if (!context) {
        return;
    }

    /* Green tank: the wide part is how much quota is left */
    UIColor *leftColor;
    UIColor *rightColor;
    if (level <= 0.20) {
        CGFloat pulse = 0.72 + 0.28 * (CGFloat)fabs(sin(self.wavePhase * 1.2));
        leftColor = [UIColor colorWithRed:0.52 green:1.00 blue:0.56 alpha:pulse];
        rightColor = [UIColor colorWithRed:0.10 green:0.68 blue:0.26 alpha:pulse];
    } else {
        leftColor = [UIColor colorWithRed:0.44 green:0.98 blue:0.55 alpha:0.88];
        rightColor = [UIColor colorWithRed:0.02 green:0.56 blue:0.20 alpha:0.94];
    }

    CGContextSaveGState(context);
    CGContextAddPath(context, liquidPath.CGPath);
    CGContextClip(context);

    CGGradientRef gradient = CGGradientCreateWithColors(NULL,
        (__bridge CFArrayRef)@[(__bridge id)leftColor.CGColor, (__bridge id)rightColor.CGColor],
        (CGFloat[]){ 0.0, 1.0 });
    CGContextDrawLinearGradient(context, gradient,
        CGPointMake(0, 0), CGPointMake(MAX(fillX, 0.01), 0),
        kCGGradientDrawsBeforeStartLocation | kCGGradientDrawsAfterEndLocation);
    CGGradientRelease(gradient);

    /* Bubbles drift towards the liquid edge */
    for (NSInteger index = 0; index < 3; index++) {
        CGFloat progress = (CGFloat)fmod((double)(self.wavePhase * 0.30) + index * 0.33, 1.0);
        CGFloat bubbleX = fillX * progress;
        CGFloat bubbleY = height * (0.25 + 0.25 * (CGFloat)index);
        if (bubbleX > fillX - 1.2) {
            continue;
        }
        CGFloat radius = 0.7 + 0.4 * (CGFloat)index;
        CGContextSetFillColorWithColor(context, [UIColor colorWithWhite:1.0 alpha:0.22].CGColor);
        CGContextFillEllipseInRect(context, CGRectMake(bubbleX - radius, bubbleY - radius, radius * 2, radius * 2));
    }

    CGContextRestoreGState(context);

    /* Vertical glossy line at the liquid edge */
    if (level > 0.001) {
        UIBezierPath *surfaceLine = [UIBezierPath bezierPath];
        BOOL started = NO;
        for (CGFloat y = 0; y <= height; y += step) {
            CGFloat x = [self edgeXForY:y width:width level:(CGFloat)level amplitude:amplitude];
            if (!started) {
                [surfaceLine moveToPoint:CGPointMake(x, y)];
                started = YES;
            } else {
                [surfaceLine addLineToPoint:CGPointMake(x, y)];
            }
        }
        [[UIColor colorWithWhite:1.0 alpha:0.45] setStroke];
        surfaceLine.lineWidth = 0.8;
        [surfaceLine stroke];
    }
}

@end

static HUDQuotaStore *gQuotaStore = nil;

static BOOL shouldUpdateSpeedLabel;
static uint64_t prevOutputBytes = 0, prevInputBytes = 0;
static NSAttributedString *attributedUploadPrefix = nil;
static NSAttributedString *attributedDownloadPrefix = nil;
static NSAttributedString *attributedInlineSeparator = nil;
static NSAttributedString *attributedLineSeparator = nil;

static NSAttributedString *formattedAttributedString(BOOL isFocused)
{
    @autoreleasepool
    {
        if (!attributedUploadPrefix)
            attributedUploadPrefix = [[NSAttributedString alloc] initWithString:[[NSString stringWithUTF8String:HUD_UPLOAD_PREFIX] stringByAppendingString:@" "] attributes:@{ NSFontAttributeName: [UIFont boldSystemFontOfSize:HUD_FONT_SIZE] }];
        if (!attributedDownloadPrefix)
            attributedDownloadPrefix = [[NSAttributedString alloc] initWithString:[[NSString stringWithUTF8String:HUD_DOWNLOAD_PREFIX] stringByAppendingString:@" "] attributes:@{ NSFontAttributeName: [UIFont boldSystemFontOfSize:HUD_FONT_SIZE] }];
        if (!attributedInlineSeparator)
            attributedInlineSeparator = [[NSAttributedString alloc] initWithString:[NSString stringWithUTF8String:INLINE_SEPARATOR] attributes:@{ NSFontAttributeName: [UIFont boldSystemFontOfSize:HUD_FONT_SIZE] }];
        if (!attributedLineSeparator)
            attributedLineSeparator = [[NSAttributedString alloc] initWithString:@"\n" attributes:@{ NSFontAttributeName: [UIFont boldSystemFontOfSize:HUD_FONT_SIZE] }];

        NSMutableAttributedString *mutableString = [[NSMutableAttributedString alloc] init];

        UpDownBytes upDownBytes = getUpDownBytes();

        uint64_t upDiff;
        uint64_t downDiff;

        if (isFocused)
        {
            upDiff = upDownBytes.outputBytes;
            downDiff = upDownBytes.inputBytes;
        }
        else
        {
            if (upDownBytes.outputBytes > prevOutputBytes)
                upDiff = upDownBytes.outputBytes - prevOutputBytes;
            else
                upDiff = 0;
            
            if (upDownBytes.inputBytes > prevInputBytes)
                downDiff = upDownBytes.inputBytes - prevInputBytes;
            else
                downDiff = 0;
        }
        
        prevOutputBytes = upDownBytes.outputBytes;
        prevInputBytes = upDownBytes.inputBytes;

        if (!SHOW_ALWAYS && (upDiff < 2 * KILOBYTES && downDiff < 2 * KILOBYTES))
        {
            shouldUpdateSpeedLabel = NO;
            return nil;
        }
        else shouldUpdateSpeedLabel = YES;

        if (HUD_DATA_UNIT == 1)
        {
            upDiff *= BYTE_SIZE;
            downDiff *= BYTE_SIZE;
        }

        if (HUD_SHOW_DOWNLOAD_SPEED_FIRST)
        {
            if (HUD_SHOW_DOWNLOAD_SPEED)
            {
                [mutableString appendAttributedString:attributedDownloadPrefix];
                [mutableString appendAttributedString:[[NSAttributedString alloc] initWithString:formattedSpeed(downDiff, isFocused) attributes:@{ NSFontAttributeName: [UIFont monospacedDigitSystemFontOfSize:HUD_FONT_SIZE weight:HUD_FONT_WEIGHT] }]];
            }

            if (HUD_SHOW_UPLOAD_SPEED)
            {
                if ([mutableString length] > 0)
                {
                    if (HUD_SHOW_SECOND_SPEED_IN_NEW_LINE) [mutableString appendAttributedString:attributedLineSeparator];
                    else [mutableString appendAttributedString:attributedInlineSeparator];
                }

                [mutableString appendAttributedString:attributedUploadPrefix];
                [mutableString appendAttributedString:[[NSAttributedString alloc] initWithString:formattedSpeed(upDiff, isFocused) attributes:@{ NSFontAttributeName: [UIFont monospacedDigitSystemFontOfSize:HUD_FONT_SIZE weight:HUD_FONT_WEIGHT] }]];
            }
        }
        else
        {
            if (HUD_SHOW_UPLOAD_SPEED)
            {
                [mutableString appendAttributedString:attributedUploadPrefix];
                [mutableString appendAttributedString:[[NSAttributedString alloc] initWithString:formattedSpeed(upDiff, isFocused) attributes:@{ NSFontAttributeName: [UIFont monospacedDigitSystemFontOfSize:HUD_FONT_SIZE weight:HUD_FONT_WEIGHT] }]];
            }
            if (HUD_SHOW_DOWNLOAD_SPEED)
            {
                if ([mutableString length] > 0)
                {
                    if (HUD_SHOW_SECOND_SPEED_IN_NEW_LINE) [mutableString appendAttributedString:attributedLineSeparator];
                    else [mutableString appendAttributedString:attributedInlineSeparator];
                }

                [mutableString appendAttributedString:attributedDownloadPrefix];
                [mutableString appendAttributedString:[[NSAttributedString alloc] initWithString:formattedSpeed(downDiff, isFocused) attributes:@{ NSFontAttributeName: [UIFont monospacedDigitSystemFontOfSize:HUD_FONT_SIZE weight:HUD_FONT_WEIGHT] }]];
            }
        }
        
        if (isFocused && gQuotaStore && [gQuotaStore activeHasQuota])
        {
            NSString *quotaString = [NSString stringWithFormat:NSLocalizedString(@"可用 %@", @"formattedQuota"),
                                     formattedQuotaBytes([gQuotaStore activeRemainingBytes])];
            NSAttributedString *quotaLine = [[NSAttributedString alloc] initWithString:quotaString attributes:@{
                NSFontAttributeName: [UIFont monospacedDigitSystemFontOfSize:MAX(HUD_FONT_SIZE - 1.5, 6.0) weight:HUD_FONT_WEIGHT],
                NSForegroundColorAttributeName: [UIColor colorWithWhite:1.0 alpha:0.72],
            }];
            [mutableString appendAttributedString:attributedLineSeparator];
            [mutableString appendAttributedString:quotaLine];
        }

        return [mutableString copy];
    }
}

/* Name of the network currently in use: the SSID for Wi-Fi, "4G网络" for cellular */
static NSAttributedString *formattedNetworkNameAttributedString(void)
{
    NSString *name = [gQuotaStore activeNetworkName];
    if (name.length == 0) {
        return nil;
    }
    if (name.length > 18) {
        name = [[name substringToIndex:17] stringByAppendingString:@"…"];
    }
    return [[NSAttributedString alloc] initWithString:name attributes:@{
        NSFontAttributeName: [UIFont boldSystemFontOfSize:MAX(HUD_FONT_SIZE - 0.5, 6.0)],
    }];
}

/* The network name takes its turn in the same label as the speed readout:
   every third refresh shows the network name instead of up/down speeds. */
static NSAttributedString *formattedDisplayAttributedString(BOOL isFocused)
{
    static NSUInteger tick = 0;

    NSAttributedString *speedString = formattedAttributedString(isFocused);
    if (!speedString) {
        return nil;
    }

    tick++;
    if ((tick % 3) != 0) {
        return speedString;
    }

    NSAttributedString *nameString = formattedNetworkNameAttributedString();
    return nameString ?: speedString;
}

#pragma mark - HUDRootViewController

@interface HUDRootViewController (Troll)
- (void)updateOrientation:(UIInterfaceOrientation)orientation animateWithDuration:(NSTimeInterval)duration;
@end

static const CACornerMask kCornerMaskBottom = kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner;
static const CACornerMask kCornerMaskAll = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner | kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner;

@implementation HUDRootViewController {
    NSMutableDictionary *_userDefaults;
    NSMutableArray <NSLayoutConstraint *> *_constraints;
    UIBlurEffect *_blurEffect;
    UIVisualEffectView *_blurView;
    ScreenshotInvisibleContainer *_containerView;
    UIView *_contentView;
    HUDBackdropLabel *_speedLabel;
    HUDQuotaLiquidView *_quotaLiquidView;
    UIImageView *_lockedView;
    NSTimer *_timer;
    UITapGestureRecognizer *_tapGestureRecognizer;
    UIPanGestureRecognizer *_panGestureRecognizer;
    UIImpactFeedbackGenerator *_impactFeedbackGenerator;
    UINotificationFeedbackGenerator *_notificationFeedbackGenerator;
    BOOL _isFocused;
    NSLayoutConstraint *_topConstraint;
    NSLayoutConstraint *_centerXConstraint;
    NSLayoutConstraint *_leadingConstraint;
    NSLayoutConstraint *_trailingConstraint;
    UIInterfaceOrientation _orientation;
#if !NO_TROLL
    FBSOrientationObserver *_orientationObserver;
#endif
}

- (void)registerNotifications
{
    int token;
    notify_register_dispatch(NOTIFY_RELOAD_HUD, &token, dispatch_get_main_queue(), ^(int token) {
        [self reloadUserDefaults];
    });

#if !NO_TROLL
    CFNotificationCenterRef darwinCenter = CFNotificationCenterGetDarwinNotifyCenter();
    
    CFNotificationCenterAddObserver(
        darwinCenter,
        (__bridge const void *)self,
        LaunchServicesApplicationStateChanged,
        CFSTR(NOTIFY_LS_APP_CHANGED),
        NULL,
        CFNotificationSuspensionBehaviorCoalesce
    );
    
    CFNotificationCenterAddObserver(
        darwinCenter,
        (__bridge const void *)self,
        SpringBoardLockStatusChanged,
        CFSTR(NOTIFY_UI_LOCKSTATE),
        NULL,
        CFNotificationSuspensionBehaviorCoalesce
    );

    NSUserDefaults *userDefaults = GetStandardUserDefaults();
    [userDefaults addObserver:self forKeyPath:HUDUserDefaultsKeyUsesCustomFontSize options:NSKeyValueObservingOptionNew context:nil];
    [userDefaults addObserver:self forKeyPath:HUDUserDefaultsKeyRealCustomFontSize options:NSKeyValueObservingOptionNew context:nil];
    [userDefaults addObserver:self forKeyPath:HUDUserDefaultsKeyUsesCustomOffset options:NSKeyValueObservingOptionNew context:nil];
    [userDefaults addObserver:self forKeyPath:HUDUserDefaultsKeyRealCustomOffsetX options:NSKeyValueObservingOptionNew context:nil];
    [userDefaults addObserver:self forKeyPath:HUDUserDefaultsKeyRealCustomOffsetY options:NSKeyValueObservingOptionNew context:nil];
#endif
}

#if !NO_TROLL
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if ([keyPath isEqualToString:HUDUserDefaultsKeyUsesCustomFontSize] ||
        [keyPath isEqualToString:HUDUserDefaultsKeyRealCustomFontSize] ||
        [keyPath isEqualToString:HUDUserDefaultsKeyUsesCustomOffset] ||
        [keyPath isEqualToString:HUDUserDefaultsKeyRealCustomOffsetX] ||
        [keyPath isEqualToString:HUDUserDefaultsKeyRealCustomOffsetY])
    {
        [self reloadUserDefaults];
    }
}
#endif

- (void)loadUserDefaults:(BOOL)forceReload
{
    if (forceReload || !_userDefaults)
        _userDefaults = [[NSDictionary dictionaryWithContentsOfFile:(ROOT_PATH_NS_VAR(USER_DEFAULTS_PATH))] mutableCopy] ?: [NSMutableDictionary dictionary];
}

- (void)saveUserDefaults
{
    BOOL wroteSucceed = [_userDefaults writeToFile:(ROOT_PATH_NS_VAR(USER_DEFAULTS_PATH)) atomically:YES];
    if (wroteSucceed) {
        [[NSFileManager defaultManager] setAttributes:@{
            NSFileOwnerAccountID: @501,
            NSFileGroupOwnerAccountID: @501,
        } ofItemAtPath:(ROOT_PATH_NS_VAR(USER_DEFAULTS_PATH)) error:nil];
        notify_post(NOTIFY_RELOAD_APP);
    }
}

- (void)reloadUserDefaults
{
    [self loadUserDefaults:YES];

    BOOL singleLineMode = [self singleLineMode];
    HUD_SHOW_UPLOAD_SPEED = !singleLineMode;

    BOOL usesBitrate = [self usesBitrate];
    HUD_DATA_UNIT = usesBitrate;

    BOOL usesArrowPrefixes = [self usesArrowPrefixes];
    HUD_UPLOAD_PREFIX = (usesArrowPrefixes ? "↑" : "▲");
    HUD_DOWNLOAD_PREFIX = (usesArrowPrefixes ? "↓" : "▼");

    BOOL usesCustomFontSize = [self usesCustomFontSize];
    if (!usesCustomFontSize) {
        BOOL usesLargeFont = [self usesLargeFont];
        HUD_FONT_SIZE = (usesLargeFont ? HUD_MAX_FONT_SIZE : HUD_MIN_FONT_SIZE);
        [_blurView.layer setCornerRadius:(usesLargeFont ? HUD_MAX_CORNER_RADIUS : HUD_MIN_CORNER_RADIUS)];
    } else {
        CGFloat realCustomFontSize = MIN(MAX([self realCustomFontSize], 8), 12);
        HUD_FONT_SIZE = realCustomFontSize;
        [_blurView.layer setCornerRadius:realCustomFontSize / 2.0];
    }

    BOOL usesInvertedColor = [self usesInvertedColor];
    HUD_FONT_WEIGHT = (usesInvertedColor ? UIFontWeightMedium : UIFontWeightRegular);
    HUD_INACTIVE_OPACITY = (usesInvertedColor ? 1.0 : 0.667);
    [_blurView setEffect:(usesInvertedColor ? nil : _blurEffect)];
    [_speedLabel setColorInvertEnabled:usesInvertedColor];
    [_lockedView setHidden:usesInvertedColor];

    [gQuotaStore reload];
    [self updateQuotaLiquidView];

    BOOL hideAtSnapshot = [self hideAtSnapshot];
    if (hideAtSnapshot) {
        [_containerView setupContainerAsHideContentInScreenshots];
    } else {
        [_containerView setupContainerAsDisplayContentInScreenshots];
    }

    prevInputBytes = 0;
    prevOutputBytes = 0;
    attributedUploadPrefix = nil;
    attributedDownloadPrefix = nil;

    [self removeAllAnimations];
    [self resetGestureRecognizers];
    [self updateViewConstraints];

    if (!_isFocused) {
        [self onFocus:_contentView];
    } else {
        [self keepFocus:_contentView];
    }

    [self performSelector:@selector(onBlur:) withObject:_contentView afterDelay:IDLE_INTERVAL];
}

+ (BOOL)passthroughMode
{
    return [[[NSDictionary dictionaryWithContentsOfFile:(ROOT_PATH_NS_VAR(USER_DEFAULTS_PATH))] objectForKey:HUDUserDefaultsKeyPassthroughMode] boolValue];
}

- (BOOL)isLandscapeOrientation
{
    BOOL isLandscape;
    if (_orientation == UIInterfaceOrientationUnknown) {
        isLandscape = CGRectGetWidth(self.view.bounds) > CGRectGetHeight(self.view.bounds);
    } else {
        isLandscape = UIInterfaceOrientationIsLandscape(_orientation);
    }
    return isLandscape;
}

- (HUDUserDefaultsKey)selectedModeKeyForCurrentOrientation
{
    return [self isLandscapeOrientation] ? HUDUserDefaultsKeySelectedModeLandscape : HUDUserDefaultsKeySelectedMode;
}

- (HUDPresetPosition)selectedModeForCurrentOrientation
{
    [self loadUserDefaults:NO];
    NSNumber *mode = [_userDefaults objectForKey:[self selectedModeKeyForCurrentOrientation]];
    return mode != nil ? (HUDPresetPosition)[mode integerValue] : HUDPresetPositionTopCenter;
}

- (BOOL)singleLineMode
{
    [self loadUserDefaults:NO];
    NSNumber *mode = [_userDefaults objectForKey:HUDUserDefaultsKeySingleLineMode];
    return mode != nil ? [mode boolValue] : NO;
}

- (BOOL)usesBitrate
{
    [self loadUserDefaults:NO];
    NSNumber *mode = [_userDefaults objectForKey:HUDUserDefaultsKeyUsesBitrate];
    return mode != nil ? [mode boolValue] : NO;
}

- (BOOL)usesArrowPrefixes
{
    [self loadUserDefaults:NO];
    NSNumber *mode = [_userDefaults objectForKey:HUDUserDefaultsKeyUsesArrowPrefixes];
    return mode != nil ? [mode boolValue] : NO;
}

- (BOOL)usesLargeFont
{
    [self loadUserDefaults:NO];
    NSNumber *mode = [_userDefaults objectForKey:HUDUserDefaultsKeyUsesLargeFont];
    return mode != nil ? [mode boolValue] : NO;
}

- (BOOL)usesRotation
{
    [self loadUserDefaults:NO];
    NSNumber *mode = [_userDefaults objectForKey:HUDUserDefaultsKeyUsesRotation];
    return mode != nil ? [mode boolValue] : NO;
}

- (BOOL)usesInvertedColor
{
    [self loadUserDefaults:NO];
    NSNumber *mode = [_userDefaults objectForKey:HUDUserDefaultsKeyUsesInvertedColor];
    return mode != nil ? [mode boolValue] : NO;
}

- (BOOL)keepInPlace
{
    [self loadUserDefaults:NO];
    NSNumber *mode = [_userDefaults objectForKey:HUDUserDefaultsKeyKeepInPlace];
    return mode != nil ? [mode boolValue] : NO;
}

- (BOOL)hideAtSnapshot
{
    [self loadUserDefaults:NO];
    NSNumber *mode = [_userDefaults objectForKey:HUDUserDefaultsKeyHideAtSnapshot];
    return mode != nil ? [mode boolValue] : NO;
}

- (CGFloat)currentPositionY
{
    [self loadUserDefaults:NO];
    NSNumber *positionY = [_userDefaults objectForKey:HUDUserDefaultsKeyCurrentPositionY];
    return positionY != nil ? [positionY doubleValue] : CGFLOAT_MAX;
}

- (void)setCurrentPositionY:(CGFloat)positionY
{
    [self loadUserDefaults:NO];
    [_userDefaults setObject:[NSNumber numberWithDouble:positionY] forKey:HUDUserDefaultsKeyCurrentPositionY];
    [self saveUserDefaults];
}

- (CGFloat)currentLandscapePositionY
{
    [self loadUserDefaults:NO];
    NSNumber *positionY = [_userDefaults objectForKey:HUDUserDefaultsKeyCurrentLandscapePositionY];
    return positionY != nil ? [positionY doubleValue] : CGFLOAT_MAX;
}

- (void)setCurrentLandscapePositionY:(CGFloat)positionY
{
    [self loadUserDefaults:NO];
    [_userDefaults setObject:[NSNumber numberWithDouble:positionY] forKey:HUDUserDefaultsKeyCurrentLandscapePositionY];
    [self saveUserDefaults];
}

- (CGFloat)currentPositionX
{
    [self loadUserDefaults:NO];
    NSNumber *positionX = [_userDefaults objectForKey:HUDUserDefaultsKeyCurrentPositionX];
    return positionX != nil ? [positionX doubleValue] : CGFLOAT_MAX;
}

- (void)setCurrentPositionX:(CGFloat)positionX
{
    [self loadUserDefaults:NO];
    [_userDefaults setObject:[NSNumber numberWithDouble:positionX] forKey:HUDUserDefaultsKeyCurrentPositionX];
    [self saveUserDefaults];
}

- (CGFloat)currentLandscapePositionX
{
    [self loadUserDefaults:NO];
    NSNumber *positionX = [_userDefaults objectForKey:HUDUserDefaultsKeyCurrentLandscapePositionX];
    return positionX != nil ? [positionX doubleValue] : CGFLOAT_MAX;
}

- (void)setCurrentLandscapePositionX:(CGFloat)positionX
{
    [self loadUserDefaults:NO];
    [_userDefaults setObject:[NSNumber numberWithDouble:positionX] forKey:HUDUserDefaultsKeyCurrentLandscapePositionX];
    [self saveUserDefaults];
}

#if !NO_TROLL
- (BOOL)usesCustomFontSize { return [GetStandardUserDefaults() boolForKey:HUDUserDefaultsKeyUsesCustomFontSize]; }
- (CGFloat)realCustomFontSize { return [GetStandardUserDefaults() doubleForKey:HUDUserDefaultsKeyRealCustomFontSize]; }
- (BOOL)usesCustomOffset { return [GetStandardUserDefaults() boolForKey:HUDUserDefaultsKeyUsesCustomOffset]; }
- (CGFloat)realCustomOffsetX { return [GetStandardUserDefaults() doubleForKey:HUDUserDefaultsKeyRealCustomOffsetX]; }
- (CGFloat)realCustomOffsetY { return [GetStandardUserDefaults() doubleForKey:HUDUserDefaultsKeyRealCustomOffsetY]; }
#else
- (BOOL)usesCustomFontSize { return NO; }
- (CGFloat)realCustomFontSize { return HUD_FONT_SIZE; }
- (BOOL)usesCustomOffset { return NO; }
- (CGFloat)realCustomOffsetX { return 0; }
- (CGFloat)realCustomOffsetY { return 0; }
#endif

- (instancetype)init
{
    self = [super init];
    if (self) {
        _constraints = [NSMutableArray array];
        [self registerNotifications];
#if !NO_TROLL
        _orientationObserver = [[objc_getClass("FBSOrientationObserver") alloc] init];
        __weak HUDRootViewController *weakSelf = self;
        [_orientationObserver setHandler:^(FBSOrientationUpdate *orientationUpdate) {
            HUDRootViewController *strongSelf = weakSelf;
            dispatch_async(dispatch_get_main_queue(), ^{
                [strongSelf updateOrientation:(UIInterfaceOrientation)orientationUpdate.orientation animateWithDuration:orientationUpdate.duration];
            });
        }];
#endif
    }
    return self;
}

- (void)dealloc
{
    @try {
        [gQuotaStore persistIfNeeded:YES];
    } @catch (__unused NSException *exception) {
    }
#if !NO_TROLL
    [_orientationObserver invalidate];
#endif
}

- (void)updateSpeedLabel
{
    log_debug(OS_LOG_DEFAULT, "updateSpeedLabel");

    /* Quota bookkeeping must never be able to take the whole HUD down: if anything
       in there throws, the speed label simply keeps working without the tank. */
    @try {
        static NSTimeInterval lastNetworkRefreshTime = 0;
        NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
        if ((now - lastNetworkRefreshTime) > 3.0) {
            lastNetworkRefreshTime = now;
            [gQuotaStore refreshNetworkContext];
        }

        [gQuotaStore accumulateSeparatedBytes:getSeparatedBytes()];
        [gQuotaStore persistIfNeeded:NO];
        [self updateQuotaLiquidView];
    } @catch (__unused NSException *exception) {
        _quotaLiquidView.hidden = YES;
    }

    NSAttributedString *attributedText = formattedDisplayAttributedString(_isFocused);
    if (attributedText) {
        [_speedLabel setAttributedText:attributedText];
    }
    [_speedLabel sizeToFit];
}

- (void)updateQuotaLiquidView
{
    BOOL usable = [gQuotaStore activeHasQuota];
    if (!usable) {
        if (!_quotaLiquidView.hidden) {
            _quotaLiquidView.hidden = YES;
        }
        return;
    }

    double fraction = [gQuotaStore activeRemainingFraction];
    [_quotaLiquidView setLevel:fraction animated:YES];

    if (_quotaLiquidView.hidden) {
        /* Snap to the current level before revealing, so it does not animate from empty */
        [_quotaLiquidView setLevel:fraction animated:NO];
        _quotaLiquidView.hidden = NO;
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    /* Just put your HUD view here */

    _contentView = [[UIView alloc] init];
    _contentView.backgroundColor = [UIColor clearColor];
    _contentView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_contentView];

    _blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    _blurView = [[UIVisualEffectView alloc] initWithEffect:_blurEffect];
    _blurView.layer.cornerRadius = HUD_MIN_CORNER_RADIUS;
    _blurView.layer.masksToBounds = YES;
    _blurView.translatesAutoresizingMaskIntoConstraints = NO;
    _containerView = [[ScreenshotInvisibleContainer alloc] initWithContent:_blurView];
    _containerView.hiddenContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [_contentView addSubview:_containerView.hiddenContainer];

    _speedLabel = [[HUDBackdropLabel alloc] initWithFrame:CGRectZero];
    _speedLabel.numberOfLines = 0;
    _speedLabel.textAlignment = NSTextAlignmentCenter;
    _speedLabel.textColor = [UIColor whiteColor];
    _speedLabel.font = [UIFont systemFontOfSize:HUD_FONT_SIZE];
    _speedLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [_speedLabel setContentHuggingPriority:UILayoutPriorityDefaultHigh forAxis:UILayoutConstraintAxisVertical];
    [_blurView.contentView addSubview:_speedLabel];

    /* Data quota liquid tank, drawn behind the speed label */
    gQuotaStore = [[HUDQuotaStore alloc] init];
    [gQuotaStore reload];

    _quotaLiquidView = [[HUDQuotaLiquidView alloc] initWithFrame:CGRectZero];
    _quotaLiquidView.translatesAutoresizingMaskIntoConstraints = NO;
    _quotaLiquidView.hidden = YES;
    [_blurView.contentView insertSubview:_quotaLiquidView atIndex:0];

    _lockedView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"lock.fill"]];
    _lockedView.tintColor = [UIColor whiteColor];
    _lockedView.translatesAutoresizingMaskIntoConstraints = NO;
    _lockedView.contentMode = UIViewContentModeScaleAspectFit;
    _lockedView.alpha = 0.0;
    [_lockedView setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisVertical];
    [_lockedView setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisVertical];
    [_blurView.contentView addSubview:_lockedView];

    _tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapGestureRecognized:)];
    _tapGestureRecognizer.numberOfTapsRequired = 1;
    _tapGestureRecognizer.numberOfTouchesRequired = 1;
    [_contentView addGestureRecognizer:_tapGestureRecognizer];

    _panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panGestureRecognized:)];
    _panGestureRecognizer.minimumNumberOfTouches = 1;
    _panGestureRecognizer.maximumNumberOfTouches = 1;
    [_contentView addGestureRecognizer:_panGestureRecognizer];

    [_contentView setUserInteractionEnabled:YES];

    [self reloadUserDefaults];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    notify_post(NOTIFY_LAUNCHED_HUD);
}

- (void)resetLoopTimer
{
    [_timer invalidate];
    _timer = [NSTimer scheduledTimerWithTimeInterval:UPDATE_INTERVAL target:self selector:@selector(updateSpeedLabel) userInfo:nil repeats:YES];
}

- (void)stopLoopTimer
{
    [_timer invalidate];
    _timer = nil;
}

- (void)viewSafeAreaInsetsDidChange
{
    [super viewSafeAreaInsetsDidChange];
    [self removeAllAnimations];
    [self resetGestureRecognizers];
    [self updateViewConstraints];
}

- (void)updateViewConstraints
{
    [NSLayoutConstraint deactivateConstraints:_constraints];
    [_constraints removeAllObjects];

#if NO_TROLL
    _orientation = [self.view.window.windowScene interfaceOrientation];
#endif

    BOOL isLandscape;
    if (_orientation == UIInterfaceOrientationUnknown) {
        isLandscape = CGRectGetWidth(self.view.bounds) > CGRectGetHeight(self.view.bounds);
    } else {
        isLandscape = UIInterfaceOrientationIsLandscape(_orientation);
    }

    HUDPresetPosition selectedMode = [self selectedModeForCurrentOrientation];
    BOOL isCentered = (selectedMode == HUDPresetPositionTopCenter || selectedMode == HUDPresetPositionTopCenterMost);
    BOOL isCenteredMost = (selectedMode == HUDPresetPositionTopCenterMost);
    BOOL isPad = ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad);

    HUD_SHOW_DOWNLOAD_SPEED_FIRST = isCentered;
    HUD_SHOW_SECOND_SPEED_IN_NEW_LINE = !isCentered;
    [_speedLabel setTextAlignment:(isCentered ? NSTextAlignmentCenter : NSTextAlignmentLeft)];
    [_lockedView setImage:[UIImage systemImageNamed:(isCentered ? @"hand.raised.slash.fill" : @"lock.fill")]];
    [_blurView.layer setMaskedCorners:((isCenteredMost && !isLandscape) ? kCornerMaskBottom : kCornerMaskAll)];

    BOOL usesCustomOffset = [self usesCustomOffset];
    CGFloat realCustomOffsetX = 0;
    CGFloat realCustomOffsetY = 0;

    if (usesCustomOffset)
    {
        realCustomOffsetX = [self realCustomOffsetX];
        realCustomOffsetY = [self realCustomOffsetY];
    }

    UILayoutGuide *layoutGuide = self.view.safeAreaLayoutGuide;
    if (isLandscape)
    {
        CGFloat notchHeight;
        CGFloat paddingNearNotch;
        CGFloat paddingFarFromNotch;

#if !NO_TROLL
        notchHeight = CGRectGetMinY(layoutGuide.layoutFrame);
        paddingNearNotch = (notchHeight > 30) ? notchHeight - 16 : 4;
        paddingFarFromNotch = (notchHeight > 30) ? -24 : -4;
#else
        notchHeight = CGRectGetMinX(layoutGuide.layoutFrame);
        paddingNearNotch = (notchHeight > 30) ? -16 : 4;
        paddingFarFromNotch = (notchHeight > 30) ? notchHeight - 24 : -4;
#endif

        paddingNearNotch += realCustomOffsetX;
        paddingFarFromNotch += realCustomOffsetX;

        [_constraints addObjectsFromArray:@[
            [_contentView.leadingAnchor constraintEqualToAnchor:layoutGuide.leadingAnchor constant:(_orientation == UIInterfaceOrientationLandscapeLeft ? -paddingFarFromNotch : paddingNearNotch)],
            [_contentView.trailingAnchor constraintEqualToAnchor:layoutGuide.trailingAnchor constant:(_orientation == UIInterfaceOrientationLandscapeLeft ? -paddingNearNotch : paddingFarFromNotch)],
        ]];

        CGFloat minimumLandscapeTopConstant = 0;
        CGFloat minimumLandscapeBottomConstant = 0;

        minimumLandscapeTopConstant = (isPad ? 30 : 10);
        minimumLandscapeBottomConstant = (isPad ? -34 : -14);

        minimumLandscapeTopConstant += realCustomOffsetY;
        minimumLandscapeBottomConstant += realCustomOffsetY;

        /* Fixed Constraints */
        [_constraints addObjectsFromArray:@[
            [_contentView.topAnchor constraintGreaterThanOrEqualToAnchor:self.view.topAnchor constant:minimumLandscapeTopConstant],
            [_contentView.bottomAnchor constraintLessThanOrEqualToAnchor:self.view.bottomAnchor constant:minimumLandscapeBottomConstant],
        ]];

        /* Flexible Constraint */
        _topConstraint = [_contentView.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:minimumLandscapeTopConstant];
        if (!isCentered) {
            CGFloat currentPositionY = [self currentLandscapePositionY];
            if (currentPositionY < CGFLOAT_MAX) {
                _topConstraint.constant = currentPositionY;
            }
        }
        _topConstraint.priority = UILayoutPriorityDefaultLow;

        [_constraints addObject:_topConstraint];
    }
    else
    {
        [_constraints addObjectsFromArray:@[
            [_contentView.leadingAnchor constraintEqualToAnchor:layoutGuide.leadingAnchor constant:realCustomOffsetX],
            [_contentView.trailingAnchor constraintEqualToAnchor:layoutGuide.trailingAnchor constant:realCustomOffsetX],
        ]];

        if (isCenteredMost && !isPad) {
            [_constraints addObject:[_contentView.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:0]];
        }
        else
        {
            CGFloat minimumTopConstraintConstant = 0;
            CGFloat minimumBottomConstraintConstant = 0;

            if (CGRectGetMinY(layoutGuide.layoutFrame) >= 51) {
                minimumTopConstraintConstant = -8;
                minimumBottomConstraintConstant = -4;
            }
            else if (CGRectGetMinY(layoutGuide.layoutFrame) > 30) {
                minimumTopConstraintConstant = -12;
                minimumBottomConstraintConstant = -4;
            } else {
#if !NO_TROLL
                minimumTopConstraintConstant = (isPad ? 30 : 20);
                minimumBottomConstraintConstant = -20;
#else
                minimumTopConstraintConstant = (isPad ? 10 : 0);
                minimumBottomConstraintConstant = -20;
#endif
            }

            minimumTopConstraintConstant += realCustomOffsetY;
            minimumBottomConstraintConstant += realCustomOffsetY;

            /* Fixed Constraints */
            [_constraints addObjectsFromArray:@[
                [_contentView.topAnchor constraintGreaterThanOrEqualToAnchor:layoutGuide.topAnchor constant:minimumTopConstraintConstant],
                [_contentView.bottomAnchor constraintLessThanOrEqualToAnchor:layoutGuide.bottomAnchor constant:minimumBottomConstraintConstant],
            ]];

            /* Flexible Constraint */
            _topConstraint = [_contentView.topAnchor constraintEqualToAnchor:layoutGuide.topAnchor constant:minimumTopConstraintConstant];
            if (!isCentered) {
                CGFloat currentPositionY = [self currentPositionY];
                if (currentPositionY < CGFLOAT_MAX) {
                    _topConstraint.constant = currentPositionY;
                }
            }
            _topConstraint.priority = UILayoutPriorityDefaultLow;

            [_constraints addObject:_topConstraint];
        }
    }

    [_constraints addObjectsFromArray:@[
        [_speedLabel.topAnchor constraintEqualToAnchor:_contentView.topAnchor],
        [_speedLabel.bottomAnchor constraintEqualToAnchor:_contentView.bottomAnchor],
    ]];

    _centerXConstraint = [_speedLabel.centerXAnchor constraintEqualToAnchor:layoutGuide.centerXAnchor];
    if (isCentered) {
        [_constraints addObject:_centerXConstraint];
    }

    _leadingConstraint = [_speedLabel.leadingAnchor constraintEqualToAnchor:_contentView.leadingAnchor constant:10];
    if (selectedMode == HUDPresetPositionTopLeft) {
        [_constraints addObject:_leadingConstraint];
    } else if (selectedMode == HUDPresetPositionFree) {
        CGFloat currentPositionX = (isLandscape ? [self currentLandscapePositionX] : [self currentPositionX]);
        if (currentPositionX < CGFLOAT_MAX && isfinite((double)currentPositionX)) {
            /* Never trust a stored X blindly: a value left over from another screen
               size (or a bad drag) can park the capsule completely off-screen, which
               looks exactly like "the HUD disappeared". */
            CGFloat screenWidth = CGRectGetWidth(self.view.bounds);
            if (screenWidth < 1) {
                screenWidth = CGRectGetWidth([UIScreen mainScreen].bounds);
            }
            CGFloat maxX = MAX(screenWidth - 80, 4);
            _leadingConstraint.constant = MIN(MAX(currentPositionX, 4), maxX);
        }
        [_constraints addObject:_leadingConstraint];
    }

    _trailingConstraint = [_speedLabel.trailingAnchor constraintEqualToAnchor:_contentView.trailingAnchor constant:-10];
    if (selectedMode == HUDPresetPositionTopRight) {
        [_constraints addObject:_trailingConstraint];
    }

    [_constraints addObjectsFromArray:@[
        [_blurView.topAnchor constraintEqualToAnchor:_speedLabel.topAnchor constant:-2],
        [_blurView.leadingAnchor constraintEqualToAnchor:_speedLabel.leadingAnchor constant:-4],
        [_blurView.trailingAnchor constraintEqualToAnchor:_speedLabel.trailingAnchor constant:4],
        [_blurView.bottomAnchor constraintEqualToAnchor:_speedLabel.bottomAnchor constant:2],
    ]];

    [_constraints addObjectsFromArray:@[
        [_quotaLiquidView.topAnchor constraintEqualToAnchor:_blurView.contentView.topAnchor],
        [_quotaLiquidView.leadingAnchor constraintEqualToAnchor:_blurView.contentView.leadingAnchor],
        [_quotaLiquidView.trailingAnchor constraintEqualToAnchor:_blurView.contentView.trailingAnchor],
        [_quotaLiquidView.bottomAnchor constraintEqualToAnchor:_blurView.contentView.bottomAnchor],
    ]];

    [_constraints addObjectsFromArray:@[
        [_lockedView.topAnchor constraintGreaterThanOrEqualToAnchor:_blurView.topAnchor constant:2],
        [_lockedView.centerXAnchor constraintEqualToAnchor:_blurView.centerXAnchor],
        [_lockedView.centerYAnchor constraintEqualToAnchor:_blurView.centerYAnchor],
    ]];

    [NSLayoutConstraint activateConstraints:_constraints];
    [super updateViewConstraints];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];

    /* Second safety net for free positioning: if the capsule still ends up past the
       right edge after layout (screen size change, rotation, stale stored X), pull it
       back on screen instead of letting it vanish. */
    HUDPresetPosition mode = [self selectedModeForCurrentOrientation];
    if (mode == HUDPresetPositionFree && _leadingConstraint) {
        CGFloat width = CGRectGetWidth(self.view.bounds);
        CGFloat labelWidth = CGRectGetWidth(_speedLabel.frame);
        CGFloat maxX = width - labelWidth - 4;
        if (maxX < 4) {
            maxX = 4;
        }
        if (_leadingConstraint.constant > maxX) {
            _leadingConstraint.constant = maxX;
        }
    }
}

- (void)keepFocus:(UIView *)view
{
    [self onFocus:view duration:0];
}

- (void)onFocus:(UIView *)view
{
    [self onFocus:view duration:0.2];
}

- (void)onFocus:(UIView *)view duration:(NSTimeInterval)duration
{
    [self onFocus:view scaleFactor:0.1 duration:duration beginFromInitialState:YES blurWhenDone:YES];
}

- (void)onFocus:(UIView *)view scaleFactor:(CGFloat)scaleFactor duration:(NSTimeInterval)duration beginFromInitialState:(BOOL)beginFromInitialState blurWhenDone:(BOOL)blurWhenDone
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(onBlur:) object:view];
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(onFocus:) object:view];
    
    _isFocused = YES;
    [self updateSpeedLabel];
    [self resetLoopTimer];

    HUDPresetPosition selectedMode = [self selectedModeForCurrentOrientation];
    BOOL isCentered = (selectedMode == HUDPresetPositionTopCenter || selectedMode == HUDPresetPositionTopCenterMost);
    
    CGFloat topTrans = CGRectGetHeight(view.bounds) * (scaleFactor / 2);
    CGFloat leadingTrans = (isCentered ? 0 : (selectedMode == HUDPresetPositionTopLeft ? CGRectGetWidth(view.bounds) * (scaleFactor / 2) : -CGRectGetWidth(view.bounds) * (scaleFactor / 2)));

    if (beginFromInitialState)
        [view setTransform:CGAffineTransformIdentity];
    
    [UIView animateWithDuration:duration delay:0.0 usingSpringWithDamping:1.0 initialSpringVelocity:1.0 options:UIViewAnimationOptionCurveEaseIn | UIViewAnimationOptionBeginFromCurrentState animations:^{
        if (ABS(leadingTrans) > 1e-6 || ABS(topTrans) > 1e-6)
        {
            CGAffineTransform transform = CGAffineTransformMakeTranslation(leadingTrans, topTrans);
            view.transform = CGAffineTransformScale(transform, 1.0 + scaleFactor, 1.0 + scaleFactor);
        }

        view.alpha = 1.0;
    } completion:^(BOOL finished) {
        if (blurWhenDone) {
            [self performSelector:@selector(onBlur:) withObject:view afterDelay:IDLE_INTERVAL];
        }
    }];
}

- (void)onBlur:(UIView *)view
{
    [self onBlur:view duration:0.6];
}

- (void)onBlur:(UIView *)view duration:(NSTimeInterval)duration
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(onBlur:) object:view];
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(onFocus:) object:view];
    
    _isFocused = NO;
    [self updateSpeedLabel];
    [self resetLoopTimer];

    [UIView animateWithDuration:duration delay:0.0 usingSpringWithDamping:1.0 initialSpringVelocity:1.0 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState animations:^{
        view.transform = CGAffineTransformIdentity;
        view.alpha = HUD_INACTIVE_OPACITY;
    } completion:nil];
}

- (void)removeAllAnimations
{
    [_contentView.layer removeAllAnimations];
}

- (void)resetGestureRecognizers
{
    for (UIGestureRecognizer *recognizer in _contentView.gestureRecognizers)
    {
        [recognizer setEnabled:NO];
        [recognizer setEnabled:YES];
    }
}

- (void)tapGestureRecognized:(UITapGestureRecognizer *)sender
{
    log_info(OS_LOG_DEFAULT, "TAPPED");
    if (!_isFocused) {
        [self onFocus:sender.view];
    } else {
        [self keepFocus:sender.view];
    }
}

- (void)cancelPreviousPerformRequestsWithTarget:(UIView *)view
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(onBlur:) object:view];
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(onFocus:) object:view];
}

- (void)flashLockedViewWithDuration:(NSTimeInterval)duration
{
    [_lockedView.layer removeAllAnimations];
    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"opacity"];
    animation.fromValue = [NSNumber numberWithFloat:0.0];
    animation.toValue = [NSNumber numberWithFloat:1.0];
    animation.duration = duration;
    animation.autoreverses = YES;
    animation.repeatCount = 1;
    animation.removedOnCompletion = YES;
    animation.fillMode = kCAFillModeForwards;
    animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [_lockedView.layer addAnimation:animation forKey:@"opacity"];

    [_speedLabel.layer removeAllAnimations];
    CABasicAnimation *animationReverse = [CABasicAnimation animationWithKeyPath:@"opacity"];
    animationReverse.fromValue = [NSNumber numberWithFloat:1.0];
    animationReverse.toValue = [NSNumber numberWithFloat:0.0];
    animationReverse.duration = duration;
    animationReverse.autoreverses = YES;
    animationReverse.repeatCount = 1;
    animationReverse.removedOnCompletion = YES;
    animationReverse.fillMode = kCAFillModeForwards;
    animationReverse.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [_speedLabel.layer addAnimation:animationReverse forKey:@"opacity"];
}

- (void)panGestureRecognized:(UIPanGestureRecognizer *)sender
{
    if (!_isFocused)
        return;

    HUDPresetPosition selectedMode = [self selectedModeForCurrentOrientation];
    BOOL isCentered = (selectedMode == HUDPresetPositionTopCenter || selectedMode == HUDPresetPositionTopCenterMost);

    if (isCentered || [self keepInPlace])
    {
        if (sender.state == UIGestureRecognizerStateBegan)
            [self cancelPreviousPerformRequestsWithTarget:sender.view];
        else if (sender.state == UIGestureRecognizerStateFailed || sender.state == UIGestureRecognizerStateEnded || sender.state == UIGestureRecognizerStateCancelled)
            [self performSelector:@selector(onBlur:) withObject:sender.view afterDelay:IDLE_INTERVAL];

        if (sender.state == UIGestureRecognizerStateBegan)
        {
            if (!_notificationFeedbackGenerator)
                _notificationFeedbackGenerator = [[UINotificationFeedbackGenerator alloc] init];
            
            [_notificationFeedbackGenerator prepare];
            [_notificationFeedbackGenerator notificationOccurred:UINotificationFeedbackTypeError];

            [self flashLockedViewWithDuration:0.2];
        }

        return;
    }

    static CGFloat beginConstantY = 0.0;
    static CGFloat beginConstantX = 0.0;
    if (sender.state == UIGestureRecognizerStatePossible || sender.state == UIGestureRecognizerStateBegan)
    {
        beginConstantY = _topConstraint.constant;
        beginConstantX = _leadingConstraint.constant;
        [self onFocus:sender.view scaleFactor:0.2 duration:0.1 beginFromInitialState:NO blurWhenDone:NO];
    }
    else
    {
        if (sender.state == UIGestureRecognizerStateChanged || sender.state == UIGestureRecognizerStateEnded)
        {
            CGPoint translation = [sender translationInView:sender.view.superview];
            [_topConstraint setConstant:beginConstantY + translation.y];
            if (selectedMode == HUDPresetPositionFree)
            {
                CGFloat maxX = MAX(CGRectGetWidth(_contentView.bounds) - 24, 4);
                [_leadingConstraint setConstant:MIN(MAX(beginConstantX + translation.x, 4), maxX)];
            }
        }

        if (sender.state == UIGestureRecognizerStateEnded)
        {
            if (UIInterfaceOrientationIsLandscape(_orientation))
            {
                [self setCurrentLandscapePositionY:_topConstraint.constant];
                [self setCurrentLandscapePositionX:_leadingConstraint.constant];
            }
            else
            {
                [self setCurrentPositionY:_topConstraint.constant];
                [self setCurrentPositionX:_leadingConstraint.constant];
            }
        }

        if (sender.state != UIGestureRecognizerStateChanged)
        {
            [self onFocus:sender.view scaleFactor:0.1 duration:0.1 beginFromInitialState:NO blurWhenDone:NO];
            [self reloadUserDefaults];
        }
    }

    if (!_impactFeedbackGenerator)
    {
        _impactFeedbackGenerator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    }

    if (sender.state == UIGestureRecognizerStateBegan || sender.state == UIGestureRecognizerStateEnded || sender.state == UIGestureRecognizerStateCancelled)
    {
        [_impactFeedbackGenerator prepare];
        [_impactFeedbackGenerator impactOccurred];
    }
}

@end

#if !NO_TROLL
@implementation HUDRootViewController (Troll)

static inline CGFloat orientationAngle(UIInterfaceOrientation orientation)
{
    switch (orientation) {
        case UIInterfaceOrientationPortraitUpsideDown:
            return M_PI;
        case UIInterfaceOrientationLandscapeLeft:
            return -M_PI_2;
        case UIInterfaceOrientationLandscapeRight:
            return M_PI_2;
        default:
            return 0;
    }
}

static inline CGRect orientationBounds(UIInterfaceOrientation orientation, CGRect bounds)
{
    switch (orientation) {
        case UIInterfaceOrientationLandscapeLeft:
        case UIInterfaceOrientationLandscapeRight:
            return CGRectMake(0, 0, bounds.size.height, bounds.size.width);
        default:
            return bounds;
    }
}

- (void)updateOrientation:(UIInterfaceOrientation)orientation animateWithDuration:(NSTimeInterval)duration
{
    BOOL usesRotation = [self usesRotation];

    if (!usesRotation)
    {
        [self onBlur:_contentView duration:0];

        if (orientation == UIInterfaceOrientationPortrait)
        {
            __weak typeof(self) weakSelf = self;
            [UIView animateWithDuration:duration animations:^{
                __strong typeof(weakSelf) strongSelf = weakSelf;
                strongSelf->_contentView.alpha = strongSelf->_isFocused ? 1.0 : HUD_INACTIVE_OPACITY;
            }];
        }
        else
        {
            __weak typeof(self) weakSelf = self;
            [UIView animateWithDuration:duration animations:^{
                __strong typeof(weakSelf) strongSelf = weakSelf;
                strongSelf->_contentView.alpha = 0.0;
            }];
        }

        return;
    }

    if (orientation == _orientation) {
        return;
    }

    _orientation = orientation;
    [self cancelPreviousPerformRequestsWithTarget:_contentView];

    CGRect bounds = orientationBounds(orientation, [UIScreen mainScreen].bounds);
    [self.view setNeedsUpdateConstraints];
    [self.view setHidden:YES];
    [self.view setBounds:bounds];

    [self resetGestureRecognizers];
    [self onBlur:_contentView duration:duration];

    __weak typeof(self) weakSelf = self;
    [UIView animateWithDuration:duration animations:^{
        [weakSelf.view setTransform:CGAffineTransformMakeRotation(orientationAngle(orientation))];
    } completion:^(BOOL finished) {
        [weakSelf.view setHidden:NO];
    }];
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskPortrait;
}

@end
#else
@implementation HUDRootViewController (NoTroll)

- (UIModalPresentationStyle)modalPresentationStyle { return UIModalPresentationOverFullScreen; }
- (UIModalTransitionStyle)modalTransitionStyle { return UIModalTransitionStyleCrossDissolve; }

- (void)viewWillTransitionToSize:(CGSize)size
       withTransitionCoordinator:(id <UIViewControllerTransitionCoordinator>)coordinator
{
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];

    BOOL usesRotation = [self usesRotation];
    __weak typeof(self) weakSelf = self;
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> _Nonnull context)
     {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        UIInterfaceOrientation orientation = [strongSelf.view.window.windowScene interfaceOrientation];

        if (!usesRotation)
        {
            [strongSelf onBlur:strongSelf->_contentView duration:0];

            if (orientation == UIInterfaceOrientationPortrait) {
                strongSelf->_contentView.alpha = strongSelf->_isFocused ? 1.0 : HUD_INACTIVE_OPACITY;
            } else {
                strongSelf->_contentView.alpha = 0.0;
            }
        }
        else
        {
            [strongSelf cancelPreviousPerformRequestsWithTarget:strongSelf->_contentView];

            [strongSelf.view setNeedsUpdateConstraints];
            [strongSelf.view setHidden:YES];

            [strongSelf resetGestureRecognizers];
            [strongSelf onBlur:strongSelf->_contentView duration:context.transitionDuration];
        }
    } completion:^(id<UIViewControllerTransitionCoordinatorContext> _Nonnull context)
     {
        if (usesRotation)
        {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            [strongSelf.view setHidden:NO];
        }
    }];
}

@end
#endif
