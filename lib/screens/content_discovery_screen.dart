import 'package:flutter/material.dart';

/// Hurchat teal accent used sparingly across the discovery UI.
const Color _accent = Color(0xFF4CAFAB);

/// ──────────────────────────────────────────────────────────────────────
/// Mock data
/// ──────────────────────────────────────────────────────────────────────

enum _ContentType { course, article, video }

class _MockCourse {
  final String id;
  final String title;
  final String instructor;
  final int lessonCount;
  final int lessonsCompleted;
  final Color color;
  final IconData icon;

  const _MockCourse({
    required this.id,
    required this.title,
    required this.instructor,
    required this.lessonCount,
    required this.lessonsCompleted,
    required this.color,
    required this.icon,
  });

  double get progress => lessonCount == 0
      ? 0
      : (lessonsCompleted / lessonCount).clamp(0.0, 1.0);
}

class _MockContent {
  final String id;
  final String title;
  final String creator;
  final _ContentType type;
  final Color color;
  final IconData icon;

  const _MockContent({
    required this.id,
    required this.title,
    required this.creator,
    required this.type,
    required this.color,
    required this.icon,
  });

  String get typeLabel => switch (type) {
    _ContentType.course => 'Course',
    _ContentType.article => 'Article',
    _ContentType.video => 'Video',
  };
}

class _MockCreator {
  final String id;
  final String name;
  final String headline;
  final String followers;
  final Color color;

  const _MockCreator({
    required this.id,
    required this.name,
    required this.headline,
    required this.followers,
    required this.color,
  });
}

const _featured = _MockContent(
  id: 'featured',
  title: 'Master UI/UX Design 2024',
  creator: 'Sarah Johnson',
  type: _ContentType.course,
  color: Color(0xFF2D6CDF),
  icon: Icons.design_services,
);

const _continueLearning = <_MockCourse>[
  _MockCourse(
    id: 'c1',
    title: 'Flutter Fundamentals',
    instructor: 'David Lee',
    lessonCount: 24,
    lessonsCompleted: 15,
    color: Color(0xFF0E7C7B),
    icon: Icons.flutter_dash,
  ),
  _MockCourse(
    id: 'c2',
    title: 'Firebase for Beginners',
    instructor: 'Emma Wilson',
    lessonCount: 18,
    lessonsCompleted: 6,
    color: Color(0xFFF2B705),
    icon: Icons.local_fire_department,
  ),
];

const _popularCreators = <_MockCreator>[
  _MockCreator(
    id: 'cr1',
    name: 'Sarah Johnson',
    headline: 'Product Designer',
    followers: '12.4k',
    color: Color(0xFF2D6CDF),
  ),
  _MockCreator(
    id: 'cr2',
    name: 'David Lee',
    headline: 'Flutter Developer',
    followers: '8.1k',
    color: Color(0xFF0E7C7B),
  ),
  _MockCreator(
    id: 'cr3',
    name: 'Emma Wilson',
    headline: 'Cloud Architect',
    followers: '5.7k',
    color: Color(0xFFF2B705),
  ),
];

const _latestContent = <_MockContent>[
  _MockContent(
    id: 'l1',
    title: 'Building Responsive Layouts',
    creator: 'David Lee',
    type: _ContentType.course,
    color: Color(0xFF0E7C7B),
    icon: Icons.view_quilt_outlined,
  ),
  _MockContent(
    id: 'l2',
    title: 'State Management Explained',
    creator: 'Emma Wilson',
    type: _ContentType.article,
    color: Color(0xFF2D6CDF),
    icon: Icons.article_outlined,
  ),
  _MockContent(
    id: 'l3',
    title: 'Advanced Animations',
    creator: 'Sarah Johnson',
    type: _ContentType.video,
    color: Color(0xFFBA68C8),
    icon: Icons.movie_outlined,
  ),
];

const _recommendedCourses = <_MockCourse>[
  _MockCourse(
    id: 'r1',
    title: 'Dart from Zero',
    instructor: 'Mike Chen',
    lessonCount: 12,
    lessonsCompleted: 0,
    color: Color(0xFF0E7C7B),
    icon: Icons.code,
  ),
  _MockCourse(
    id: 'r2',
    title: 'Clean Architecture',
    instructor: 'Sarah Johnson',
    lessonCount: 18,
    lessonsCompleted: 0,
    color: Color(0xFF2D6CDF),
    icon: Icons.account_tree_outlined,
  ),
];

