/// Maps raw Supabase / network / Dart exceptions to short user-facing text.
/// Never show stack traces or PostgREST JSON blobs in the UI.
String friendlyError(Object error, {String fallback = 'Something went wrong. Try again.'}) {
  final s = error.toString();

  // Auth
  if (s.contains('Invalid login credentials') ||
      s.contains('invalid_credentials')) {
    return 'Email or password is incorrect.';
  }
  if (s.contains('Email not confirmed') || s.contains('Email not confirmed')) {
    return 'Confirm your email first (check inbox and spam).';
  }
  if (s.contains('User already registered')) {
    return 'An account with this email already exists. Sign in instead.';
  }
  if (s.contains('Password should be at least') ||
      s.contains('password') && s.contains('at least')) {
    return 'Password must be at least 8 characters.';
  }
  if (s.contains('JWT') || s.contains('session') && s.contains('expired')) {
    return 'Your session expired. Sign in again.';
  }

  // Network
  if (s.contains('SocketException') ||
      s.contains('Failed host lookup') ||
      s.contains('Network is unreachable') ||
      s.contains('ClientException')) {
    return 'Network problem. Check your connection and try again.';
  }
  if (s.contains('TimeoutException') || s.contains('timed out')) {
    return 'Request timed out. Try again.';
  }

  // Postgres / PostgREST
  if (s.contains('duplicate key') ||
      s.contains('unique constraint') ||
      s.contains('23505')) {
    return 'That value is already in use. Choose another.';
  }
  if (s.contains('foreign key') || s.contains('23503')) {
    return 'Related record is missing or was removed.';
  }
  if (s.contains('row-level security') ||
      s.contains('RLS') ||
      s.contains('42501') ||
      s.contains('permission denied')) {
    return 'You do not have permission for this action.';
  }
  if (s.contains('not authorized') || s.contains('not authenticated')) {
    return 'You do not have permission for this action.';
  }

  // Generic cleanup
  var cleaned = s
      .replaceFirst(RegExp(r'^Exception:\s*'), '')
      .replaceFirst(RegExp(r'^AuthException\(message:\s*'), '')
      .replaceFirst(RegExp(r'^PostgrestException\(message:\s*'), '')
      .replaceAll(RegExp(r'\)$'), '')
      .trim();

  if (cleaned.isEmpty || cleaned.length > 180) return fallback;
  return cleaned;
}
