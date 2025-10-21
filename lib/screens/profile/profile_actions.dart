import 'package:flutter/material.dart';

class ProfileActions extends StatelessWidget {
  final VoidCallback onUpdateProfile;
  final VoidCallback onSignOut;
  static const Color themeColor = Color(0xFF4CAFAB);

  const ProfileActions({
    super.key,
    required this.onUpdateProfile,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: onUpdateProfile,
            icon: const Icon(Icons.edit, color: Colors.white),
            label: const Text(
              'Update Profile',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: themeColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: onSignOut,
            icon: const Icon(Icons.logout, color: Color(0xFF4CAFAB)),
            label: const Text(
              'Logout',
              style: TextStyle(
                fontSize: 15,
                color: Color(0xFF4CAFAB),
                fontWeight: FontWeight.w600,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF4CAFAB)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
