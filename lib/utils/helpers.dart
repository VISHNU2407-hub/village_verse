import 'package:flutter/material.dart';

class AppHelpers {
  // Get greeting based on time of day
  static String getGreeting() {
    final hour = DateTime.now().hour;

    if (hour >= 5 && hour < 12) {
      return 'Good Morning';
    } else if (hour >= 12 && hour < 17) {
      return 'Good Afternoon';
    } else if (hour >= 17 && hour < 21) {
      return 'Good Evening';
    } else {
      return 'Good Night';
    }
  }

  // Validate phone number
  static String? validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number is required';
    }

    // Remove any non-digit characters
    final cleanPhone = value.replaceAll(RegExp(r'[^\d]'), '');

    if (cleanPhone.length != 10) {
      return 'Please enter a valid 10-digit phone number';
    }

    return null;
  }

  // Validate required field
  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  // Format phone number for display
  static String formatPhoneNumber(String phone) {
    if (phone.length == 10) {
      return '${phone.substring(0, 5)}-${phone.substring(5)}';
    }
    return phone;
  }

  // Show snackbar
  static void showSnackBar(
    BuildContext context,
    String message, {
    Color? color,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color ?? Colors.grey[800],
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Show success snackbar
  static void showSuccessSnackBar(BuildContext context, String message) {
    showSnackBar(context, message, color: Colors.green);
  }

  // Show error snackbar
  static void showErrorSnackBar(BuildContext context, String message) {
    showSnackBar(context, message, color: Colors.red);
  }

  // Format date for display
  static String formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  // Format date time for display - defensive with error handling
  static String formatDateTime(DateTime? dateTime) {
    if (dateTime == null) {
      print('WARNING: formatDateTime received null, using current time');
      return formatDate(DateTime.now());
    }

    try {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      print('ERROR: Failed to format DateTime: $e');
      return 'Unknown time';
    }
  }

  // Generate unique ID
  static String generateUniqueId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  // Check if string is empty or null
  static bool isEmpty(String? value) {
    return value == null || value.trim().isEmpty;
  }

  // Capitalize first letter
  static String capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  // Get emergency icon based on type
  static IconData getEmergencyIcon(String type) {
    switch (type.toLowerCase()) {
      case 'medical':
        return Icons.local_hospital;
      case 'police':
        return Icons.local_police;
      case 'fire':
        return Icons.local_fire_department;
      case 'sos':
        return Icons.sos;
      default:
        return Icons.emergency;
    }
  }

  // Get emergency color based on type
  static Color getEmergencyColor(String type) {
    switch (type.toLowerCase()) {
      case 'medical':
        return Colors.red;
      case 'police':
        return Colors.blue;
      case 'fire':
        return Colors.orange;
      case 'sos':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}

// Global helper shortcuts
String? validatePhone(String? value) => AppHelpers.validatePhone(value);

String? validateRequired(String? value, String fieldName) =>
    AppHelpers.validateRequired(value, fieldName);

void showSuccessSnackBar(BuildContext context, String message) =>
    AppHelpers.showSuccessSnackBar(context, message);

void showErrorSnackBar(BuildContext context, String message) =>
    AppHelpers.showErrorSnackBar(context, message);