const _subscribedContent = <_MockContent>[
  _MockContent(
    id: 's1',
    title: 'Design Systems Deep Dive',
    creator: 'Sarah Johnson',
    type: _ContentType.video,
    color: Color(0xFF2D6CDF),
    icon: Icons.movie_outlined,
  ),
  _MockContent(
    id: 's2',
    title: 'Scaling Firebase Apps',
    creator: 'Emma Wilson',
    type: _ContentType.article,
    color: Color(0xFFF2B705),
    icon: Icons.article_outlined,
  ),
];

const _membershipTiers = <_MockTier>[
  _MockTier(
    name: 'Free',
    price: '0',
    period: 'forever',
    features: ['Basic content', 'Community access'],
    color: Color(0xFF9AA0A6),
  ),
  _MockTier(
    name: 'Pro',
    price: '9',
    period: '/month',
    features: [
      'All courses',
      'Exclusive content',
      'Creator Q&A',
      'Certificates',
    ],
    color: Color(0xFF0E7C7B),
    highlight: true,
  ),
  _MockTier(
    name: 'Premium',
    price: '19',
    period: '/month',
    features: [
      'Everything in Pro',
      '1-on-1 mentoring',
      'Early access',
      'Offline downloads',
    ],
    color: Color(0xFF2D6CDF),
  ),
];

const _membershipCourses = <_MockCourse>[
  _MockCourse(
    id: 'm1',
    title: 'Advanced Flutter Patterns',
    instructor: 'David Lee',
    lessonCount: 20,
    lessonsCompleted: 4,
    color: Color(0xFF0E7C7B),
    icon: Icons.flutter_dash,
  ),
  _MockCourse(
    id: 'm2',
    title: 'System Design Interviews',
    instructor: 'Mike Chen',
    lessonCount: 16,
    lessonsCompleted: 0,
    color: Color(0xFF2D6CDF),
    icon: Icons.account_tree_outlined,
  ),
];

class _MockTier {
  final String name;
  final String price;
  final String period;
  final List<String> features;
  final Color color;
  final bool highlight;

  const _MockTier({
    required this.name,
    required this.price,
    required this.period,
    required this.features,
    required this.color,
    this.highlight = false,
  });
}

/// ──────────────────────────────────────────────────────────────────────
/// Screen
/// ──────────────────────────────────────────────────────────────────────

class ContentDiscoveryScreen extends StatefulWidget {
  const ContentDiscoveryScreen({super.key});

  @override
  State<ContentDiscoveryScreen> createState() => _ContentDiscoveryScreenState();
}

enum _Category { all, subscriptions, memberships, courses }

