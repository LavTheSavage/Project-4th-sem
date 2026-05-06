import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';

class AuthService {
  // Sign in with Facebook
  Future<Map<String, dynamic>?> signInWithFacebook() async {
    try {
      final LoginResult result = await FacebookAuth.instance.login(
        permissions: ['email', 'public_profile'],
      );

      if (result.status == LoginStatus.success) {
        final AccessToken accessToken = result.accessToken!;

        // Get user data
        final userData = await FacebookAuth.instance.getUserData(
          fields: "name,email,picture.width(200)",
        );

        print('User: ${userData['name']}');
        print('Email: ${userData['email']}');
        return userData;
      } else {
        print('Login failed: ${result.message}');
        return null;
      }
    } catch (e) {
      print('Error: $e');
      return null;
    }
  }

  // Check if already logged in
  Future<AccessToken?> checkLoginStatus() async {
    return await FacebookAuth.instance.accessToken;
  }

  // Log out
  Future<void> logout() async {
    await FacebookAuth.instance.logOut();
  }
}
