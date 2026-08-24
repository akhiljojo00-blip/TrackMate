import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final DatabaseService _databaseService = DatabaseService();
  final NotificationService _notificationService = NotificationService();

  User? _user;
  UserModel? _userModel;
  bool _isLoading = false;
  String? _errorMessage;
  StreamSubscription<User?>? _authSubscription;

  User? get user => _user;
  UserModel? get userModel => _userModel;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _user != null;

  AuthProvider() {
    _authSubscription = _authService.authStateChanges.listen((user) async {
      _user = user;
      if (user != null) {
        await _loadUserProfile(user.uid);
        await _syncDeviceToken(user.uid);
      } else {
        _userModel = null;
      }
      notifyListeners();
    });
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> _loadUserProfile(String uid) async {
    try {
      _userModel = await _databaseService.getUserProfile(uid);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading user profile: $e');
    }
  }

  Future<void> _syncDeviceToken(String uid) async {
    try {
      final token = await _notificationService.getDeviceToken();
      if (token != null && token.isNotEmpty) {
        await _databaseService.saveUserDeviceToken(uid, token);
        debugPrint('FCM Device token registered for user session');
      }
    } catch (e) {
      debugPrint('Notice: unable to sync device token: $e');
    }
  }

  Future<bool> signUp({
    required String name,
    required String username,
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      final trimmedName = name.trim();
      final trimmedUsername = username.trim().toLowerCase();
      final trimmedEmail = email.trim();

      if (trimmedName.isEmpty) {
        _errorMessage = 'Name cannot be empty';
        _setLoading(false);
        return false;
      }
      if (trimmedUsername.isEmpty) {
        _errorMessage = 'Username cannot be empty';
        _setLoading(false);
        return false;
      }
      if (trimmedEmail.isEmpty || !trimmedEmail.contains('@')) {
        _errorMessage = 'Please enter a valid email address';
        _setLoading(false);
        return false;
      }
      if (password.length < 6) {
        _errorMessage = 'Password must be at least 6 characters long';
        _setLoading(false);
        return false;
      }

      final credential = await _authService.signUpWithEmail(
        email: trimmedEmail,
        password: password,
      );

      final uid = credential.user?.uid;
      if (uid != null) {
        final newUser = UserModel(
          uid: uid,
          name: trimmedName,
          username: trimmedUsername,
          email: trimmedEmail,
          isLocationSharing: false,
          createdAt: DateTime.now().millisecondsSinceEpoch,
        );
        await _databaseService.createUserProfile(newUser);
        _userModel = newUser;
        await _syncDeviceToken(uid);
      }

      _setLoading(false);
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _getFriendlyAuthErrorMessage(e);
      _setLoading(false);
      return false;
    } catch (e) {
      _errorMessage = 'Sign up failed: ${e.toString()}';
      _setLoading(false);
      return false;
    }
  }

  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      final input = email.trim();
      if (input.isEmpty) {
        _errorMessage = 'Please enter your email or username';
        _setLoading(false);
        return false;
      }
      if (password.isEmpty) {
        _errorMessage = 'Please enter your password';
        _setLoading(false);
        return false;
      }

      String resolvedEmail = input;
      if (!input.contains('@')) {
        // Resolve username to registered email
        final fetchedEmail = await _databaseService.getEmailByUsername(input);
        if (fetchedEmail == null || fetchedEmail.isEmpty) {
          _errorMessage = 'No account found with username "$input".';
          _setLoading(false);
          return false;
        }
        resolvedEmail = fetchedEmail;
      }

      final credential = await _authService.signInWithEmail(
        email: resolvedEmail,
        password: password,
      );

      final uid = credential.user?.uid;
      if (uid != null) {
        await _loadUserProfile(uid);
        await _syncDeviceToken(uid);
      }

      _setLoading(false);
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _getFriendlyAuthErrorMessage(e);
      _setLoading(false);
      return false;
    } catch (e) {
      _errorMessage = 'Sign in failed: ${e.toString()}';
      _setLoading(false);
      return false;
    }
  }

  Future<void> signOut() async {
    _setLoading(true);
    try {
      if (_user != null) {
        try {
          await _databaseService.clearUserDeviceToken(_user!.uid);
          debugPrint('FCM Device token cleared on sign out');
        } catch (e) {
          debugPrint('Notice: unable to clear device token on sign out: $e');
        }
      }
      await _authService.signOut();
      _user = null;
      _userModel = null;
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Sign out failed: ${e.toString()}';
    } finally {
      _setLoading(false);
    }
  }

  String _getFriendlyAuthErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with this email address.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Invalid email or password.';
      case 'email-already-in-use':
        return 'An account already exists with this email address.';
      case 'invalid-email':
        return 'The email address format is invalid.';
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'network-request-failed':
        return 'Network connection failed. Please check your internet connection.';
      default:
        return e.message ?? 'An authentication error occurred.';
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
