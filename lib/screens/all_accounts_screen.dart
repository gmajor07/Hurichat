import 'package:flutter/material.dart';

class AllAccountsScreen extends StatelessWidget {
  const AllAccountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.grey.shade900 : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? Colors.grey.shade800 : Color(0xFF128C7E),
        elevation: 0,
        title: Text('All Accounts', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView.builder(
        itemCount: 20,
        itemBuilder: (context, index) {
          return ListTile(
            leading: CircleAvatar(
              radius: 24,
              backgroundColor: isDark
                  ? Colors.grey.shade700
                  : Colors.grey.shade300,
              backgroundImage: NetworkImage(
                'https://i.pravatar.cc/150?img=${index + 20}',
              ),
            ),
            title: Text(
              'Account ${index + 1}',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Text('${index + 5} mutual friends'),
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
    );
  }
}
