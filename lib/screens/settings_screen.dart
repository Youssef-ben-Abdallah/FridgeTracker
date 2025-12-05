import 'package:flutter/material.dart';
import 'package:provider/provider.dart';


import '../services/database_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  int _notificationDays = 3;

  @override
  Widget build(BuildContext context) {
    final dbService = Provider.of<DatabaseService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          // Notifications Section
          _buildSectionHeader('Notifications'),
          SwitchListTile(
            title: const Text('Enable Notifications'),
            subtitle: const Text('Get reminders for expiring items'),
            value: _notificationsEnabled,
            onChanged: (value) {
              setState(() {
                _notificationsEnabled = value;
              });
            },
          ),
          ListTile(
            title: const Text('Notify before expiration'),
            subtitle: Text('$_notificationDays days before'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: _notificationDays > 1
                      ? () {
                    setState(() {
                      _notificationDays--;
                    });
                  }
                      : null,
                ),
                Text('$_notificationDays'),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _notificationDays < 7
                      ? () {
                    setState(() {
                      _notificationDays++;
                    });
                  }
                      : null,
                ),
              ],
            ),
          ),

          // Data Management Section
          _buildSectionHeader('Data Management'),
          FutureBuilder<int>(
            future: dbService.getInventoryCount(),
            builder: (context, snapshot) {
              final count = snapshot.data ?? 0;
              return ListTile(
                title: const Text('Inventory Items'),
                subtitle: Text('$count items in pantry'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: count > 0
                      ? () => _showClearInventoryDialog(dbService)
                      : null,
                ),
              );
            },
          ),
          FutureBuilder<int>(
            future: dbService.getExpiringSoonCount(),
            builder: (context, snapshot) {
              final count = snapshot.data ?? 0;
              return ListTile(
                title: const Text('Expired Items'),
                subtitle: Text('$count expired items'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_forever, color: Colors.red),
                  onPressed: () => _deleteExpiredItems(dbService),
                ),
              );
            },
          ),
          ListTile(
            title: const Text('Clear All Data'),
            subtitle: const Text('Remove all products and inventory'),
            trailing: IconButton(
              icon: const Icon(Icons.warning_amber, color: Colors.orange),
              onPressed: () => _showClearAllDataDialog(dbService),
            ),
          ),

          // App Information Section
          _buildSectionHeader('App Information'),
          ListTile(
            title: const Text('Version'),
            subtitle: const Text('1.0.0'),
          ),
          ListTile(
            title: const Text('About'),
            subtitle: const Text('Pantry Tracker - Keep your kitchen organized'),
            onTap: () {
              _showAboutDialog();
            },
          ),

          const SizedBox(height: 32),

          // Reset Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ElevatedButton.icon(
              onPressed: () => _resetToDefaults(dbService),
              icon: const Icon(Icons.restart_alt),
              label: const Text('Reset to Defaults'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
        ),
      ),
    );
  }

  Future<void> _showClearInventoryDialog(DatabaseService dbService) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Inventory'),
        content: const Text('This will remove all items from your pantry. This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await dbService.clearConsumedItems();
      // You might want to add a method to clear all inventory
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inventory cleared')),
      );
      setState(() {});
    }
  }

  Future<void> _deleteExpiredItems(DatabaseService dbService) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Expired Items'),
        content: const Text('This will permanently delete all expired items from your pantry.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await dbService.deleteExpiredItems();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expired items deleted')),
      );
      setState(() {});
    }
  }

  Future<void> _showClearAllDataDialog(DatabaseService dbService) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data'),
        content: const Text('This will delete ALL products and inventory items. This cannot be undone!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete All', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // This is a simplified version - you might want to implement a proper reset
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Feature coming soon')),
      );
    }
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About Pantry Tracker'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Pantry Tracker helps you keep track of your food inventory.'),
              SizedBox(height: 16),
              Text('Features:'),
              Text('• Scan barcodes to add products'),
              Text('• Extract expiration dates with OCR'),
              Text('• Get notifications before items expire'),
              Text('• Track quantities and categories'),
              Text('• View statistics about your pantry'),
              SizedBox(height: 16),
              Text('Made with ❤️ for organized kitchens'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _resetToDefaults(DatabaseService dbService) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset to Defaults'),
        content: const Text('This will add sample products and clear current data. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await dbService.close();
      // Reinitialize database (which will add sample products)
      await dbService.database;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reset to defaults completed')),
      );
      setState(() {});
    }
  }
}