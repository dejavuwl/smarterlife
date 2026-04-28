import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AuthService {
  AuthService(this._auth);

  final FirebaseAuth _auth;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<User> ensureSignedIn() async {
    // Wait for Firebase Auth to fully restore persisted state before checking.
    // Accessing currentUser synchronously right after initializeApp() can return
    // null even if the user was previously signed in, causing a spurious
    // signInAnonymously() call and a PERMISSION_DENIED error from Firestore.
    final user = await _auth.authStateChanges().first;
    if (user != null) return user;
    final credential = await _auth.signInAnonymously();
    return credential.user!;
  }

  Future<void> upgradeAnonymousToEmail({
    required String email,
    required String password,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No signed-in user.');
    }
    final credential =
        EmailAuthProvider.credential(email: email, password: password);
    if (user.isAnonymous) {
      await user.linkWithCredential(credential);
    } else {
      await _auth.signInWithCredential(credential);
    }
  }

  Future<void> upgradeAnonymousToGoogle() async {
    final account = await GoogleSignIn().signIn();
    if (account == null) {
      return;
    }
    final auth = await account.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: auth.accessToken,
      idToken: auth.idToken,
    );
    final user = _auth.currentUser;
    if (user != null && user.isAnonymous) {
      await user.linkWithCredential(credential);
    } else {
      await _auth.signInWithCredential(credential);
    }
  }

  Future<void> upgradeAnonymousToApple() async {
    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [AppleIDAuthorizationScopes.email],
    );
    final oauthCredential = OAuthProvider('apple.com').credential(
      idToken: appleCredential.identityToken,
      accessToken: appleCredential.authorizationCode,
    );
    final user = _auth.currentUser;
    if (user != null && user.isAnonymous) {
      await user.linkWithCredential(oauthCredential);
    } else {
      await _auth.signInWithCredential(oauthCredential);
    }
  }

  Future<dynamic> idToken() async {
    final user = _auth.currentUser ?? await ensureSignedIn();
    return user.getIdToken();
  }
}