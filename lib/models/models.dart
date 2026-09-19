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
      // Breast-health topics first, so "breast pain" doesn't get the cycle-pain answer
      if (lower.contains('biopsy')) {
        response =
            "A biopsy removes a small sample of tissue, usually with a thin needle under ultrasound guidance and local anaesthetic. It is the only way to confirm whether a lump is benign or cancer, and most biopsies come back benign.";
      } else if (lower.contains('benign') || lower.contains('cyst') || lower.contains('fibroadenoma')) {
        response =
            "Benign means not cancer. Common benign findings are cysts (fluid-filled sacs) and fibroadenomas (firm, smooth lumps of normal tissue). Your doctor may suggest a repeat ultrasound in a few months to check it hasn't changed.";
      } else if (lower.contains('malignant') || lower.contains('suspicious') || lower.contains('cancer')) {
        response =
            "A suspicious result means the scan has features doctors want to look at more closely. It is not a diagnosis. A breast specialist will usually examine you and may recommend a biopsy. Please book that appointment soon rather than waiting.";
      } else if (lower.contains('mammogram') || lower.contains('screening')) {
        response =
            "A mammogram is a low-dose X-ray of the breast. In Pakistan breast cancer is most common between 40 and 50, so ask your doctor about screening every 1 to 2 years from age 40, or earlier if you have a strong family history.";
      } else if (lower.contains('breast') && lower.contains('pain')) {
        response =
            "Breast pain on its own is rarely a sign of cancer and often rises and falls with your cycle. See a doctor if it stays in one spot for more than a few weeks, or if you notice a lump or other change.";
      } else if (lower.contains('self-exam') || lower.contains('self exam') || lower.contains('lump') || lower.contains('breast')) {
        response =
            "Do a self-exam once a month, 3 to 5 days after your period ends. Look in the mirror, then feel each breast and armpit in small circles with light, medium and firm pressure. The Self-Exam Guide on the breast health screen walks you through it.";
      } else if (lower.contains('cramp') || lower.contains('pain')) {
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

  /// Posts a question and a model-generated explanation to the AI companion, then opens it.
  void discussResult({required String question, required String answer}) {
    final now = DateTime.now();
    _chatMessages
      ..add(ChatMessage(id: '${now.millisecondsSinceEpoch}', text: question, isUser: true, timestamp: now))
      ..add(ChatMessage(id: '${now.millisecondsSinceEpoch + 1}', text: answer, isUser: false, timestamp: now));
    _currentTabIndex = 4; // AI companion tab
    notifyListeners();
  }
}
