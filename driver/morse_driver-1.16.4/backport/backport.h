/*
 * Stub backport/backport.h for native Ubuntu kernel build
 *
 * This file is normally provided by the OpenWrt mac80211 backport system
 * to provide compatibility shims for older kernels.
 *
 * For native Ubuntu kernels (6.8+), we use the kernel's native APIs directly.
 * The driver will use LINUX_VERSION_CODE for version checks since
 * MAC80211_BACKPORT_VERSION_CODE won't be defined.
 */

#ifndef __BACKPORT_H
#define __BACKPORT_H

#include <linux/version.h>
#include <linux/kconfig.h>

/*
 * IEEE80211_CHAN_IGNORE is an OpenWrt-specific flag added to cfg80211 for
 * S1G (802.11ah) support. The standard kernel doesn't have it.
 * We define it as IEEE80211_CHAN_DISABLED since ignored channels are
 * effectively disabled from the driver's perspective.
 */
#ifndef IEEE80211_CHAN_IGNORE
#define IEEE80211_CHAN_IGNORE IEEE80211_CHAN_DISABLED
#endif

#endif /* __BACKPORT_H */
