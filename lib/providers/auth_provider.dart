import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/account_deletion_service.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;
  final DatabaseService _databaseService;
  final NotificationService _notificationService;
  final AccountDeletionService _accountDeletionService;

  User? _user;
  UserModel? _userModel;
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _errorMessage;
  StreamSubscription<User?>? _authSubscription;
  final Completer<void> _initialAuthCompleter = Completer<void>();

  User? get user => _user;
  UserModel? get userModel => _userModel;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _user != null;
  Future<void> get initializationDone => _initialAuthCompleter.future;

  AuthProvider({
    AuthService? authService,
    DatabaseService? databaseService,
    NotificationService? notificationService,
    AccountDeletionService? accountDeletionService,
  })  : _authService = authService ?? AuthService(),
        _databaseService = databaseService ?? DatabaseService(),
        _notificationService = notificationService ?? NotificationService(),
        _accountDeletionService = accountDeletionService ?? AccountDeletionService() {
    _initializeAuth();
  }

  void _initializeAuth() {
    try {
      final initialUser = _authService.currentUser;
      _user = initialUser;

      _authSubscription = _authService.authStateChanges.listen((user) async {
        _user = user;
        if (user != null) {
          await _loadUserProfile(user.uid);
          await _syncDeviceToken(user.uid);
        } else {
          _userModel = null;
        }
        _isInitialized = true;
        if (!_initialAuthCompleter.isCompleted) {
          _initialAuthCompleter.complete();
        }
        notifyListeners();
      }, onError: (e) {
        debugPrint('Auth state change listener error: $e');
        _isInitialized = true;
        if (!_initialAuthCompleter.isCompleted) {
          _initialAuthCompleter.complete();
        }
      });

      if (initialUser != null) {
        _loadUserProfile(initialUser.uid).then((_) {
          _isInitialized = true;
          if (!_initialAuthCompleter.isCompleted) {
            _initialAuthCompleter.complete();
          }
          notifyListeners();
        }).catchError((_) {
          _isInitialized = true;
          if (!_initialAuthCompleter.isCompleted) {
            _initialAuthCompleter.complete();
          }
        });
      } else {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (!_isInitialized) {
            _isInitialized = true;
            if (!_initialAuthCompleter.isCompleted) {
              _initialAuthCompleter.complete();
            }
            notifyListeners();
          }
        });
      }
    } catch (e) {
      debugPrint('Auth initialization fallback: $e');
      _isInitialized = true;
      if (!_initialAuthCompleter.isCompleted) {
        _initialAuthCompleter.complete();
      }
    }
  }

  Future<void> refreshProfile() async {
    if (_user != null) {
      await _loadUserProfile(_user!.uid);
    }
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

  Future<bool> updateUsername(String newUsername) async {
    if (_user == null) return false;
    _setLoading(true);
    _errorMessage = null;

    try {
      final sanitizedNew = newUsername.trim().toLowerCase();
      final currentUsername = _userModel?.username ?? '';

      if (sanitizedNew == currentUsername) {
        _setLoading(false);
        return true;
      }

      await _databaseService.updateUsername(
        uid: _user!.uid,
        oldUsername: currentUsername,
        newUsername: sanitizedNew,
      );

      if (_userModel != null) {
        _userModel = _userModel!.copyWith(username: sanitizedNew);
      } else {
        await _loadUserProfile(_user!.uid);
      }

      _setLoading(false);
      notifyListeners();
      return true;
    } on FormatException catch (e) {
      _errorMessage = e.message;
      _setLoading(false);
      return false;
    } on StateError catch (e) {
      _errorMessage = e.message;
      _setLoading(false);
      return false;
    } catch (e) {
      _errorMessage = 'Failed to update username: ${e.toString()}';
      _setLoading(false);
      return false;
    }
  }

  Future<bool> updateProfile({
    required String name,
    String? username,
    String? bio,
    String? emergencyContact,
    int? avatarPresetIndex,
  }) async {
    if (_user == null) return false;
    _setLoading(true);
    _errorMessage = null;

    try {
      final trimmedName = name.trim();
      if (trimmedName.isEmpty) {
        _errorMessage = 'Name cannot be empty';
        _setLoading(false);
        return false;
      }

      // If username changed, perform atomic swap check
      if (username != null) {
        final sanitizedUsername = username.trim().toLowerCase();
        if (sanitizedUsername.isNotEmpty && sanitizedUsername != _userModel?.username.toLowerCase()) {
          final usernameSuccess = await updateUsername(sanitizedUsername);
          if (!usernameSuccess) {
            // Error message already set by updateUsername
            return false;
          }
        }
      }

      final updates = <String, dynamic>{
        'name': trimmedName,
        'bio': bio?.trim(),
        'emergencyContact': emergencyContact?.trim(),
        'avatarPresetIndex': avatarPresetIndex,
      };

      await _databaseService.updateUserProfile(_user!.uid, updates);

      if (_userModel != null) {
        _userModel = _userModel!.copyWith(
          name: trimmedName,
          bio: bio?.trim(),
          emergencyContact: emergencyContact?.trim(),
          avatarPresetIndex: avatarPresetIndex,
        );
      } else {
        await _loadUserProfile(_user!.uid);
      }

      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = 'Failed to update profile: ${e.toString()}';
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

  Future<bool> deleteAccount({
    required String password,
  }) async {
    if (_user == null) {
      _errorMessage = 'No authenticated user session found.';
      notifyListeners();
      return false;
    }
    _setLoading(true);
    _errorMessage = null;

    try {
      final user = _user!;
      final userModel = _userModel ??
          UserModel(
            uid: user.uid,
            name: user.displayName ?? 'User',
            username: (user.email?.split('@').first ?? 'user').toLowerCase(),
            email: user.email ?? '',
            isLocationSharing: false,
            createdAt: 0,
          );

      await _accountDeletionService.purgeAndCloseAccount(
        authUser: user,
        password: password,
        userModel: userModel,
      );

      _user = null;
      _userModel = null;
      _errorMessage = null;
      _setLoading(false);
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _getFriendlyAuthErrorMessage(e);
      _setLoading(false);
      return false;
    } catch (e) {
      _errorMessage = 'Failed to delete account: ${e.toString()}';
      _setLoading(false);
      return false;
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
      case 'requires-recent-login':
        return 'Session expired. Please sign out and sign back in to delete your account.';
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
