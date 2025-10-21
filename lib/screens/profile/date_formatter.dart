import 'package:cloud_firestore/cloud_firestore.dart';

class DateFormatter {
  static String formatDate(dynamic date) {
    if (date is Timestamp) {
      final DateTime dateTime = date.toDate();
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
    return 'Not set';
  }
}
