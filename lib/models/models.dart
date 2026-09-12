import 'package:flutter/material.dart';

class SymptomItem {
  final String id;
  final String name;
  final IconData icon;
  bool isSelected;

  SymptomItem({
    required this.id,
    required this.name,
    required this.icon,
    this.isSelected = false,
  });
}

class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}

class AppState extends ChangeNotifier {
  int _currentTabIndex = 0;
  int get currentTabIndex => _currentTabIndex;

  int _selectedCalendarDay = 10;
  int get selectedCalendarDay => _selectedCalendarDay;

  String _userNotes = "";
  String get userNotes => _userNotes;

  bool _isScanning = false;
  bool get isScanning => _isScanning;

  bool _hasScanResult = true;
  bool get hasScanResult => _hasScanResult;

  final List<SymptomItem> _symptoms = [
    SymptomItem(id: 'cramps', name: 'Cramps', icon: Icons.water_drop_outlined),
    SymptomItem(id: 'bloating', name: 'Bloating', icon: Icons.bubble_chart_outlined),
    SymptomItem(id: 'headache', name: 'Headache', icon: Icons.sentiment_dissatisfied_outlined),
    SymptomItem(id: 'fatigue', name: 'Fatigue', icon: Icons.battery_alert_outlined),
    SymptomItem(id: 'acne', name: 'Acne', icon: Icons.auto_awesome_outlined, isSelected: true),
    SymptomItem(id: 'backache', name: 'Backache', icon: Icons.accessibility_new_outlined),
    SymptomItem(id: 'tender', name: 'Tender', icon: Icons.spa_outlined),
    SymptomItem(id: 'nausea', name: 'Nausea', icon: Icons.sick_outlined),
  ];

  List<SymptomItem> get symptoms => _symptoms;

  final List<ChatMessage> _chatMessages = [
    ChatMessage(
      id: '1',
      text:
          'Mild cramps are normal during the luteal phase due to rising progesterone levels as your body prepares for a potential pregnancy.',
      isUser: false,
      timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
    ),
    ChatMessage(
      id: '2',
      text: 'Is it normal to feel extra tired today?',
      isUser: true,
      timestamp: DateTime.now().subtract(const Duration(minutes: 2)),
    ),
    ChatMessage(
      id: '3',
      text:
          'Yes, increased fatigue is very common right now due to peak progesterone and metabolic demands. Prioritize hydration and 20-minute rest intervals.',
      isUser: false,
      timestamp: DateTime.now().subtract(const Duration(minutes: 1)),
    ),
  ];

  List<ChatMessage> get chatMessages => _chatMessages;

  void setTab(int index) {
    _currentTabIndex = index;
    notifyListeners();
  }

  void selectCalendarDay(int day) {
    _selectedCalendarDay = day;
    notifyListeners();
  }

  void toggleSymptom(String id) {
    final index = _symptoms.indexWhere((s) => s.id == id);
    if (index != -1) {
      _symptoms[index].isSelected = !_symptoms[index].isSelected;
      notifyListeners();
    }
  }

  void updateNotes(String notes) {
    _userNotes = notes;
  }

  void saveDailyLog() {
    notifyListeners();
  }

  void sendMessage(String text) {
    if (text.trim().isEmpty) return;

    _chatMessages.add(
      ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: text.trim(),
        isUser: true,
        timestamp: DateTime.now(),
      ),
    );
    notifyListeners();

    // Responsive AI companion reply simulation
    Future.delayed(const Duration(milliseconds: 900), () {
      String response =
          "Thanks for sharing. Based on your current Cycle Day 12 and follicular stage, estrogen levels are rising. Staying hydrated and eating balanced meals will support your optimal energy.";
      
      final lower = text.toLowerCase();
      if (lower.contains('cramp') || lower.contains('pain')) {
        response =
            "Mild pelvic sensations or twinges around day 12 can indicate impending ovulation (Mittelschmerz). Warm tea and gentle stretching help relieve discomfort.";
      } else if (lower.contains('pregnan') || lower.contains('baby') || lower.contains('trimester')) {
        response =
            "In your 2nd trimester (Week 16), baby's bones are hardening and facial muscles are developing. Keep monitoring any sudden swelling or blood pressure shifts.";
      } else if (lower.contains('pcos') || lower.contains('diet') || lower.contains('food')) {
        response =
            "With PCOS management, pairing complex fiber with lean protein helps mitigate insulin spikes and regulates LH-to-FSH ratios.";
      }

      _chatMessages.add(
        ChatMessage(
          id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
          text: response,
          isUser: false,
          timestamp: DateTime.now(),
        ),
      );
      notifyListeners();
    });
  }

  void triggerScan() {
    _isScanning = true;
    notifyListeners();

    Future.delayed(const Duration(seconds: 2), () {
      _isScanning = false;
      _hasScanResult = true;
      notifyListeners();
    });
  }
}
