import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'GTD'**
  String get appTitle;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @title.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get title;

  /// No description provided for @notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notes;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @tomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get tomorrow;

  /// No description provided for @noDate.
  ///
  /// In en, this message translates to:
  /// **'No date'**
  String get noDate;

  /// No description provided for @pickDate.
  ///
  /// In en, this message translates to:
  /// **'Pick a date…'**
  String get pickDate;

  /// No description provided for @navBoard.
  ///
  /// In en, this message translates to:
  /// **'Board'**
  String get navBoard;

  /// No description provided for @navTodos.
  ///
  /// In en, this message translates to:
  /// **'Todos'**
  String get navTodos;

  /// No description provided for @navCalendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get navCalendar;

  /// No description provided for @kanbanAddTask.
  ///
  /// In en, this message translates to:
  /// **'Add task'**
  String get kanbanAddTask;

  /// No description provided for @kanbanColumnOptions.
  ///
  /// In en, this message translates to:
  /// **'Column options'**
  String get kanbanColumnOptions;

  /// No description provided for @kanbanDropHere.
  ///
  /// In en, this message translates to:
  /// **'Drop tasks here'**
  String get kanbanDropHere;

  /// No description provided for @kanbanNoTasks.
  ///
  /// In en, this message translates to:
  /// **'No tasks'**
  String get kanbanNoTasks;

  /// Number of tasks in the column
  ///
  /// In en, this message translates to:
  /// **'{count}'**
  String kanbanTaskCount(int count);

  /// No description provided for @kanbanTaskCountDescription.
  ///
  /// In en, this message translates to:
  /// **'Number of tasks in the column'**
  String get kanbanTaskCountDescription;

  /// No description provided for @boardTitle.
  ///
  /// In en, this message translates to:
  /// **'Board'**
  String get boardTitle;

  /// No description provided for @boardNoSelection.
  ///
  /// In en, this message translates to:
  /// **'No board selected'**
  String get boardNoSelection;

  /// No description provided for @boardAddColumn.
  ///
  /// In en, this message translates to:
  /// **'Add column'**
  String get boardAddColumn;

  /// No description provided for @boardNewTask.
  ///
  /// In en, this message translates to:
  /// **'New task'**
  String get boardNewTask;

  /// No description provided for @boardRenameColumn.
  ///
  /// In en, this message translates to:
  /// **'Rename column'**
  String get boardRenameColumn;

  /// No description provided for @boardMarkActive.
  ///
  /// In en, this message translates to:
  /// **'Mark as active column'**
  String get boardMarkActive;

  /// No description provided for @boardMarkDone.
  ///
  /// In en, this message translates to:
  /// **'Mark as done column'**
  String get boardMarkDone;

  /// No description provided for @boardMoveLeft.
  ///
  /// In en, this message translates to:
  /// **'Move left'**
  String get boardMoveLeft;

  /// No description provided for @boardMoveRight.
  ///
  /// In en, this message translates to:
  /// **'Move right'**
  String get boardMoveRight;

  /// No description provided for @boardDeleteColumn.
  ///
  /// In en, this message translates to:
  /// **'Delete column'**
  String get boardDeleteColumn;

  /// No description provided for @boardDeleteColumnHint.
  ///
  /// In en, this message translates to:
  /// **'Tasks move to the first column'**
  String get boardDeleteColumnHint;

  /// No description provided for @boardDeleteColumnQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete column?'**
  String get boardDeleteColumnQuestion;

  /// No description provided for @boardDeleteColumnBody.
  ///
  /// In en, this message translates to:
  /// **'Tasks in \"{column}\" will be moved to the first column.'**
  String boardDeleteColumnBody(String column);

  /// No description provided for @boardNewColumn.
  ///
  /// In en, this message translates to:
  /// **'New column'**
  String get boardNewColumn;

  /// No description provided for @boardColumnHint.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get boardColumnHint;

  /// No description provided for @boardSwitch.
  ///
  /// In en, this message translates to:
  /// **'Switch board'**
  String get boardSwitch;

  /// No description provided for @boardNewBoard.
  ///
  /// In en, this message translates to:
  /// **'New board'**
  String get boardNewBoard;

  /// No description provided for @boardDeleteBoard.
  ///
  /// In en, this message translates to:
  /// **'Delete this board'**
  String get boardDeleteBoard;

  /// No description provided for @boardHint.
  ///
  /// In en, this message translates to:
  /// **'Work'**
  String get boardHint;

  /// No description provided for @boardDeleteBoardQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"?'**
  String boardDeleteBoardQuestion(String name);

  /// No description provided for @boardDeleteBoardBody.
  ///
  /// In en, this message translates to:
  /// **'All of its tasks will be deleted too.'**
  String get boardDeleteBoardBody;

  /// No description provided for @boardDeleteColumnConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get boardDeleteColumnConfirm;

  /// No description provided for @boardNewCard.
  ///
  /// In en, this message translates to:
  /// **'New card'**
  String get boardNewCard;

  /// No description provided for @boardAddCard.
  ///
  /// In en, this message translates to:
  /// **'Add card'**
  String get boardAddCard;

  /// No description provided for @dueLabel.
  ///
  /// In en, this message translates to:
  /// **'Due {date}'**
  String dueLabel(String date);

  /// No description provided for @todosTitle.
  ///
  /// In en, this message translates to:
  /// **'Todos'**
  String get todosTitle;

  /// No description provided for @todosMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get todosMore;

  /// No description provided for @todosDetailedTask.
  ///
  /// In en, this message translates to:
  /// **'Detailed task'**
  String get todosDetailedTask;

  /// No description provided for @todosPasteList.
  ///
  /// In en, this message translates to:
  /// **'Paste list'**
  String get todosPasteList;

  /// No description provided for @todosAddTask.
  ///
  /// In en, this message translates to:
  /// **'Add a task'**
  String get todosAddTask;

  /// No description provided for @todosDeletedTask.
  ///
  /// In en, this message translates to:
  /// **'Deleted \"{title}\"'**
  String todosDeletedTask(String title);

  /// No description provided for @todosClipboardEmpty.
  ///
  /// In en, this message translates to:
  /// **'Clipboard is empty'**
  String get todosClipboardEmpty;

  /// No description provided for @todosAddedTask.
  ///
  /// In en, this message translates to:
  /// **'Added \"{title}\"'**
  String todosAddedTask(String title);

  /// No description provided for @todosAddedTasks.
  ///
  /// In en, this message translates to:
  /// **'Added {count} tasks'**
  String todosAddedTasks(int count);

  /// No description provided for @todosFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get todosFilterAll;

  /// No description provided for @todosFilterToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get todosFilterToday;

  /// No description provided for @todosFilterUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get todosFilterUpcoming;

  /// No description provided for @todosFilterAnytime.
  ///
  /// In en, this message translates to:
  /// **'Anytime'**
  String get todosFilterAnytime;

  /// No description provided for @todosFilterDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get todosFilterDone;

  /// No description provided for @todosGroupOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get todosGroupOverdue;

  /// No description provided for @todosGroupToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get todosGroupToday;

  /// No description provided for @todosGroupTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get todosGroupTomorrow;

  /// No description provided for @todosGroupUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get todosGroupUpcoming;

  /// No description provided for @todosGroupLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get todosGroupLater;

  /// No description provided for @todosGroupAnytime.
  ///
  /// In en, this message translates to:
  /// **'Anytime'**
  String get todosGroupAnytime;

  /// No description provided for @todosGroupCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get todosGroupCompleted;

  /// No description provided for @todosEmptyCompleted.
  ///
  /// In en, this message translates to:
  /// **'Nothing completed yet.'**
  String get todosEmptyCompleted;

  /// No description provided for @todosEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing here. Type above to add a task.'**
  String get todosEmpty;

  /// No description provided for @todosDeleteTask.
  ///
  /// In en, this message translates to:
  /// **'Delete task?'**
  String get todosDeleteTask;

  /// No description provided for @todosDeleteTaskBody.
  ///
  /// In en, this message translates to:
  /// **'\"{title}\" will be removed permanently.'**
  String todosDeleteTaskBody(String title);

  /// No description provided for @calendarTitle.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get calendarTitle;

  /// No description provided for @calendarToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get calendarToday;

  /// No description provided for @calendarMonth.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get calendarMonth;

  /// No description provided for @calendarTwoWeeks.
  ///
  /// In en, this message translates to:
  /// **'2 weeks'**
  String get calendarTwoWeeks;

  /// No description provided for @calendarWeek.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get calendarWeek;

  /// No description provided for @calendarNewEvent.
  ///
  /// In en, this message translates to:
  /// **'New event'**
  String get calendarNewEvent;

  /// No description provided for @calendarNothingScheduled.
  ///
  /// In en, this message translates to:
  /// **'Nothing scheduled'**
  String get calendarNothingScheduled;

  /// No description provided for @calendarAddEntry.
  ///
  /// In en, this message translates to:
  /// **'Add an entry'**
  String get calendarAddEntry;

  /// No description provided for @calendarAllDay.
  ///
  /// In en, this message translates to:
  /// **'All day'**
  String get calendarAllDay;

  /// No description provided for @calendarTaskCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No tasks} =1{1 task} other{{count} tasks}}'**
  String calendarTaskCount(int count);

  /// No description provided for @calendarTask.
  ///
  /// In en, this message translates to:
  /// **'Task'**
  String get calendarTask;

  /// No description provided for @calendarTaskWithTime.
  ///
  /// In en, this message translates to:
  /// **'Task · {time}'**
  String calendarTaskWithTime(String time);

  /// No description provided for @calendarEventsForTask.
  ///
  /// In en, this message translates to:
  /// **'Linked events'**
  String get calendarEventsForTask;

  /// No description provided for @eventEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit event'**
  String get eventEditTitle;

  /// No description provided for @eventNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New event'**
  String get eventNewTitle;

  /// No description provided for @eventStarts.
  ///
  /// In en, this message translates to:
  /// **'Starts'**
  String get eventStarts;

  /// No description provided for @eventEnds.
  ///
  /// In en, this message translates to:
  /// **'Ends'**
  String get eventEnds;

  /// No description provided for @eventRepeat.
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get eventRepeat;

  /// No description provided for @eventRepeatNone.
  ///
  /// In en, this message translates to:
  /// **'Does not repeat'**
  String get eventRepeatNone;

  /// No description provided for @eventRepeatDaily.
  ///
  /// In en, this message translates to:
  /// **'Every day'**
  String get eventRepeatDaily;

  /// No description provided for @eventRepeatWeekly.
  ///
  /// In en, this message translates to:
  /// **'Every week'**
  String get eventRepeatWeekly;

  /// No description provided for @eventRepeatMonthly.
  ///
  /// In en, this message translates to:
  /// **'Every month'**
  String get eventRepeatMonthly;

  /// No description provided for @eventUntil.
  ///
  /// In en, this message translates to:
  /// **'Until {date}'**
  String eventUntil(String date);

  /// No description provided for @eventNoEndDate.
  ///
  /// In en, this message translates to:
  /// **'No end date'**
  String get eventNoEndDate;

  /// No description provided for @eventClearEndDate.
  ///
  /// In en, this message translates to:
  /// **'Clear end date'**
  String get eventClearEndDate;

  /// No description provided for @eventLinkTask.
  ///
  /// In en, this message translates to:
  /// **'Link a task'**
  String get eventLinkTask;

  /// No description provided for @eventUnlinkTask.
  ///
  /// In en, this message translates to:
  /// **'Unlink task'**
  String get eventUnlinkTask;

  /// No description provided for @eventLinkToTask.
  ///
  /// In en, this message translates to:
  /// **'Link to a task'**
  String get eventLinkToTask;

  /// No description provided for @eventSearchTasks.
  ///
  /// In en, this message translates to:
  /// **'Search tasks'**
  String get eventSearchTasks;

  /// No description provided for @eventNoTask.
  ///
  /// In en, this message translates to:
  /// **'No task'**
  String get eventNoTask;

  /// No description provided for @eventNoMatchingTasks.
  ///
  /// In en, this message translates to:
  /// **'No matching tasks'**
  String get eventNoMatchingTasks;

  /// No description provided for @eventDeleteQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete event?'**
  String get eventDeleteQuestion;

  /// No description provided for @eventDeleteOne.
  ///
  /// In en, this message translates to:
  /// **'\"{title}\" will be removed.'**
  String eventDeleteOne(String title);

  /// No description provided for @eventDeleteSeries.
  ///
  /// In en, this message translates to:
  /// **'\"{title}\" and all of its repetitions will be removed.'**
  String eventDeleteSeries(String title);

  /// No description provided for @eventAllDay.
  ///
  /// In en, this message translates to:
  /// **'All day'**
  String get eventAllDay;

  /// No description provided for @taskEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit task'**
  String get taskEditTitle;

  /// No description provided for @taskNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New task'**
  String get taskNewTitle;

  /// No description provided for @taskPriority.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get taskPriority;

  /// No description provided for @taskPriorityLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get taskPriorityLow;

  /// No description provided for @taskPriorityMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get taskPriorityMedium;

  /// No description provided for @taskPriorityHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get taskPriorityHigh;

  /// No description provided for @taskPriorityUrgent.
  ///
  /// In en, this message translates to:
  /// **'Urgent'**
  String get taskPriorityUrgent;

  /// No description provided for @taskAddDueDate.
  ///
  /// In en, this message translates to:
  /// **'Add due date'**
  String get taskAddDueDate;

  /// No description provided for @taskAddTime.
  ///
  /// In en, this message translates to:
  /// **'Add time'**
  String get taskAddTime;

  /// No description provided for @taskClearDueDate.
  ///
  /// In en, this message translates to:
  /// **'Clear due date'**
  String get taskClearDueDate;

  /// No description provided for @taskColumn.
  ///
  /// In en, this message translates to:
  /// **'Column'**
  String get taskColumn;

  /// No description provided for @taskCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get taskCompleted;

  /// No description provided for @taskLinkedEvents.
  ///
  /// In en, this message translates to:
  /// **'LINKED EVENTS'**
  String get taskLinkedEvents;

  /// No description provided for @taskNoLinkedEvents.
  ///
  /// In en, this message translates to:
  /// **'No calendar event linked to this task yet.'**
  String get taskNoLinkedEvents;

  /// No description provided for @taskNewEventShort.
  ///
  /// In en, this message translates to:
  /// **'New event'**
  String get taskNewEventShort;

  /// No description provided for @taskDeleteQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete task?'**
  String get taskDeleteQuestion;

  /// No description provided for @taskDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'\"{title}\" will be removed permanently.'**
  String taskDeleteBody(String title);

  /// No description provided for @taskReminder.
  ///
  /// In en, this message translates to:
  /// **'Remind me'**
  String get taskReminder;

  /// No description provided for @taskReminderNone.
  ///
  /// In en, this message translates to:
  /// **'No reminder'**
  String get taskReminderNone;

  /// No description provided for @taskReminderAtDue.
  ///
  /// In en, this message translates to:
  /// **'At the due time'**
  String get taskReminderAtDue;

  /// No description provided for @taskReminderNeedsDue.
  ///
  /// In en, this message translates to:
  /// **'Set a due date to add a reminder'**
  String get taskReminderNeedsDue;

  /// No description provided for @taskReminderBefore.
  ///
  /// In en, this message translates to:
  /// **'{label} before'**
  String taskReminderBefore(String label);

  /// No description provided for @taskReminderBody.
  ///
  /// In en, this message translates to:
  /// **'{title} is due'**
  String taskReminderBody(String title);

  /// No description provided for @quickAddHint.
  ///
  /// In en, this message translates to:
  /// **'Add a task'**
  String get quickAddHint;

  /// No description provided for @quickAddAction.
  ///
  /// In en, this message translates to:
  /// **'Add task'**
  String get quickAddAction;

  /// No description provided for @quickAddDone.
  ///
  /// In en, this message translates to:
  /// **'Done adding'**
  String get quickAddDone;

  /// No description provided for @quickAddClearParsed.
  ///
  /// In en, this message translates to:
  /// **'Clear recognised date'**
  String get quickAddClearParsed;

  /// No description provided for @quickAddDueDate.
  ///
  /// In en, this message translates to:
  /// **'Set due date'**
  String get quickAddDueDate;

  /// No description provided for @quickAddAddedOne.
  ///
  /// In en, this message translates to:
  /// **'Added \"{title}\"'**
  String quickAddAddedOne(String title);

  /// No description provided for @quickAddAddedMany.
  ///
  /// In en, this message translates to:
  /// **'Added {count} tasks'**
  String quickAddAddedMany(int count);

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsSwipe.
  ///
  /// In en, this message translates to:
  /// **'Swipe actions'**
  String get settingsSwipe;

  /// No description provided for @settingsSwipeRight.
  ///
  /// In en, this message translates to:
  /// **'Swipe right'**
  String get settingsSwipeRight;

  /// No description provided for @settingsSwipeRightHint.
  ///
  /// In en, this message translates to:
  /// **'On a task in the Todos list'**
  String get settingsSwipeRightHint;

  /// No description provided for @settingsSwipeLeft.
  ///
  /// In en, this message translates to:
  /// **'Swipe left'**
  String get settingsSwipeLeft;

  /// No description provided for @settingsReminders.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get settingsReminders;

  /// No description provided for @settingsDailyReminder.
  ///
  /// In en, this message translates to:
  /// **'Daily reminder'**
  String get settingsDailyReminder;

  /// No description provided for @settingsDailyReminderHint.
  ///
  /// In en, this message translates to:
  /// **'A notification at your chosen time'**
  String get settingsDailyReminderHint;

  /// No description provided for @settingsNotificationsUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Not available in the browser build'**
  String get settingsNotificationsUnsupported;

  /// No description provided for @settingsReminderTime.
  ///
  /// In en, this message translates to:
  /// **'Reminder time'**
  String get settingsReminderTime;

  /// No description provided for @settingsCalendarSync.
  ///
  /// In en, this message translates to:
  /// **'Calendar sync'**
  String get settingsCalendarSync;

  /// No description provided for @settingsBackup.
  ///
  /// In en, this message translates to:
  /// **'Backup'**
  String get settingsBackup;

  /// No description provided for @settingsExport.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get settingsExport;

  /// No description provided for @settingsExportHint.
  ///
  /// In en, this message translates to:
  /// **'Save boards, tasks and events as JSON'**
  String get settingsExportHint;

  /// No description provided for @settingsImport.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get settingsImport;

  /// No description provided for @settingsImportHint.
  ///
  /// In en, this message translates to:
  /// **'Replace everything with a backup file'**
  String get settingsImportHint;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @settingsVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get settingsVersion;

  /// No description provided for @settingsLicenses.
  ///
  /// In en, this message translates to:
  /// **'Licenses'**
  String get settingsLicenses;

  /// No description provided for @settingsLicensesHint.
  ///
  /// In en, this message translates to:
  /// **'Open source packages used by GTD'**
  String get settingsLicensesHint;

  /// No description provided for @settingsDeviceCalendar.
  ///
  /// In en, this message translates to:
  /// **'Device calendar'**
  String get settingsDeviceCalendar;

  /// No description provided for @settingsOnlyAndroid.
  ///
  /// In en, this message translates to:
  /// **'Only available on Android'**
  String get settingsOnlyAndroid;

  /// No description provided for @settingsDeviceCalendarHint.
  ///
  /// In en, this message translates to:
  /// **'Mirror events into a device calendar'**
  String get settingsDeviceCalendarHint;

  /// No description provided for @settingsSyncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync now'**
  String get settingsSyncNow;

  /// No description provided for @settingsNotSyncedYet.
  ///
  /// In en, this message translates to:
  /// **'Not synced yet'**
  String get settingsNotSyncedYet;

  /// No description provided for @settingsLastSynced.
  ///
  /// In en, this message translates to:
  /// **'Last synced {time}'**
  String settingsLastSynced(String time);

  /// No description provided for @settingsRemoveSynced.
  ///
  /// In en, this message translates to:
  /// **'Remove synced events'**
  String get settingsRemoveSynced;

  /// No description provided for @settingsRemoveSyncedHint.
  ///
  /// In en, this message translates to:
  /// **'Delete the copies this app created'**
  String get settingsRemoveSyncedHint;

  /// No description provided for @settingsCalendarPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Calendar permission denied'**
  String get settingsCalendarPermissionDenied;

  /// No description provided for @settingsNoWritableCalendar.
  ///
  /// In en, this message translates to:
  /// **'No writable calendar'**
  String get settingsNoWritableCalendar;

  /// No description provided for @settingsNoWritableCalendarBody.
  ///
  /// In en, this message translates to:
  /// **'This device has no calendar this app can write to. Create a local \"GTD\" calendar?'**
  String get settingsNoWritableCalendarBody;

  /// No description provided for @settingsCouldNotCreateCalendar.
  ///
  /// In en, this message translates to:
  /// **'Could not create a calendar'**
  String get settingsCouldNotCreateCalendar;

  /// No description provided for @settingsCalendarError.
  ///
  /// In en, this message translates to:
  /// **'Calendar error: {error}'**
  String settingsCalendarError(String error);

  /// No description provided for @settingsCalendarSynced.
  ///
  /// In en, this message translates to:
  /// **'Calendar synced: {summary}'**
  String settingsCalendarSynced(String summary);

  /// No description provided for @settingsSyncFailed.
  ///
  /// In en, this message translates to:
  /// **'Sync failed: {error}'**
  String settingsSyncFailed(String error);

  /// No description provided for @settingsRemoveSyncedQuestion.
  ///
  /// In en, this message translates to:
  /// **'Remove synced events?'**
  String get settingsRemoveSyncedQuestion;

  /// No description provided for @settingsRemoveSyncedBody.
  ///
  /// In en, this message translates to:
  /// **'The copies in your device calendar are deleted. Your GTD events stay in the app.'**
  String get settingsRemoveSyncedBody;

  /// No description provided for @settingsRemovedEvents.
  ///
  /// In en, this message translates to:
  /// **'Removed {count} event(s)'**
  String settingsRemovedEvents(int count);

  /// No description provided for @settingsCouldNotRemove.
  ///
  /// In en, this message translates to:
  /// **'Could not remove events: {error}'**
  String settingsCouldNotRemove(String error);

  /// No description provided for @settingsNotificationDenied.
  ///
  /// In en, this message translates to:
  /// **'Notification permission denied'**
  String get settingsNotificationDenied;

  /// No description provided for @settingsDailyReminderEnabled.
  ///
  /// In en, this message translates to:
  /// **'Daily reminder enabled'**
  String get settingsDailyReminderEnabled;

  /// No description provided for @settingsCouldNotEnable.
  ///
  /// In en, this message translates to:
  /// **'Could not enable notifications: {error}'**
  String settingsCouldNotEnable(String error);

  /// No description provided for @settingsCouldNotReschedule.
  ///
  /// In en, this message translates to:
  /// **'Could not reschedule reminder: {error}'**
  String settingsCouldNotReschedule(String error);

  /// No description provided for @settingsBackupNotSaved.
  ///
  /// In en, this message translates to:
  /// **'Backup not saved'**
  String get settingsBackupNotSaved;

  /// No description provided for @settingsBackupSaved.
  ///
  /// In en, this message translates to:
  /// **'Backup saved'**
  String get settingsBackupSaved;

  /// No description provided for @settingsExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed: {error}'**
  String settingsExportFailed(String error);

  /// No description provided for @settingsCouldNotOpenFile.
  ///
  /// In en, this message translates to:
  /// **'Could not open file: {error}'**
  String settingsCouldNotOpenFile(String error);

  /// No description provided for @settingsReplaceAllQuestion.
  ///
  /// In en, this message translates to:
  /// **'Replace all data?'**
  String get settingsReplaceAllQuestion;

  /// No description provided for @settingsReplaceAllBody.
  ///
  /// In en, this message translates to:
  /// **'Importing a backup deletes the boards, tasks and events that are currently stored on this device.'**
  String get settingsReplaceAllBody;

  /// No description provided for @settingsImported.
  ///
  /// In en, this message translates to:
  /// **'Imported {summary}'**
  String settingsImported(String summary);

  /// No description provided for @settingsImportFailed.
  ///
  /// In en, this message translates to:
  /// **'Import failed: {error}'**
  String settingsImportFailed(String error);

  /// No description provided for @settingsExportDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Export GTD backup'**
  String get settingsExportDialogTitle;

  /// No description provided for @settingsImportDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Import GTD backup'**
  String get settingsImportDialogTitle;

  /// No description provided for @subtasksTitle.
  ///
  /// In en, this message translates to:
  /// **'Subtasks'**
  String get subtasksTitle;

  /// No description provided for @subtaskAdd.
  ///
  /// In en, this message translates to:
  /// **'Add subtask'**
  String get subtaskAdd;

  /// No description provided for @subtaskProgress.
  ///
  /// In en, this message translates to:
  /// **'{done}/{total}'**
  String subtaskProgress(int done, int total);

  /// No description provided for @subtaskEmpty.
  ///
  /// In en, this message translates to:
  /// **'No subtasks yet'**
  String get subtaskEmpty;

  /// No description provided for @tagsTitle.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get tagsTitle;

  /// No description provided for @tagAdd.
  ///
  /// In en, this message translates to:
  /// **'Add tag'**
  String get tagAdd;

  /// No description provided for @tagNew.
  ///
  /// In en, this message translates to:
  /// **'New tag'**
  String get tagNew;

  /// No description provided for @tagName.
  ///
  /// In en, this message translates to:
  /// **'Tag name'**
  String get tagName;

  /// No description provided for @tagEmpty.
  ///
  /// In en, this message translates to:
  /// **'No tags yet'**
  String get tagEmpty;

  /// No description provided for @tagNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No matching tags'**
  String get tagNoMatches;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search tasks, events and tags'**
  String get searchHint;

  /// No description provided for @searchTasks.
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get searchTasks;

  /// No description provided for @searchEvents.
  ///
  /// In en, this message translates to:
  /// **'Events'**
  String get searchEvents;

  /// No description provided for @searchNoResults.
  ///
  /// In en, this message translates to:
  /// **'Nothing found for \"{query}\"'**
  String searchNoResults(String query);

  /// No description provided for @reminderBefore5m.
  ///
  /// In en, this message translates to:
  /// **'5 minutes before'**
  String get reminderBefore5m;

  /// No description provided for @reminderBefore15m.
  ///
  /// In en, this message translates to:
  /// **'15 minutes before'**
  String get reminderBefore15m;

  /// No description provided for @reminderBefore1h.
  ///
  /// In en, this message translates to:
  /// **'1 hour before'**
  String get reminderBefore1h;

  /// No description provided for @reminderBefore3h.
  ///
  /// In en, this message translates to:
  /// **'3 hours before'**
  String get reminderBefore3h;

  /// No description provided for @reminderBefore1d.
  ///
  /// In en, this message translates to:
  /// **'1 day before'**
  String get reminderBefore1d;

  /// No description provided for @reminderNotificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Reminder'**
  String get reminderNotificationTitle;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @subtaskEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit subtask'**
  String get subtaskEdit;

  /// No description provided for @todosGroupBySubject.
  ///
  /// In en, this message translates to:
  /// **'Group by subject'**
  String get todosGroupBySubject;

  /// No description provided for @todosGroupByDay.
  ///
  /// In en, this message translates to:
  /// **'Group by due date'**
  String get todosGroupByDay;

  /// No description provided for @todosUncategorized.
  ///
  /// In en, this message translates to:
  /// **'Uncategorized'**
  String get todosUncategorized;

  /// No description provided for @todosFilterBySubject.
  ///
  /// In en, this message translates to:
  /// **'Show only this subject'**
  String get todosFilterBySubject;

  /// No description provided for @todosShowAllSubjects.
  ///
  /// In en, this message translates to:
  /// **'Show all subjects'**
  String get todosShowAllSubjects;

  /// No description provided for @todosSelectTasks.
  ///
  /// In en, this message translates to:
  /// **'Select tasks'**
  String get todosSelectTasks;

  /// No description provided for @todosSelectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No tasks selected} =1{1 task selected} other{{count} tasks selected}}'**
  String todosSelectedCount(int count);

  /// No description provided for @todosSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get todosSelectAll;

  /// No description provided for @todosClearSelection.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get todosClearSelection;

  /// No description provided for @todosBulkToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get todosBulkToday;

  /// No description provided for @todosBulkTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get todosBulkTomorrow;

  /// No description provided for @todosBulkPickDate.
  ///
  /// In en, this message translates to:
  /// **'Pick a date'**
  String get todosBulkPickDate;

  /// No description provided for @todosBulkClearDate.
  ///
  /// In en, this message translates to:
  /// **'Remove due date'**
  String get todosBulkClearDate;

  /// No description provided for @todosBulkComplete.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get todosBulkComplete;

  /// No description provided for @todosBulkReopen.
  ///
  /// In en, this message translates to:
  /// **'Mark incomplete'**
  String get todosBulkReopen;

  /// No description provided for @todosBulkDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get todosBulkDelete;

  /// No description provided for @todosBulkTags.
  ///
  /// In en, this message translates to:
  /// **'Add tags'**
  String get todosBulkTags;

  /// No description provided for @todosBulkUpdated.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Updated 1 task} other{Updated {count} tasks}}'**
  String todosBulkUpdated(int count);

  /// No description provided for @todosBulkDeleted.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Deleted 1 task} other{Deleted {count} tasks}}'**
  String todosBulkDeleted(int count);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
