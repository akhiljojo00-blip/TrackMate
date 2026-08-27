import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../data/user_guide_data.dart';
import 'widgets/feedback_dialog.dart';

class UserGuideScreen extends StatefulWidget {
  const UserGuideScreen({super.key});

  @override
  State<UserGuideScreen> createState() => _UserGuideScreenState();
}

class _UserGuideScreenState extends State<UserGuideScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  IconData _resolveIcon(String iconName) {
    switch (iconName) {
      case 'shield':
        return Icons.security_outlined;
      case 'timer':
        return Icons.timer_outlined;
      case 'people':
        return Icons.group_outlined;
      case 'pin':
        return Icons.location_on_outlined;
      case 'sos':
        return Icons.emergency_outlined;
      case 'trash':
        return Icons.delete_forever_outlined;
      default:
        return Icons.menu_book_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final query = _searchQuery.trim().toLowerCase();

    // Filter sections based on search query
    final filteredSections = UserGuideRegistry.sections.map((section) {
      if (query.isEmpty) return section;
      final matchingItems = section.items.where((item) {
        return item.title.toLowerCase().contains(query) ||
            item.summary.toLowerCase().contains(query) ||
            item.howToUse.toLowerCase().contains(query) ||
            item.whyItMatters.toLowerCase().contains(query) ||
            item.keyRules.any((r) => r.toLowerCase().contains(query));
      }).toList();
      return GuideSection(
        categoryTitle: section.categoryTitle,
        iconName: section.iconName,
        items: matchingItems,
      );
    }).where((section) => section.items.isNotEmpty).toList();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF070D18) : Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Living User Manual', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: isDark ? const Color(0xFF0F1F3D) : Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Send Feedback',
            icon: const Icon(Icons.rate_review_outlined),
            onPressed: () => FeedbackDialog.show(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F1F3D) : Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: isDark ? Colors.white10 : Colors.grey.shade200,
                ),
              ),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Search features, privacy rules, or guides...',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                filled: true,
                fillColor: isDark ? const Color(0xFF0A1426) : Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Sections List
          Expanded(
            child: filteredSections.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off_outlined,
                          size: 48,
                          color: isDark ? Colors.white24 : Colors.black26,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No matching guides found for "$_searchQuery"',
                          style: TextStyle(
                            color: isDark ? Colors.white60 : Colors.black54,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredSections.length,
                    itemBuilder: (context, sectionIndex) {
                      final section = filteredSections[sectionIndex];
                      return _buildSectionCard(context, section, isDark);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(BuildContext context, GuideSection section, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: isDark ? const Color(0xFF0F1F3D) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade200,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: true,
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _resolveIcon(section.iconName),
                color: AppColors.primary,
                size: 20,
              ),
            ),
            title: Text(
              section.categoryTitle,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            subtitle: Text(
              '${section.items.length} feature ${section.items.length == 1 ? 'guide' : 'guides'}',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white54 : Colors.black45,
              ),
            ),
            children: section.items.map((item) => _buildGuideItemTile(context, item, isDark)).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildGuideItemTile(BuildContext context, GuideItem item, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Material(
        color: isDark ? const Color(0xFF0A1426) : Colors.grey.shade50,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
          title: Row(
            children: [
              Expanded(
                child: Text(
                  item.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  item.versionAdded,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              item.summary,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(),
                  const SizedBox(height: 6),

                  // Why it matters
                  _buildSubHeading('Why it matters:', Icons.lightbulb_outline, const Color(0xFFFBBF24)),
                  const SizedBox(height: 4),
                  Text(
                    item.whyItMatters,
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87),
                  ),
                  const SizedBox(height: 12),

                  // How to use
                  _buildSubHeading('How to use:', Icons.touch_app_outlined, AppColors.primary),
                  const SizedBox(height: 4),
                  Text(
                    item.howToUse,
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87),
                  ),
                  const SizedBox(height: 12),

                  // Key rules
                  _buildSubHeading('Key Invariants & Rules:', Icons.gavel_outlined, const Color(0xFF10B981)),
                  const SizedBox(height: 6),
                  ...item.keyRules.map(
                    (rule) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 4, right: 6),
                            child: Icon(Icons.circle, size: 5, color: Color(0xFF10B981)),
                          ),
                          Expanded(
                            child: Text(
                              rule,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildSubHeading(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
