enum Gesture { shake_twice, tap_three_times, long_press }
enum ActionType { sos_emergency, send_location, call_contact, disable_feature } // تم تخمين هذه الإجراءات

extension GestureExtension on Gesture {
  String get displayName {
    switch (this) {
      case Gesture.shake_twice:
        return 'Shake the device twice';
      case Gesture.tap_three_times:
        return 'Tap three times';
      case Gesture.long_press:
        return 'Long press';
    }
  }

  String get codeName => toString().split('.').last;
}

extension ActionTypeExtension on ActionType {
  String get displayName {
    switch (this) {
      case ActionType.sos_emergency:
        return 'SOS Emergency Call';
      case ActionType.send_location:
        return 'Send geographic location';
      case ActionType.call_contact:
        return 'Call emergency contact';
      case ActionType.disable_feature:
        return 'Disable feature (Stop)';
    }
  }

  String get codeName => toString().split('.').last;

  static ActionType fromCodeName(String codeName) {
    return ActionType.values.firstWhere(
          (e) => e.toString().split('.').last == codeName,
      orElse: () => ActionType.disable_feature,
    );
  }
}