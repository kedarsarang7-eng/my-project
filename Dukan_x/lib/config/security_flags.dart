/// Authorized Google email for owner access. Override via
/// `--dart-define=OWNER_GOOGLE_EMAIL=owner@domain.com` for production builds.
const String kOwnerGoogleEmail = String.fromEnvironment(
  'OWNER_GOOGLE_EMAIL',
  defaultValue: 'owner@example.com',
);
