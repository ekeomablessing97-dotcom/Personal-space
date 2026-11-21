import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AppFormatters {
  static String greetingForHour(int hour) {
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  static String fullDate(DateTime date) =>
      DateFormat('EEEE, d MMMM y').format(date);

  static String shortDate(DateTime date) =>
      DateFormat('d MMM y').format(date);

  static String dateTime(DateTime date) =>
      DateFormat('d MMM y • HH:mm').format(date);

  static String timeOnly(DateTime date) => DateFormat('HH:mm').format(date);

  static String dateKey(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  static String relativeDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final diff = target.difference(today).inDays;

    if (diff == 0) return 'Today, ${timeOnly(date)}';
    if (diff == -1) return 'Yesterday, ${timeOnly(date)}';
    if (diff == 1) return 'Tomorrow, ${timeOnly(date)}';
    if (diff > 1 && diff <= 7) return DateFormat('EEEE').format(date);
    return shortDate(date);
  }

  static String durationFromMs(int ms) {
    final totalSeconds = (ms / 1000).round();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  static Color hexToColor(String hex, {Color fallback = const Color(0xFFC85A32)}) {
    final clean = hex.replaceAll('#', '').trim();
    if (clean.length == 6) {
      final value = int.tryParse('FF$clean', radix: 16);
      if (value != null) return Color(value);
    } else if (clean.length == 8) {
      final value = int.tryParse(clean, radix: 16);
      if (value != null) return Color(value);
    }
    return fallback;
  }

  static String colorToHex(Color color) {
    final rgb = color.toARGB32() & 0x00FFFFFF;
    return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  static String stripMarkdown(String input) {
    return input
        .replaceAll(RegExp(r'^#{1,6}\s*', multiLine: true), '')
        .replaceAll('**', '')
        .replaceAll('*', '')
        .replaceAll(RegExp(r'^\s*[-•]\s+', multiLine: true), '')
        .replaceAll(RegExp(r'^\s*\d+\.\s+', multiLine: true), '')
        .trim();
  }
}
