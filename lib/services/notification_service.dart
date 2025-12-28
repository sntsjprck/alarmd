import 'package:local_notifier/local_notifier.dart';

class NotificationService {
  Future<void> init() async {
    await localNotifier.setup(
      appName: 'Alarmd',
      shortcutPolicy: ShortcutPolicy.requireCreate,
    );
  }

  Future<void> showAlarmNotification({
    required String title,
    required String body,
    void Function()? onDismiss,
    void Function()? onSnooze,
  }) async {
    final notification = LocalNotification(
      title: title,
      body: body,
      actions: [
        LocalNotificationAction(text: 'Dismiss'),
        LocalNotificationAction(text: 'Snooze'),
      ],
    );

    notification.onClickAction = (actionIndex) {
      if (actionIndex == 0) {
        onDismiss?.call();
      } else if (actionIndex == 1) {
        onSnooze?.call();
      }
    };

    notification.onClick = () {
      onDismiss?.call();
    };

    notification.onClose = (reason) {
      if (reason == LocalNotificationCloseReason.timedOut) {
        // Notification timed out - keep alarm ringing
      }
    };

    await notification.show();
  }

  Future<void> showSimpleNotification({
    required String title,
    required String body,
  }) async {
    final notification = LocalNotification(
      title: title,
      body: body,
    );
    await notification.show();
  }
}
