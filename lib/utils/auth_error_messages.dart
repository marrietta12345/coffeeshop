/// Friendly copy for Firebase Auth error codes — shared by every
/// sign-in/sign-up page so wording stays identical everywhere and only
/// needs updating in one place.

String signInErrorMessage(String code) {
  switch (code) {
    case 'invalid-email':
      return 'That email address looks invalid.';
    case 'user-disabled':
      return 'This account has been disabled.';
    case 'user-not-found':
      return 'No account found with that email.';
    case 'wrong-password':
    case 'invalid-credential':
      return 'Incorrect email or password.';
    case 'too-many-requests':
      return 'Too many attempts. Please try again later.';
    default:
      return 'Sign in failed. Please try again.';
  }
}

String signUpErrorMessage(String code) {
  switch (code) {
    case 'invalid-email':
      return 'That email address looks invalid.';
    case 'email-already-in-use':
      return 'An account already exists for that email.';
    case 'weak-password':
      return 'Please choose a stronger password.';
    case 'operation-not-allowed':
      return 'Email/password sign-up is not enabled.';
    default:
      return 'Sign up failed. Please try again.';
  }
}