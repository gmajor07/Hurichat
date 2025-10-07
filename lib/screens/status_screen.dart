import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'all_accounts_screen.dart';

class StatusScreen extends StatelessWidget {
  const StatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.grey.shade900 : Colors.white,
      body: Column(
        children: [
          // My Status
          _buildMyStatusSection(user, isDark),

          // Recent Updates
          _buildRecentUpdatesSection(isDark),

          // Accounts to Follow
          _buildAccountsToFollowSection(context, isDark),

          // Followed Status
          _buildFollowedStatusSection(isDark),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            mini: true,
            backgroundColor: isDark
                ? Colors.grey.shade700
                : Colors.grey.shade300,
            child: Icon(
              Icons.edit,
              color: isDark ? Colors.white : Colors.grey.shade600,
            ),
            onPressed: () {},
          ),
          SizedBox(height: 16),
          FloatingActionButton(
            backgroundColor: Color(0xFF128C7E),
            child: Icon(Icons.camera_alt, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildMyStatusSection(User? user, bool isDark) {
    return ListTile(
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: isDark
                ? Colors.grey.shade700
                : Colors.grey.shade300,
            child: user?.photoURL != null
                ? CircleAvatar(
                    backgroundImage: NetworkImage(user!.photoURL!),
                    radius: 26,
                  )
                : Icon(
                    Icons.person,
                    size: 30,
                    color: isDark ? Colors.white : Colors.grey.shade600,
                  ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Color(0xFF128C7E),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Icon(Icons.add, color: Colors.white, size: 16),
            ),
          ),
        ],
      ),
      title: Text('My status', style: TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text('Tap to add status update'),
      onTap: () {},
    );
  }

  Widget _buildRecentUpdatesSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Text(
            'Recent updates',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16),
            itemCount: 5,
            itemBuilder: (context, index) {
              return Container(
                width: 70,
                margin: EdgeInsets.only(right: 12),
                child: SizedBox(
                  height: 100,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Color(0xFF128C7E),
                            width: 2,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 26,
                          backgroundColor: isDark
                              ? Colors.grey.shade700
                              : Colors.grey.shade300,
                          backgroundImage: NetworkImage(
                            'https://i.pravatar.cc/150?img=$index',
                          ),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'User ${index + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${index + 1}h ago',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Divider(height: 20),
      ],
    );
  }

  Widget _buildAccountsToFollowSection(BuildContext context, bool isDark) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Accounts to follow',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AllAccountsScreen(),
                    ),
                  );
                },
                child: Text(
                  'See all',
                  style: TextStyle(
                    color: Color(0xFF128C7E),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: 3,
          itemBuilder: (context, index) {
            return ListTile(
              leading: CircleAvatar(
                radius: 24,
                backgroundColor: isDark
                    ? Colors.grey.shade700
                    : Colors.grey.shade300,
                backgroundImage: NetworkImage(
                  'https://i.pravatar.cc/150?img=${index + 10}',
                ),
              ),
              title: Text(
                'Suggested User ${index + 1}',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: Text('${index + 15} mutual friends'),
              trailing: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Color(0xFF128C7E),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Follow',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            );
          },
        ),
        Divider(height: 20),
      ],
    );
  }

  Widget _buildFollowedStatusSection(bool isDark) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text(
              'Followed Status',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: 8,
              itemBuilder: (context, index) {
                return ListTile(
                  leading: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Color(0xFF128C7E), width: 2),
                    ),
                    child: CircleAvatar(
                      radius: 26,
                      backgroundColor: isDark
                          ? Colors.grey.shade700
                          : Colors.grey.shade300,
                      backgroundImage: NetworkImage(
                        'https://i.pravatar.cc/150?img=${index + 5}',
                      ),
                    ),
                  ),
                  title: Text(
                    'Followed User ${index + 1}',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text('Today at ${index + 10}:30'),
                  trailing: Text(
                    '${index + 1}m',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
