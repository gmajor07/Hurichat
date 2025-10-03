import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
      body: CustomScrollView(
        slivers: [
          // App Bar with profile header
          SliverAppBar(
            expandedHeight: 200,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [Colors.lightGreen.shade800, Colors.green.shade800]
                        : [Colors.lightGreen.shade500, Colors.green.shade500],
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.2),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: user?.photoURL != null
                            ? CircleAvatar(
                                backgroundImage: NetworkImage(user!.photoURL!),
                              )
                            : Icon(
                                Icons.person,
                                size: 40,
                                color: Colors.white.withOpacity(0.8),
                              ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        user?.email ?? '',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.logout,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                onPressed: () async {
                  final shouldLogout = await showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Logout'),
                      content: const Text('Are you sure you want to logout?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text(
                            'Logout',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  );

                  if (shouldLogout == true) {
                    await FirebaseAuth.instance.signOut();
                    if (context.mounted) {
                      Navigator.pushReplacementNamed(context, '/login');
                    }
                  }
                },
              ),
            ],
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 20)),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: ChatScreen(
                userId: user!.uid,
                chatId: '',
              ), // custom widget you create
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),

          // Other options like Messages, Groups, Settings
          SliverToBoxAdapter(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.message, color: theme.primaryColor),
                  title: const Text("My Messages"),
                  onTap: () => Navigator.pushNamed(context, '/messages'),
                ),
                ListTile(
                  leading: Icon(Icons.group, color: theme.primaryColor),
                  title: const Text("My Groups"),
                  onTap: () => Navigator.pushNamed(context, '/groups'),
                ),
                ListTile(
                  leading: Icon(Icons.settings, color: theme.primaryColor),
                  title: const Text("Settings"),
                  onTap: () => Navigator.pushNamed(context, '/settings'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
