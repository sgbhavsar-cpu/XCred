import 'api_response.dart';

/// MOB-POLISH-01 — every list screen's `AsyncValue.error` branch was dumping the raw
/// exception (`'Failed to load X: $e'`) straight into the UI regardless of cause —
/// distinguishing "you're offline" from "something actually went wrong server-side" is
/// the one signal `ApiException.code == 'NETWORK_ERROR'` already carries (see
/// api_client.dart), it just wasn't being used for display on screens that don't have
/// an offline cache fallback to fall back to.
String friendlyErrorMessage(Object error) {
  if (error is ApiException && error.code == 'NETWORK_ERROR') {
    return "You're offline. Check your connection and try again.";
  }
  return 'Something went wrong. Please try again.';
}
