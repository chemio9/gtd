package io.github.chemio9.gtd

import android.Manifest
import android.app.Activity
import android.content.ContentUris
import android.content.ContentValues
import android.content.pm.PackageManager
import android.provider.CalendarContract
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.TimeZone

/**
 * Writes GTD events into the device calendar through the CalendarContract
 * provider. Kept small on purpose: the sync bookkeeping (which app event maps
 * to which device event) lives in Dart.
 */
class CalendarSyncChannel(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    private val channel = MethodChannel(messenger, "gtd/calendar")
    private var pendingPermissionResult: MethodChannel.Result? = null

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "hasPermission" -> result.success(hasReadWritePermission())
            "requestPermission" -> requestPermission(result)
            "listCalendars" -> result.success(listCalendars())
            "createLocalCalendar" -> createLocalCalendar(call, result)
            "insertEvent" -> insertEvent(call, result)
            "updateEvent" -> updateEvent(call, result)
            "deleteEvent" -> deleteEvent(call, result)
            else -> result.notImplemented()
        }
    }

    fun onRequestPermissionsResult(requestCode: Int, grantResults: IntArray) {
        if (requestCode != PERMISSION_REQUEST_CODE) return
        val result = pendingPermissionResult ?: return
        pendingPermissionResult = null
        val granted = grantResults.isNotEmpty() &&
            grantResults.all { it == PackageManager.PERMISSION_GRANTED }
        result.success(granted && hasReadWritePermission())
    }

    // ---------------------------------------------------------------- permission

    private fun permissions(): Array<String> = arrayOf(
        Manifest.permission.READ_CALENDAR,
        Manifest.permission.WRITE_CALENDAR,
    )

    private fun hasReadWritePermission(): Boolean = permissions().all {
        ContextCompat.checkSelfPermission(activity, it) == PackageManager.PERMISSION_GRANTED
    }

    private fun requestPermission(result: MethodChannel.Result) {
        if (hasReadWritePermission()) {
            result.success(true)
            return
        }
        if (pendingPermissionResult != null) {
            result.success(false)
            return
        }
        pendingPermissionResult = result
        ActivityCompat.requestPermissions(activity, permissions(), PERMISSION_REQUEST_CODE)
    }

    // ---------------------------------------------------------------- calendars

    private fun listCalendars(): List<Map<String, Any?>> {
        if (!hasReadWritePermission()) return emptyList()

        val projection = arrayOf(
            CalendarContract.Calendars._ID,
            CalendarContract.Calendars.CALENDAR_DISPLAY_NAME,
            CalendarContract.Calendars.ACCOUNT_NAME,
            CalendarContract.Calendars.CALENDAR_ACCESS_LEVEL,
            CalendarContract.Calendars.IS_PRIMARY,
        )
        val calendars = mutableListOf<Map<String, Any?>>()
        activity.contentResolver.query(
            CalendarContract.Calendars.CONTENT_URI,
            projection,
            null,
            null,
            null,
        )?.use { cursor ->
            while (cursor.moveToNext()) {
                val accessLevel = cursor.getInt(3)
                calendars.add(
                    mapOf(
                        "id" to cursor.getLong(0),
                        "name" to cursor.getString(1),
                        "account" to cursor.getString(2),
                        "isWritable" to (accessLevel >= CalendarContract.Calendars.CAL_ACCESS_CONTRIBUTOR),
                        "isPrimary" to (cursor.getInt(4) == 1),
                    ),
                )
            }
        }
        return calendars
    }

    private fun createLocalCalendar(call: MethodCall, result: MethodChannel.Result) {
        if (!hasReadWritePermission()) {
            result.error("permission", "Calendar permission missing", null)
            return
        }
        val name = call.argument<String>("name") ?: "GTD"
        val values = ContentValues().apply {
            put(CalendarContract.Calendars.ACCOUNT_NAME, name)
            put(CalendarContract.Calendars.ACCOUNT_TYPE, CalendarContract.ACCOUNT_TYPE_LOCAL)
            put(CalendarContract.Calendars.NAME, name)
            put(CalendarContract.Calendars.CALENDAR_DISPLAY_NAME, name)
            put(CalendarContract.Calendars.CALENDAR_COLOR, 0xFF4F46E5.toInt())
            put(CalendarContract.Calendars.CALENDAR_ACCESS_LEVEL, CalendarContract.Calendars.CAL_ACCESS_OWNER)
            put(CalendarContract.Calendars.OWNER_ACCOUNT, name)
            put(CalendarContract.Calendars.VISIBLE, 1)
            put(CalendarContract.Calendars.SYNC_EVENTS, 1)
            put(CalendarContract.Calendars.CALENDAR_TIME_ZONE, TimeZone.getDefault().id)
        }
        val uri = CalendarContract.Calendars.CONTENT_URI.buildUpon()
            .appendQueryParameter(CalendarContract.CALLER_IS_SYNCADAPTER, "true")
            .appendQueryParameter(CalendarContract.Calendars.ACCOUNT_NAME, name)
            .appendQueryParameter(CalendarContract.Calendars.ACCOUNT_TYPE, CalendarContract.ACCOUNT_TYPE_LOCAL)
            .build()
        try {
            val inserted = activity.contentResolver.insert(uri, values)
            result.success(inserted?.lastPathSegment?.toLongOrNull())
        } catch (error: Exception) {
            result.error("insert_failed", error.message, null)
        }
    }

    // ---------------------------------------------------------------- events

    private fun insertEvent(call: MethodCall, result: MethodChannel.Result) {
        if (!hasReadWritePermission()) {
            result.error("permission", "Calendar permission missing", null)
            return
        }
        val values = eventValues(call, includeCalendar = true)
            ?: run {
                result.error("bad_args", "Missing event fields", null)
                return
            }
        try {
            val uri = activity.contentResolver.insert(CalendarContract.Events.CONTENT_URI, values)
            result.success(uri?.lastPathSegment?.toLongOrNull())
        } catch (error: Exception) {
            result.error("insert_failed", error.message, null)
        }
    }

    private fun updateEvent(call: MethodCall, result: MethodChannel.Result) {
        if (!hasReadWritePermission()) {
            result.error("permission", "Calendar permission missing", null)
            return
        }
        val deviceEventId = call.argument<Number>("deviceEventId")?.toLong()
        val values = eventValues(call, includeCalendar = false)
        if (deviceEventId == null || values == null) {
            result.error("bad_args", "Missing event fields", null)
            return
        }
        try {
            val uri = ContentUris.withAppendedId(CalendarContract.Events.CONTENT_URI, deviceEventId)
            val updated = activity.contentResolver.update(uri, values, null, null)
            result.success(updated > 0)
        } catch (error: Exception) {
            result.error("update_failed", error.message, null)
        }
    }

    private fun deleteEvent(call: MethodCall, result: MethodChannel.Result) {
        if (!hasReadWritePermission()) {
            result.error("permission", "Calendar permission missing", null)
            return
        }
        val deviceEventId = call.argument<Number>("deviceEventId")?.toLong()
        if (deviceEventId == null) {
            result.error("bad_args", "Missing deviceEventId", null)
            return
        }
        try {
            val uri = ContentUris.withAppendedId(CalendarContract.Events.CONTENT_URI, deviceEventId)
            activity.contentResolver.delete(uri, null, null)
            result.success(true)
        } catch (error: Exception) {
            result.error("delete_failed", error.message, null)
        }
    }

    private fun eventValues(call: MethodCall, includeCalendar: Boolean): ContentValues? {
        val title = call.argument<String>("title") ?: return null
        val startMillis = call.argument<Number>("startMillis")?.toLong() ?: return null
        val endMillis = call.argument<Number>("endMillis")?.toLong() ?: return null
        val allDay = call.argument<Boolean>("allDay") ?: false
        val timeZone = call.argument<String>("timeZone") ?: TimeZone.getDefault().id
        val rrule = call.argument<String>("rrule")

        val values = ContentValues().apply {
            put(CalendarContract.Events.TITLE, title)
            put(CalendarContract.Events.DESCRIPTION, call.argument<String>("description"))
            put(CalendarContract.Events.DTSTART, startMillis)
            put(CalendarContract.Events.ALL_DAY, if (allDay) 1 else 0)
            put(CalendarContract.Events.EVENT_TIMEZONE, if (allDay) "UTC" else timeZone)
            if (rrule.isNullOrBlank()) {
                put(CalendarContract.Events.DTEND, endMillis)
                putNull(CalendarContract.Events.RRULE)
                putNull(CalendarContract.Events.DURATION)
            } else {
                // Recurring events use DURATION instead of DTEND on Android.
                put(CalendarContract.Events.RRULE, rrule)
                put(CalendarContract.Events.DURATION, durationString(startMillis, endMillis, allDay))
                putNull(CalendarContract.Events.DTEND)
            }
        }
        if (includeCalendar) {
            val calendarId = call.argument<Number>("calendarId")?.toLong() ?: return null
            values.put(CalendarContract.Events.CALENDAR_ID, calendarId)
        }
        return values
    }

    /** RFC2445 duration: `P1D` for all-day, `PT90M`/`PT1H30M` otherwise. */
    private fun durationString(startMillis: Long, endMillis: Long, allDay: Boolean): String {
        var minutes = ((endMillis - startMillis) / 60_000).coerceAtLeast(1)
        if (allDay) {
            val days = ((endMillis - startMillis) / 86_400_000).coerceAtLeast(1)
            return "P${days}D"
        }
        val hours = minutes / 60
        minutes %= 60
        val builder = StringBuilder("PT")
        if (hours > 0) builder.append("${hours}H")
        if (minutes > 0L || hours == 0L) builder.append("${minutes}M")
        return builder.toString()
    }

    companion object {
        private const val PERMISSION_REQUEST_CODE = 4711
    }
}
