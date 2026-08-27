import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../constants/app_colors.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/database_service.dart';

class FeedbackDialog extends StatefulWidget {
  final DatabaseService? databaseService;

  const FeedbackDialog({super.key, this.databaseService});

  static const String developerEmail = 'akhiljojo00@gmail.com';

  static Future<void> show(BuildContext context, {DatabaseService? databaseService}) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => FeedbackDialog(databaseService: databaseService),
    );
  }

  @override
  State<FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends State<FeedbackDialog> {
  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();
  String _selectedCategory = 'Feature Request';
  int _rating = 5;
  bool _isSubmitting = false;
  bool _alsoOpenEmail = false;

  static const List<String> _categories = [
    'Feature Request',
    'Bug Report',
    'General Feedback',
    'Usability / Design',
  ];

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submitFeedback() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final uid = authProvider.user?.uid ?? 'anonymous_user';
      final username = authProvider.userModel?.username ?? 'anonymous';
      final userEmail = authProvider.user?.email ?? authProvider.userModel?.email ?? 'N/A';
      final message = _messageController.text.trim();

      final feedbackPayload = {
        'uid': uid,
        'username': username,
        'email': userEmail,
        'category': _selectedCategory,
        'rating': _rating,
        'message': message,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'appVersion': '1.5.0',
      };

      // 1. 100% In-App Submission: Record payload to Realtime Database /feedback/$uid
      final db = widget.databaseService ?? DatabaseService();
      try {
        final feedbackRef = db.usersRef.root.child('feedback').child(uid).push();
        await feedbackRef.set(feedbackPayload);
      } catch (e) {
        debugPrint('Notice: unable to write feedback to remote DB: $e');
      }

      // 2. Optional External Email Dispatch if toggled
      if (_alsoOpenEmail) {
        final subject = '[TrackMate Feedback] [$_selectedCategory] from @$username';
        final body = '''
TrackMate User Feedback Report
----------------------------------------
User: @$username (Email: $userEmail)
User ID: $uid
Category: $_selectedCategory
Satisfaction Rating: $_rating / 5 Stars
App Version: 1.5.0

Details:
$message
----------------------------------------
Sent from TrackMate Mobile App
''';

        final emailUri = Uri(
          scheme: 'mailto',
          path: FeedbackDialog.developerEmail,
          query: 'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
        );

        try {
          if (await canLaunchUrl(emailUri)) {
            await launchUrl(emailUri, mode: LaunchMode.externalApplication);
          }
        } catch (e) {
          debugPrint('Notice: email client launcher note: $e');
        }
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thank you! Your feedback has been submitted successfully.'),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit feedback: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? const Color(0xFF0F1F3D) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.rate_review_outlined,
                        color: AppColors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Send Feedback',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          Text(
                            'Direct to developer: ${FeedbackDialog.developerEmail}',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'Category',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: _selectedCategory,
                  dropdownColor: isDark ? const Color(0xFF13284F) : Colors.white,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0A1426) : Colors.grey.shade100,
                  ),
                  items: _categories.map((cat) {
                    return DropdownMenuItem(
                      value: cat,
                      child: Text(
                        cat,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedCategory = val);
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  'Satisfaction Rating',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    final starValue = index + 1;
                    return IconButton(
                      icon: Icon(
                        starValue <= _rating ? Icons.star : Icons.star_border,
                        color: const Color(0xFFFBBF24),
                        size: 28,
                      ),
                      onPressed: () => setState(() => _rating = starValue),
                    );
                  }),
                ),
                const SizedBox(height: 12),
                Text(
                  'Details',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _messageController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Describe your feedback or suggestion in detail...',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                    contentPadding: const EdgeInsets.all(12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0A1426) : Colors.grey.shade100,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().length < 5) {
                      return 'Please provide at least 5 characters.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _alsoOpenEmail,
                  dense: true,
                  title: Text(
                    'Also open in email client app',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: (val) {
                    setState(() => _alsoOpenEmail = val ?? false);
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      ),
                      onPressed: _isSubmitting ? null : _submitFeedback,
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Submit Feedback'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
