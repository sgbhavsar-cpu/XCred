// Mirrors XCred.Core's org-settings shape (returned inline on GET /api/dashboard, per
// DashboardController.cs's OrgSettingsDto). Defaults match the server's own seed
// defaults exactly (src/XCred.Web/src/store/authStore.ts's DEFAULT_ORG_SETTINGS) — this
// is the exact class of hardcoded-default bug fixed in the web app this session
// (session timeout, clipboard-clear, attachment size); mobile must read the real values
// from here, never a literal, per MOB-SESS-03's acceptance criteria.
class OrgSettings {
  final int clipboardClearSeconds;
  final int expiryWarningDays;
  final int sessionTimeoutMinutes;
  final int maxAttachmentSizeMb;

  const OrgSettings({
    required this.clipboardClearSeconds,
    required this.expiryWarningDays,
    required this.sessionTimeoutMinutes,
    required this.maxAttachmentSizeMb,
  });

  static const defaults = OrgSettings(
    clipboardClearSeconds: 30,
    expiryWarningDays: 30,
    sessionTimeoutMinutes: 15,
    maxAttachmentSizeMb: 10,
  );

  factory OrgSettings.fromJson(Map<String, dynamic> json) => OrgSettings(
        clipboardClearSeconds:
            json['clipboardClearSeconds'] as int? ?? defaults.clipboardClearSeconds,
        expiryWarningDays: json['expiryWarningDays'] as int? ?? defaults.expiryWarningDays,
        sessionTimeoutMinutes:
            json['sessionTimeoutMinutes'] as int? ?? defaults.sessionTimeoutMinutes,
        maxAttachmentSizeMb:
            json['maxAttachmentSizeMb'] as int? ?? defaults.maxAttachmentSizeMb,
      );
}