class _ContentDiscoveryScreenState extends State<ContentDiscoveryScreen> {
  _Category _selected = _Category.all;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  static const _categoryLabels = <_Category, String>{
    _Category.all: 'All',
    _Category.subscriptions: 'Subscriptions',
    _Category.memberships: 'Memberships',
    _Category.courses: 'Courses',
  };

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _select(_Category category) {
    setState(() => _selected = category);
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bg = isDark ? const Color(0xFF121212) : Colors.white;
    final Color primaryText = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Discover Content',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: primaryText,
          ),
        ),
      ),
      body: Column(
        children: [
          _buildSearchField(isDark),
          _buildCategoryTabs(isDark),
          Expanded(
            child: _buildBody(isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF7F9FA),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.06),
          ),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
          style: TextStyle(
            fontSize: 15,
            color: isDark ? Colors.white : Colors.black87,
          ),
          decoration: InputDecoration(
            hintText: 'Search courses, creators, content',
            hintStyle: TextStyle(
              fontSize: 15,
              color: isDark ? Colors.white38 : Colors.grey.shade500,
            ),
            prefixIcon: Icon(
              Icons.search_rounded,
              size: 20,
              color: isDark ? Colors.white54 : Colors.grey.shade500,
            ),
            suffixIcon: _query.isNotEmpty
                ? IconButton(
                    tooltip: 'Clear search',
                    icon: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: isDark ? Colors.white54 : Colors.grey.shade500,
                    ),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _query = '');
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryTabs(bool isDark) {
    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _Category.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final category = _Category.values[index];
          final selected = category == _selected;
          return _CategoryChip(
            label: _categoryLabels[category]!,
            selected: selected,
            isDark: isDark,
            onTap: () => _select(category),
          );
        },
      ),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_query.isNotEmpty) {
      return _buildSearchResults(isDark);
    }
    switch (_selected) {
      case _Category.all:
        return _buildAllFeed(isDark);
      case _Category.subscriptions:
        return _buildSubscriptions(isDark);
      case _Category.memberships:
        return _buildMemberships(isDark);
      case _Category.courses:
        return _buildCourses(isDark);
    }
  }

  // ── All feed ─────────────────────────────────────────────────────────
  Widget _buildAllFeed(bool isDark) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _SectionHeader(title: 'Featured Content'),
        _FeaturedCard(content: _featured),
        _SectionHeader(title: 'Continue Learning'),
        SizedBox(
          height: 250,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _continueLearning.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) => _CourseCard(
              course: _continueLearning[index],
              showProgress: true,
              width: 220,
            ),
          ),
        ),
        _SectionHeader(title: 'Popular Creators'),
        SizedBox(
          height: 148,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _popularCreators.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) => _CreatorCard(
              creator: _popularCreators[index],
            ),
          ),
        ),
        _SectionHeader(title: 'Latest Content'),
        ..._latestContent.map((c) => _ContentCard(content: c)),
        _SectionHeader(title: 'Recommended Courses'),
        SizedBox(
          height: 210,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _recommendedCourses.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) => _CourseCard(
              course: _recommendedCourses[index],
              showProgress: false,
              width: 220,
            ),
          ),
        ),
      ],
    );
  }

  // ── Search results ───────────────────────────────────────────────────
  Widget _buildSearchResults(bool isDark) {
    final all = <_MockContent>[_featured, ..._latestContent, ..._subscribedContent];
    final courses = <_MockCourse>[..._continueLearning, ..._recommendedCourses, ..._membershipCourses];

    final matchedContent = all.where((c) {
      final haystack = '${c.title} ${c.creator} ${c.typeLabel}'.toLowerCase();
      return haystack.contains(_query);
    }).toList();

    final matchedCourses = courses.where((c) {
      final haystack = '${c.title} ${c.instructor}'.toLowerCase();
      return haystack.contains(_query);
    }).toList();

    final creatorMatches = _popularCreators.where((c) {
      final haystack = '${c.name} ${c.headline}'.toLowerCase();
      return haystack.contains(_query);
    }).toList();

    if (matchedContent.isEmpty && matchedCourses.isEmpty && creatorMatches.isEmpty) {
      return _EmptyState(
        icon: Icons.search_off_rounded,
        title: 'No results for "$_query"',
        subtitle: 'Try searching for a different topic or creator.',
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (creatorMatches.isNotEmpty) ...[
          _SectionHeader(title: 'Creators'),
          SizedBox(
            height: 148,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: creatorMatches.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) => _CreatorCard(
                creator: creatorMatches[index],
              ),
            ),
          ),
        ],
        if (matchedCourses.isNotEmpty) ...[
          _SectionHeader(title: 'Courses'),
          ...matchedCourses.map(
            (c) => _CourseListCard(course: c, showProgress: true),
          ),
        ],
        if (matchedContent.isNotEmpty) ...[
          _SectionHeader(title: 'Content'),
          ...matchedContent.map((c) => _ContentCard(content: c)),
        ],
      ],
    );
  }

  // ── Subscriptions ────────────────────────────────────────────────────
  Widget _buildSubscriptions(bool isDark) {
    final subscribed = _subscribedContent.where((c) {
      if (_query.isEmpty) return true;
      return '${c.title} ${c.creator}'.toLowerCase().contains(_query);
    }).toList();

    if (_subscribedContent.isEmpty) {
      return _EmptyState(
        icon: Icons.subscriptions_outlined,
        title: 'No subscriptions yet',
        subtitle: 'Subscribe to creators to see their latest content here.',
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _SectionHeader(title: 'From Your Subscriptions'),
        if (subscribed.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 24, 16, 24),
            child: _EmptyState(
              icon: Icons.search_off_rounded,
              title: 'No matching content',
              subtitle: 'Try a different search.',
            ),
          )
        else
          ...subscribed.map((c) => _ContentCard(content: c)),
      ],
    );
  }

  // ── Memberships ──────────────────────────────────────────────────────
  Widget _buildMemberships(bool isDark) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _SectionHeader(title: 'Exclusive Previews'),
        SizedBox(
          height: 250,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _membershipCourses.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) => _CourseCard(
              course: _membershipCourses[index],
              showProgress: true,
              width: 220,
            ),
          ),
        ),
        _SectionHeader(title: 'Membership Tiers'),
        ..._membershipTiers.map((tier) => _TierCard(tier: tier)),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            'Membership previews only. Payments and subscriptions are not enabled in this UI.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  // ── Courses ──────────────────────────────────────────────────────────
  Widget _buildCourses(bool isDark) {
    final courses = _continueLearning.where((c) {
      if (_query.isEmpty) return true;
      return '${c.title} ${c.instructor}'.toLowerCase().contains(_query);
    }).toList();

    if (_continueLearning.isEmpty) {
      return _EmptyState(
        icon: Icons.menu_book_outlined,
        title: 'No courses yet',
        subtitle: 'Enroll in courses to track your progress here.',
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _SectionHeader(title: 'Your Courses'),
        if (courses.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 24, 16, 24),
            child: _EmptyState(
              icon: Icons.search_off_rounded,
              title: 'No matching courses',
              subtitle: 'Try a different search.',
            ),
          )
        else
          ...courses.map((c) => _CourseListCard(course: c, showProgress: true)),
      ],
    );
  }
}

