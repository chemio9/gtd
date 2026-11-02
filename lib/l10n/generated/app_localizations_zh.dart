// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'GTD';

  @override
  String get cancel => '取消';

  @override
  String get delete => '删除';

  @override
  String get save => '保存';

  @override
  String get create => '创建';

  @override
  String get close => '关闭';

  @override
  String get remove => '移除';

  @override
  String get title => '标题';

  @override
  String get notes => '备注';

  @override
  String get name => '名称';

  @override
  String get undo => '撤销';

  @override
  String get search => '搜索';

  @override
  String get settings => '设置';

  @override
  String get today => '今天';

  @override
  String get tomorrow => '明天';

  @override
  String get noDate => '无日期';

  @override
  String get pickDate => '选择日期…';

  @override
  String get navBoard => '看板';

  @override
  String get navTodos => '待办';

  @override
  String get navCalendar => '日历';

  @override
  String get kanbanAddTask => '添加任务';

  @override
  String get kanbanColumnOptions => '列选项';

  @override
  String get kanbanDropHere => '拖放任务到这里';

  @override
  String get kanbanNoTasks => '暂无任务';

  @override
  String kanbanTaskCount(int count) {
    return '$count';
  }

  @override
  String get kanbanTaskCountDescription => '该列任务数量';

  @override
  String get boardTitle => '看板';

  @override
  String get boardNoSelection => '未选择看板';

  @override
  String get boardAddColumn => '添加列';

  @override
  String get boardNewTask => '新任务';

  @override
  String get boardRenameColumn => '重命名列';

  @override
  String get boardMarkActive => '设为进行中列';

  @override
  String get boardMarkDone => '设为完成列';

  @override
  String get boardMoveLeft => '左移';

  @override
  String get boardMoveRight => '右移';

  @override
  String get boardDeleteColumn => '删除列';

  @override
  String get boardDeleteColumnHint => '任务会移动到第一列';

  @override
  String get boardDeleteColumnQuestion => '删除该列？';

  @override
  String boardDeleteColumnBody(String column) {
    return '“$column”中的任务将移动到第一列。';
  }

  @override
  String get boardNewColumn => '新建列';

  @override
  String get boardColumnHint => '复盘';

  @override
  String get boardSwitch => '切换看板';

  @override
  String get boardNewBoard => '新建看板';

  @override
  String get boardDeleteBoard => '删除此看板';

  @override
  String get boardHint => '工作';

  @override
  String boardDeleteBoardQuestion(String name) {
    return '删除“$name”？';
  }

  @override
  String get boardDeleteBoardBody => '其中的任务也会一并删除。';

  @override
  String get boardDeleteColumnConfirm => '删除';

  @override
  String get boardNewCard => '新卡片';

  @override
  String get boardAddCard => '添加卡片';

  @override
  String dueLabel(String date) {
    return '$date 到期';
  }

  @override
  String get todosTitle => '待办';

  @override
  String get todosMore => '更多';

  @override
  String get todosDetailedTask => '详细任务';

  @override
  String get todosPasteList => '粘贴清单';

  @override
  String get todosAddTask => '添加任务';

  @override
  String todosDeletedTask(String title) {
    return '已删除“$title”';
  }

  @override
  String get todosClipboardEmpty => '剪贴板为空';

  @override
  String todosAddedTask(String title) {
    return '已添加“$title”';
  }

  @override
  String todosAddedTasks(int count) {
    return '已添加 $count 个任务';
  }

  @override
  String get todosFilterAll => '全部';

  @override
  String get todosFilterToday => '今天';

  @override
  String get todosFilterUpcoming => '即将到来';

  @override
  String get todosFilterAnytime => '随时';

  @override
  String get todosFilterDone => '已完成';

  @override
  String get todosGroupOverdue => '已逾期';

  @override
  String get todosGroupToday => '今天';

  @override
  String get todosGroupTomorrow => '明天';

  @override
  String get todosGroupUpcoming => '即将到来';

  @override
  String get todosGroupLater => '稍后';

  @override
  String get todosGroupAnytime => '随时';

  @override
  String get todosGroupCompleted => '已完成';

  @override
  String get todosEmptyCompleted => '还没有已完成的任务。';

  @override
  String get todosEmpty => '这里空空如也。在上方输入即可添加任务。';

  @override
  String get todosDeleteTask => '删除任务？';

  @override
  String todosDeleteTaskBody(String title) {
    return '“$title”将被永久删除。';
  }

  @override
  String get calendarTitle => '日历';

  @override
  String get calendarToday => '今天';

  @override
  String get calendarMonth => '月';

  @override
  String get calendarTwoWeeks => '两周';

  @override
  String get calendarWeek => '周';

  @override
  String get calendarNewEvent => '新建事件';

  @override
  String get calendarNothingScheduled => '暂无安排';

  @override
  String get calendarAddEntry => '添加安排';

  @override
  String get calendarAllDay => '全天';

  @override
  String calendarTaskCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个任务',
      one: '1 个任务',
      zero: '无任务',
    );
    return '$_temp0';
  }

  @override
  String get calendarTask => '任务';

  @override
  String calendarTaskWithTime(String time) {
    return '任务 · $time';
  }

  @override
  String get calendarEventsForTask => '关联事件';

  @override
  String get eventEditTitle => '编辑事件';

  @override
  String get eventNewTitle => '新建事件';

  @override
  String get eventStarts => '开始';

  @override
  String get eventEnds => '结束';

  @override
  String get eventRepeat => '重复';

  @override
  String get eventRepeatNone => '不重复';

  @override
  String get eventRepeatDaily => '每天';

  @override
  String get eventRepeatWeekly => '每周';

  @override
  String get eventRepeatMonthly => '每月';

  @override
  String eventUntil(String date) {
    return '截止 $date';
  }

  @override
  String get eventNoEndDate => '无结束日期';

  @override
  String get eventClearEndDate => '清除结束日期';

  @override
  String get eventLinkTask => '关联任务';

  @override
  String get eventUnlinkTask => '取消关联';

  @override
  String get eventLinkToTask => '关联到任务';

  @override
  String get eventSearchTasks => '搜索任务';

  @override
  String get eventNoTask => '无任务';

  @override
  String get eventNoMatchingTasks => '没有匹配的任务';

  @override
  String get eventDeleteQuestion => '删除事件？';

  @override
  String eventDeleteOne(String title) {
    return '“$title”将被删除。';
  }

  @override
  String eventDeleteSeries(String title) {
    return '“$title”及其所有重复事件都将被删除。';
  }

  @override
  String get eventAllDay => '全天';

  @override
  String get taskEditTitle => '编辑任务';

  @override
  String get taskNewTitle => '新建任务';

  @override
  String get taskPriority => '优先级';

  @override
  String get taskPriorityLow => '低';

  @override
  String get taskPriorityMedium => '中';

  @override
  String get taskPriorityHigh => '高';

  @override
  String get taskPriorityUrgent => '紧急';

  @override
  String get taskAddDueDate => '添加截止日期';

  @override
  String get taskAddTime => '添加时间';

  @override
  String get taskClearDueDate => '清除截止日期';

  @override
  String get taskColumn => '列';

  @override
  String get taskCompleted => '已完成';

  @override
  String get taskLinkedEvents => '关联事件';

  @override
  String get taskNoLinkedEvents => '此任务还没有关联的日历事件。';

  @override
  String get taskNewEventShort => '新建事件';

  @override
  String get taskDeleteQuestion => '删除任务？';

  @override
  String taskDeleteBody(String title) {
    return '“$title”将被永久删除。';
  }

  @override
  String get taskReminder => '提醒我';

  @override
  String get taskReminderNone => '不提醒';

  @override
  String get taskReminderAtDue => '到期时提醒';

  @override
  String get taskReminderNeedsDue => '设置截止日期后才能添加提醒';

  @override
  String taskReminderBefore(String label) {
    return '提前$label';
  }

  @override
  String taskReminderBody(String title) {
    return '$title 即将到期';
  }

  @override
  String get quickAddHint => '添加任务';

  @override
  String get quickAddAction => '添加任务';

  @override
  String get quickAddDone => '结束添加';

  @override
  String get quickAddClearParsed => '清除识别出的日期';

  @override
  String get quickAddDueDate => '设置截止日期';

  @override
  String quickAddAddedOne(String title) {
    return '已添加“$title”';
  }

  @override
  String quickAddAddedMany(int count) {
    return '已添加 $count 个任务';
  }

  @override
  String get settingsTitle => '设置';

  @override
  String get settingsSwipe => '滑动手势';

  @override
  String get settingsSwipeRight => '右滑';

  @override
  String get settingsSwipeRightHint => '在待办列表的任务上';

  @override
  String get settingsSwipeLeft => '左滑';

  @override
  String get settingsReminders => '提醒';

  @override
  String get settingsDailyReminder => '每日提醒';

  @override
  String get settingsDailyReminderHint => '在你选择的时间发送通知';

  @override
  String get settingsNotificationsUnsupported => '浏览器版本不支持';

  @override
  String get settingsReminderTime => '提醒时间';

  @override
  String get settingsCalendarSync => '日历同步';

  @override
  String get settingsBackup => '备份';

  @override
  String get settingsExport => '导出';

  @override
  String get settingsExportHint => '将看板、任务和事件保存为 JSON';

  @override
  String get settingsImport => '导入';

  @override
  String get settingsImportHint => '用备份文件替换全部数据';

  @override
  String get settingsAbout => '关于';

  @override
  String get settingsVersion => '版本';

  @override
  String get settingsLicenses => '开源许可';

  @override
  String get settingsLicensesHint => 'GTD 使用的开源软件包';

  @override
  String get settingsDeviceCalendar => '设备日历';

  @override
  String get settingsOnlyAndroid => '仅在 Android 上可用';

  @override
  String get settingsDeviceCalendarHint => '将事件同步到设备日历';

  @override
  String get settingsSyncNow => '立即同步';

  @override
  String get settingsNotSyncedYet => '尚未同步';

  @override
  String settingsLastSynced(String time) {
    return '上次同步 $time';
  }

  @override
  String get settingsRemoveSynced => '删除已同步事件';

  @override
  String get settingsRemoveSyncedHint => '删除本应用创建的副本';

  @override
  String get settingsCalendarPermissionDenied => '日历权限被拒绝';

  @override
  String get settingsNoWritableCalendar => '没有可写入的日历';

  @override
  String get settingsNoWritableCalendarBody => '此设备没有可写入的日历。创建一个本地 “GTD” 日历？';

  @override
  String get settingsCouldNotCreateCalendar => '无法创建日历';

  @override
  String settingsCalendarError(String error) {
    return '日历错误：$error';
  }

  @override
  String settingsCalendarSynced(String summary) {
    return '日历已同步：$summary';
  }

  @override
  String settingsSyncFailed(String error) {
    return '同步失败：$error';
  }

  @override
  String get settingsRemoveSyncedQuestion => '删除已同步事件？';

  @override
  String get settingsRemoveSyncedBody => '设备日历中的副本将被删除，GTD 中的事件保留。';

  @override
  String settingsRemovedEvents(int count) {
    return '已删除 $count 个事件';
  }

  @override
  String settingsCouldNotRemove(String error) {
    return '无法删除事件：$error';
  }

  @override
  String get settingsNotificationDenied => '通知权限被拒绝';

  @override
  String get settingsDailyReminderEnabled => '已启用每日提醒';

  @override
  String settingsCouldNotEnable(String error) {
    return '无法启用通知：$error';
  }

  @override
  String settingsCouldNotReschedule(String error) {
    return '无法重新安排提醒：$error';
  }

  @override
  String get settingsBackupNotSaved => '备份未保存';

  @override
  String get settingsBackupSaved => '备份已保存';

  @override
  String settingsExportFailed(String error) {
    return '导出失败：$error';
  }

  @override
  String settingsCouldNotOpenFile(String error) {
    return '无法打开文件：$error';
  }

  @override
  String get settingsReplaceAllQuestion => '替换全部数据？';

  @override
  String get settingsReplaceAllBody => '导入备份会删除此设备上现有的看板、任务和事件。';

  @override
  String settingsImported(String summary) {
    return '已导入 $summary';
  }

  @override
  String settingsImportFailed(String error) {
    return '导入失败：$error';
  }

  @override
  String get settingsExportDialogTitle => '导出 GTD 备份';

  @override
  String get settingsImportDialogTitle => '导入 GTD 备份';

  @override
  String get subtasksTitle => '子任务';

  @override
  String get subtaskAdd => '添加子任务';

  @override
  String subtaskProgress(int done, int total) {
    return '$done/$total';
  }

  @override
  String get subtaskEmpty => '还没有子任务';

  @override
  String get tagsTitle => '标签';

  @override
  String get tagAdd => '添加标签';

  @override
  String get tagNew => '新建标签';

  @override
  String get tagName => '标签名称';

  @override
  String get tagEmpty => '还没有标签';

  @override
  String get tagNoMatches => '没有匹配的标签';

  @override
  String get searchHint => '搜索任务、事件和标签';

  @override
  String get searchTasks => '任务';

  @override
  String get searchEvents => '事件';

  @override
  String searchNoResults(String query) {
    return '没有找到“$query”';
  }

  @override
  String get reminderBefore5m => '提前 5 分钟';

  @override
  String get reminderBefore15m => '提前 15 分钟';

  @override
  String get reminderBefore1h => '提前 1 小时';

  @override
  String get reminderBefore3h => '提前 3 小时';

  @override
  String get reminderBefore1d => '提前 1 天';

  @override
  String get reminderNotificationTitle => '提醒';

  @override
  String get edit => '编辑';

  @override
  String get subtaskEdit => '编辑子任务';
}
