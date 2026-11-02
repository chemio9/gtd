// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'GTD';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get save => 'Save';

  @override
  String get create => 'Create';

  @override
  String get close => 'Close';

  @override
  String get remove => 'Remove';

  @override
  String get title => 'Title';

  @override
  String get notes => 'Notes';

  @override
  String get name => 'Name';

  @override
  String get undo => 'Undo';

  @override
  String get search => 'Search';

  @override
  String get settings => 'Settings';

  @override
  String get today => 'Today';

  @override
  String get tomorrow => 'Tomorrow';

  @override
  String get noDate => 'No date';

  @override
  String get pickDate => 'Pick a date…';

  @override
  String get navBoard => 'Board';

  @override
  String get navTodos => 'Todos';

  @override
  String get navCalendar => 'Calendar';

  @override
  String get kanbanAddTask => 'Add task';

  @override
  String get kanbanColumnOptions => 'Column options';

  @override
  String get kanbanDropHere => 'Drop tasks here';

  @override
  String get kanbanNoTasks => 'No tasks';

  @override
  String kanbanTaskCount(int count) {
    return '$count';
  }

  @override
  String get kanbanTaskCountDescription => 'Number of tasks in the column';

  @override
  String get boardTitle => 'Board';

  @override
  String get boardNoSelection => 'No board selected';

  @override
  String get boardAddColumn => 'Add column';

  @override
  String get boardNewTask => 'New task';

  @override
  String get boardRenameColumn => 'Rename column';

  @override
  String get boardMarkActive => 'Mark as active column';

  @override
  String get boardMarkDone => 'Mark as done column';

  @override
  String get boardMoveLeft => 'Move left';

  @override
  String get boardMoveRight => 'Move right';

  @override
  String get boardDeleteColumn => 'Delete column';

  @override
  String get boardDeleteColumnHint => 'Tasks move to the first column';

  @override
  String get boardDeleteColumnQuestion => 'Delete column?';

  @override
  String boardDeleteColumnBody(String column) {
    return 'Tasks in \"$column\" will be moved to the first column.';
  }

  @override
  String get boardNewColumn => 'New column';

  @override
  String get boardColumnHint => 'Review';

  @override
  String get boardSwitch => 'Switch board';

  @override
  String get boardNewBoard => 'New board';

  @override
  String get boardDeleteBoard => 'Delete this board';

  @override
  String get boardHint => 'Work';

  @override
  String boardDeleteBoardQuestion(String name) {
    return 'Delete \"$name\"?';
  }

  @override
  String get boardDeleteBoardBody => 'All of its tasks will be deleted too.';

  @override
  String get boardDeleteColumnConfirm => 'Delete';

  @override
  String get boardNewCard => 'New card';

  @override
  String get boardAddCard => 'Add card';

  @override
  String dueLabel(String date) {
    return 'Due $date';
  }

  @override
  String get todosTitle => 'Todos';

  @override
  String get todosMore => 'More';

  @override
  String get todosDetailedTask => 'Detailed task';

  @override
  String get todosPasteList => 'Paste list';

  @override
  String get todosAddTask => 'Add a task';

  @override
  String todosDeletedTask(String title) {
    return 'Deleted \"$title\"';
  }

  @override
  String get todosClipboardEmpty => 'Clipboard is empty';

  @override
  String todosAddedTask(String title) {
    return 'Added \"$title\"';
  }

  @override
  String todosAddedTasks(int count) {
    return 'Added $count tasks';
  }

  @override
  String get todosFilterAll => 'All';

  @override
  String get todosFilterToday => 'Today';

  @override
  String get todosFilterUpcoming => 'Upcoming';

  @override
  String get todosFilterAnytime => 'Anytime';

  @override
  String get todosFilterDone => 'Done';

  @override
  String get todosGroupOverdue => 'Overdue';

  @override
  String get todosGroupToday => 'Today';

  @override
  String get todosGroupTomorrow => 'Tomorrow';

  @override
  String get todosGroupUpcoming => 'Upcoming';

  @override
  String get todosGroupLater => 'Later';

  @override
  String get todosGroupAnytime => 'Anytime';

  @override
  String get todosGroupCompleted => 'Completed';

  @override
  String get todosEmptyCompleted => 'Nothing completed yet.';

  @override
  String get todosEmpty => 'Nothing here. Type above to add a task.';

  @override
  String get todosDeleteTask => 'Delete task?';

  @override
  String todosDeleteTaskBody(String title) {
    return '\"$title\" will be removed permanently.';
  }

  @override
  String get calendarTitle => 'Calendar';

  @override
  String get calendarToday => 'Today';

  @override
  String get calendarMonth => 'Month';

  @override
  String get calendarTwoWeeks => '2 weeks';

  @override
  String get calendarWeek => 'Week';

  @override
  String get calendarNewEvent => 'New event';

  @override
  String get calendarNothingScheduled => 'Nothing scheduled';

  @override
  String get calendarAddEntry => 'Add an entry';

  @override
  String get calendarAllDay => 'All day';

  @override
  String calendarTaskCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tasks',
      one: '1 task',
      zero: 'No tasks',
    );
    return '$_temp0';
  }

  @override
  String get calendarTask => 'Task';

  @override
  String calendarTaskWithTime(String time) {
    return 'Task · $time';
  }

  @override
  String get calendarEventsForTask => 'Linked events';

  @override
  String get eventEditTitle => 'Edit event';

  @override
  String get eventNewTitle => 'New event';

  @override
  String get eventStarts => 'Starts';

  @override
  String get eventEnds => 'Ends';

  @override
  String get eventRepeat => 'Repeat';

  @override
  String get eventRepeatNone => 'Does not repeat';

  @override
  String get eventRepeatDaily => 'Every day';

  @override
  String get eventRepeatWeekly => 'Every week';

  @override
  String get eventRepeatMonthly => 'Every month';

  @override
  String eventUntil(String date) {
    return 'Until $date';
  }

  @override
  String get eventNoEndDate => 'No end date';

  @override
  String get eventClearEndDate => 'Clear end date';

  @override
  String get eventLinkTask => 'Link a task';

  @override
  String get eventUnlinkTask => 'Unlink task';

  @override
  String get eventLinkToTask => 'Link to a task';

  @override
  String get eventSearchTasks => 'Search tasks';

  @override
  String get eventNoTask => 'No task';

  @override
  String get eventNoMatchingTasks => 'No matching tasks';

  @override
  String get eventDeleteQuestion => 'Delete event?';

  @override
  String eventDeleteOne(String title) {
    return '\"$title\" will be removed.';
  }

  @override
  String eventDeleteSeries(String title) {
    return '\"$title\" and all of its repetitions will be removed.';
  }

  @override
  String get eventAllDay => 'All day';

  @override
  String get taskEditTitle => 'Edit task';

  @override
  String get taskNewTitle => 'New task';

  @override
  String get taskPriority => 'Priority';

  @override
  String get taskPriorityLow => 'Low';

  @override
  String get taskPriorityMedium => 'Medium';

  @override
  String get taskPriorityHigh => 'High';

  @override
  String get taskPriorityUrgent => 'Urgent';

  @override
  String get taskAddDueDate => 'Add due date';

  @override
  String get taskAddTime => 'Add time';

  @override
  String get taskClearDueDate => 'Clear due date';

  @override
  String get taskColumn => 'Column';

  @override
  String get taskCompleted => 'Completed';

  @override
  String get taskLinkedEvents => 'LINKED EVENTS';

  @override
  String get taskNoLinkedEvents => 'No calendar event linked to this task yet.';

  @override
  String get taskNewEventShort => 'New event';

  @override
  String get taskDeleteQuestion => 'Delete task?';

  @override
  String taskDeleteBody(String title) {
    return '\"$title\" will be removed permanently.';
  }

  @override
  String get taskReminder => 'Remind me';

  @override
  String get taskReminderNone => 'No reminder';

  @override
  String get taskReminderAtDue => 'At the due time';

  @override
  String get taskReminderNeedsDue => 'Set a due date first';

  @override
  String taskReminderBefore(String label) {
    return '$label before';
  }

  @override
  String taskReminderBody(String title) {
    return '$title is due';
  }

  @override
  String get quickAddHint => 'Add a task';

  @override
  String get quickAddAction => 'Add task';

  @override
  String get quickAddDone => 'Done adding';

  @override
  String get quickAddClearParsed => 'Clear recognised date';

  @override
  String get quickAddDueDate => 'Set due date';

  @override
  String quickAddAddedOne(String title) {
    return 'Added \"$title\"';
  }

  @override
  String quickAddAddedMany(int count) {
    return 'Added $count tasks';
  }

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsSwipe => 'Swipe actions';

  @override
  String get settingsSwipeRight => 'Swipe right';

  @override
  String get settingsSwipeRightHint => 'On a task in the Todos list';

  @override
  String get settingsSwipeLeft => 'Swipe left';

  @override
  String get settingsReminders => 'Reminders';

  @override
  String get settingsDailyReminder => 'Daily reminder';

  @override
  String get settingsDailyReminderHint => 'A notification at your chosen time';

  @override
  String get settingsNotificationsUnsupported =>
      'Not available in the browser build';

  @override
  String get settingsReminderTime => 'Reminder time';

  @override
  String get settingsCalendarSync => 'Calendar sync';

  @override
  String get settingsBackup => 'Backup';

  @override
  String get settingsExport => 'Export';

  @override
  String get settingsExportHint => 'Save boards, tasks and events as JSON';

  @override
  String get settingsImport => 'Import';

  @override
  String get settingsImportHint => 'Replace everything with a backup file';

  @override
  String get settingsAbout => 'About';

  @override
  String get settingsVersion => 'Version';

  @override
  String get settingsLicenses => 'Licenses';

  @override
  String get settingsLicensesHint => 'Open source packages used by GTD';

  @override
  String get settingsDeviceCalendar => 'Device calendar';

  @override
  String get settingsOnlyAndroid => 'Only available on Android';

  @override
  String get settingsDeviceCalendarHint =>
      'Mirror events into a device calendar';

  @override
  String get settingsSyncNow => 'Sync now';

  @override
  String get settingsNotSyncedYet => 'Not synced yet';

  @override
  String settingsLastSynced(String time) {
    return 'Last synced $time';
  }

  @override
  String get settingsRemoveSynced => 'Remove synced events';

  @override
  String get settingsRemoveSyncedHint => 'Delete the copies this app created';

  @override
  String get settingsCalendarPermissionDenied => 'Calendar permission denied';

  @override
  String get settingsNoWritableCalendar => 'No writable calendar';

  @override
  String get settingsNoWritableCalendarBody =>
      'This device has no calendar this app can write to. Create a local \"GTD\" calendar?';

  @override
  String get settingsCouldNotCreateCalendar => 'Could not create a calendar';

  @override
  String settingsCalendarError(String error) {
    return 'Calendar error: $error';
  }

  @override
  String settingsCalendarSynced(String summary) {
    return 'Calendar synced: $summary';
  }

  @override
  String settingsSyncFailed(String error) {
    return 'Sync failed: $error';
  }

  @override
  String get settingsRemoveSyncedQuestion => 'Remove synced events?';

  @override
  String get settingsRemoveSyncedBody =>
      'The copies in your device calendar are deleted. Your GTD events stay in the app.';

  @override
  String settingsRemovedEvents(int count) {
    return 'Removed $count event(s)';
  }

  @override
  String settingsCouldNotRemove(String error) {
    return 'Could not remove events: $error';
  }

  @override
  String get settingsNotificationDenied => 'Notification permission denied';

  @override
  String get settingsDailyReminderEnabled => 'Daily reminder enabled';

  @override
  String settingsCouldNotEnable(String error) {
    return 'Could not enable notifications: $error';
  }

  @override
  String settingsCouldNotReschedule(String error) {
    return 'Could not reschedule reminder: $error';
  }

  @override
  String get settingsBackupNotSaved => 'Backup not saved';

  @override
  String get settingsBackupSaved => 'Backup saved';

  @override
  String settingsExportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String settingsCouldNotOpenFile(String error) {
    return 'Could not open file: $error';
  }

  @override
  String get settingsReplaceAllQuestion => 'Replace all data?';

  @override
  String get settingsReplaceAllBody =>
      'Importing a backup deletes the boards, tasks and events that are currently stored on this device.';

  @override
  String settingsImported(String summary) {
    return 'Imported $summary';
  }

  @override
  String settingsImportFailed(String error) {
    return 'Import failed: $error';
  }

  @override
  String get settingsExportDialogTitle => 'Export GTD backup';

  @override
  String get settingsImportDialogTitle => 'Import GTD backup';

  @override
  String get subtasksTitle => 'Subtasks';

  @override
  String get subtaskAdd => 'Add subtask';

  @override
  String subtaskProgress(int done, int total) {
    return '$done/$total';
  }

  @override
  String get subtaskEmpty => 'No subtasks yet';

  @override
  String get tagsTitle => 'Tags';

  @override
  String get tagAdd => 'Add tag';

  @override
  String get tagNew => 'New tag';

  @override
  String get tagName => 'Tag name';

  @override
  String get tagEmpty => 'No tags yet';

  @override
  String get tagNoMatches => 'No matching tags';

  @override
  String get searchHint => 'Search tasks, events and tags';

  @override
  String get searchTasks => 'Tasks';

  @override
  String get searchEvents => 'Events';

  @override
  String searchNoResults(String query) {
    return 'Nothing found for \"$query\"';
  }
}
