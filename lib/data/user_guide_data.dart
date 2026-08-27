class GuideItem {
  final String id;
  final String title;
  final String summary;
  final String whyItMatters;
  final String howToUse;
  final List<String> keyRules;
  final String versionAdded;

  const GuideItem({
    required this.id,
    required this.title,
    required this.summary,
    required this.whyItMatters,
    required this.howToUse,
    required this.keyRules,
    required this.versionAdded,
  });
}

class GuideSection {
  final String categoryTitle;
  final String iconName; // e.g., 'shield', 'timer', 'people', 'sos', 'pin', 'trash'
  final List<GuideItem> items;

  const GuideSection({
    required this.categoryTitle,
    required this.iconName,
    required this.items,
  });
}

class UserGuideRegistry {
  static const List<GuideSection> sections = [
    GuideSection(
      categoryTitle: 'Privacy & Permissions',
      iconName: 'shield',
      items: [
        GuideItem(
          id: 'directional_permissions',
          title: 'Directional Location Permissions',
          summary: 'Location sharing in TrackMate is strictly directional and zero-trust.',
          whyItMatters:
              'Being connected with a friend never automatically exposes your location. You retain unilateral control over who sees your coordinates.',
          howToUse:
              'Open the Connections screen or tap a friend pin to toggle location sharing permissions on or off individually for each friend.',
          keyRules: [
            'Connection does not equal location permission.',
            'Toggling a friend off instantly revokes their real-time coordinate stream.',
            'Reverse access is completely independent.'
          ],
          versionAdded: 'v1.0.0',
        ),
        GuideItem(
          id: 'instant_revocation',
          title: 'Instant Coordinate Revocation',
          summary: 'Terminating permission severs telemetry in real-time.',
          whyItMatters:
              'If you revoke access, peer devices immediately clear your marker and distance without relying on app restarts.',
          howToUse:
              'Toggle off the sharing switch next to any friend in the Friends list.',
          keyRules: [
            'Real-time listener removes coordinates immediately.',
            'Cached positions are discarded on the peer device.'
          ],
          versionAdded: 'v1.0.0',
        ),
      ],
    ),
    GuideSection(
      categoryTitle: 'Timed & Live Location',
      iconName: 'timer',
      items: [
        GuideItem(
          id: 'timed_duration_presets',
          title: 'Timed Sharing Sessions',
          summary: 'Share your live location for a predetermined window with automatic teardown.',
          whyItMatters:
              'Prevents accidentally leaving background location sharing active all day when meeting up for short intervals.',
          howToUse:
              'Tap "Share Location" on the map and choose 30 Minutes, 1 Hour, 2 Hours, a Custom Time, or Indefinite.',
          keyRules: [
            'Sessions automatically stop when time expires.',
            'Zero-trust reader gates hide expired pins on friend devices.',
            'Cold-start recovery cleans up expired sessions automatically.'
          ],
          versionAdded: 'v1.4.0',
        ),
        GuideItem(
          id: 'active_sharing_hud',
          title: 'Active Countdown HUD Chip',
          summary: 'Floating live badge on the map with dynamic countdown and one-tap Stop.',
          whyItMatters:
              'Gives you instant visual feedback on your active broadcast status and remaining minutes.',
          howToUse:
              'View the floating chip at the top of the map. Tap the red "Stop" button at any time to end sharing immediately.',
          keyRules: [
            'Pulsing green indicator for indefinite sessions.',
            'Pulsing gold countdown chip for timed sessions.',
            'Displays active connection count.'
          ],
          versionAdded: 'v1.4.0',
        ),
        GuideItem(
          id: 'screen_off_retention',
          title: 'Screen-Off Retention & Heartbeat',
          summary: 'Maintains live telemetry and prevents "Signal Lost" warnings when the screen is locked.',
          whyItMatters:
              'Android Doze mode and stationary GPS filters normally pause updates. TrackMate dispatches a periodic 35s heartbeat to keep your connection alive.',
          howToUse:
              'Allow "Ignore Battery Optimization" when prompted. Lock your phone and background tracking will continue seamlessly.',
          keyRules: [
            '35-second stationary heartbeat prevents stale disconnects.',
            'Foreground notification remains visible while active.',
            'Dismisses automatically on session expiration.'
          ],
          versionAdded: 'v1.4.1',
        ),
      ],
    ),
    GuideSection(
      categoryTitle: 'Groups & Collaboration',
      iconName: 'people',
      items: [
        GuideItem(
          id: 'group_live_tracking',
          title: 'Group Live Tracking Sessions',
          summary: 'Coordinate with multiple team members or family in dedicated group rooms.',
          whyItMatters:
              'View all active group participants on a single map canvas with real-time distance and travel mode indicators.',
          howToUse:
              'Navigate to the Groups tab, select a group, and start or join an active location session.',
          keyRules: [
            'Only group members can observe session coordinates.',
            'Admin transfers automatically if creator departs.'
          ],
          versionAdded: 'v1.2.0',
        ),
      ],
    ),
    GuideSection(
      categoryTitle: 'Geofencing & Alerts',
      iconName: 'pin',
      items: [
        GuideItem(
          id: 'geofence_zones',
          title: 'Custom Safe Zones & Geofences',
          summary: 'Define circular geographic perimeters and receive entry/exit notifications.',
          whyItMatters:
              'Stay notified when family members arrive safely at school, work, or home.',
          howToUse:
              'Open Geofences from the drawer/menu, tap "+ Create Zone", select radius and coordinates, and set alert triggers.',
          keyRules: [
            'Evaluates distance locally with minimal battery consumption.',
            'Triggers local push notifications upon boundary transition.'
          ],
          versionAdded: 'v1.1.0',
        ),
      ],
    ),
    GuideSection(
      categoryTitle: 'Emergency SOS',
      iconName: 'sos',
      items: [
        GuideItem(
          id: 'emergency_sos_trigger',
          title: '3-Second Hold Emergency SOS',
          summary: 'Broadcast instant emergency distress signal with high-precision GPS coordinates.',
          whyItMatters:
              'Provides immediate safety alerting to all connected friends and designated emergency contacts with haptic confirmation.',
          howToUse:
              'Press and hold the red SOS button on the map for 3 seconds until the circular progress indicator fills completely.',
          keyRules: [
            '3-second hold prevents accidental activation.',
            'Broadcasts emergency payload immediately across Realtime Database.',
            'Can be resolved or dismissed from the active alert banner.'
          ],
          versionAdded: 'v1.0.0',
        ),
      ],
    ),
    GuideSection(
      categoryTitle: 'Account & Data Purge',
      iconName: 'trash',
      items: [
        GuideItem(
          id: 'atomic_account_deletion',
          title: 'Atomic Account Deletion & Right-to-be-Forgotten',
          summary: 'Permanently purge all account data, coordinates, permissions, and groups in one step.',
          whyItMatters:
              'Ensures zero orphaned data, releases your username, and wipes all historical coordinates atomically.',
          howToUse:
              'Go to Profile -> Delete Account, enter your account password for re-authentication, and confirm.',
          keyRules: [
            'Requires password re-authentication.',
            'Atomically unlinks connections and transfers group ownership.',
            'Irreversible and permanent.'
          ],
          versionAdded: 'v1.3.0',
        ),
      ],
    ),
  ];
}
