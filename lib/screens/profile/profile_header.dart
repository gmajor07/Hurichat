import 'package:flutter/material.dart';
import '../user_account/profile_update_logic.dart';

class ProfileHeader extends StatelessWidget {
  final Map<String, dynamic>? userData;
  static const Color themeColor = Color(0xFF4CAFAB);

  const ProfileHeader({super.key, required this.userData});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final photoUrl = profileStringValue(userData?['photoUrl'], fallback: '');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : themeColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 35,
                backgroundColor: isDark ? Colors.grey[700] : Colors.grey[300],
                backgroundImage: photoUrl.isNotEmpty
                    ? NetworkImage(photoUrl)
                    : null,
                child: photoUrl.isNotEmpty
                    ? null
                    : Icon(
                        Icons.person,
                        size: 40,
                        color: isDark ? Colors.grey[400] : Colors.grey,
                      ),
              ),
              Positioned(
                right: -4,
                bottom: -4,
                child: Container(
                  decoration: BoxDecoration(
                    color: themeColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      width: 2,
                    ),
                  ),
                  padding: const EdgeInsets.all(6),
                  child: const Icon(Icons.edit, size: 12, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profileStringValue(
                    userData?['name'],
                    fallback: 'Unknown User',
                  ),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  profileStringValue(
                    userData?['phone'],
                    fallback: 'No phone number',
                  ),
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                if (userData?['age'] != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${userData!['age']} years old',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
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