/// ──────────────────────────────────────────────────────────────────────
/// Shared widgets
/// ──────────────────────────────────────────────────────────────────────

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? _accent
          : (isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF1F3F4)),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: selected
                ? Border.all(color: _accent, width: 1.4)
                : Border.all(
                    color: isDark
                        ? Colors.white12
                        : Colors.black.withValues(alpha: 0.06),
                    width: 1,
                  ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected
                  ? Colors.white
                  : (isDark ? Colors.white70 : Colors.black54),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  final _MockContent content;

  const _FeaturedCard({required this.content});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 190,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            colors: [content.color, content.color.withValues(alpha: 0.7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Opacity(
                opacity: 0.18,
                child: Icon(content.icon, size: 140, color: Colors.white),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'FEATURED',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        content.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'by ${content.creator}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: const Text(
                          'Start Learning',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2D6CDF),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  final _MockCourse course;
  final bool showProgress;
  final double width;

  const _CourseCard({
    required this.course,
    required this.showProgress,
    this.width = 220,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 110,
            width: double.infinity,
            color: course.color,
            child: Center(
              child: Icon(course.icon, size: 44, color: Colors.white),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  course.instructor,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.menu_book_outlined,
                      size: 14,
                      color: isDark ? Colors.white38 : Colors.grey.shade500,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${course.lessonCount} lessons',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                if (showProgress && course.progress > 0) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: course.progress,
                      minHeight: 5,
                      backgroundColor:
                          isDark ? Colors.white12 : Colors.grey.shade200,
                      valueColor: const AlwaysStoppedAnimation<Color>(_accent),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${(course.progress * 100).round()}% complete',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _accent,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseListCard extends StatelessWidget {
  final _MockCourse course;
  final bool showProgress;

  const _CourseListCard({required this.course, required this.showProgress});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: course.color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(course.icon, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  course.instructor,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.menu_book_outlined,
                      size: 14,
                      color: isDark ? Colors.white38 : Colors.grey.shade500,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${course.lessonCount} lessons',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                if (showProgress && course.progress > 0) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: course.progress,
                      minHeight: 5,
                      backgroundColor:
                          isDark ? Colors.white12 : Colors.grey.shade200,
                      valueColor: const AlwaysStoppedAnimation<Color>(_accent),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContentCard extends StatelessWidget {
  final _MockContent content;

  const _ContentCard({required this.content});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: content.color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(content.icon, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  content.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      content.creator,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: content.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        content.typeLabel,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: content.color,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CreatorCard extends StatelessWidget {
  final _MockCreator creator;

  const _CreatorCard({required this.creator});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 120,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: creator.color,
            child: Text(
              creator.name[0],
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            creator.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            creator.headline,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10.5,
              color: isDark ? Colors.white54 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${creator.followers} followers',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: _accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _TierCard extends StatelessWidget {
  final _MockTier tier;

  const _TierCard({required this.tier});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: tier.highlight
              ? _accent
              : (isDark
                  ? Colors.white12
                  : Colors.black.withValues(alpha: 0.06)),
          width: tier.highlight ? 1.6 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                tier.name,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: tier.color,
                ),
              ),
              if (tier.highlight)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'POPULAR',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                      color: _accent,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '\$${tier.price}',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                TextSpan(
                  text: ' ${tier.period}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ...tier.features.map(
            (feature) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, size: 15, color: _accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      feature,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 56,
              color: isDark ? Colors.white24 : Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white54 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}