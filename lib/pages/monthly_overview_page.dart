import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';

class MonthlyOverviewPage extends StatefulWidget {
  final Map<String, List<Map<String, String>>> taskMap;
  final Function(DateTime) onSelectDate;

  const MonthlyOverviewPage({
    super.key,
    required this.taskMap,
    required this.onSelectDate,
  });

  @override
  State<MonthlyOverviewPage> createState() => _MonthlyOverviewPageState();
}

class _MonthlyOverviewPageState extends State<MonthlyOverviewPage> {
  late DateTime _focusedDate;
  final CalendarController _calendarController = CalendarController();

  @override
  void initState() {
    super.initState();
    _focusedDate = DateTime.now();
    _calendarController.displayDate = _focusedDate;
  }

  void _changeMonth(int offset) {
    setState(() {
      _focusedDate = DateTime(_focusedDate.year, _focusedDate.month + offset);
      _calendarController.displayDate = _focusedDate;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text('月曆總覽', style: TextStyle(color: Colors.black)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.today, color: Colors.black),
            onPressed: () {
              setState(() {
                _focusedDate = DateTime.now();
                _calendarController.displayDate = _focusedDate;
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _changeMonth(-1),
                ),
                Text(
                  DateFormat('yyyy 年 MM 月').format(_focusedDate),
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2576BD)),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => _changeMonth(1),
                ),
              ],
            ),
          ),
          Expanded(
            child: SfCalendar(
              controller: _calendarController,
              view: CalendarView.month,
              backgroundColor: const Color(0xFFF6F7FA),
              firstDayOfWeek: 7,
              dataSource: _TaskCalendarDataSource(widget.taskMap),
              todayHighlightColor: Colors.blueAccent,
              headerHeight: 0,
              showDatePickerButton: false,
              showNavigationArrow: false,
              viewHeaderStyle: const ViewHeaderStyle(
                dayTextStyle: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
              ),
              monthViewSettings: const MonthViewSettings(
                appointmentDisplayMode: MonthAppointmentDisplayMode.appointment,
                showAgenda: false,
                appointmentDisplayCount: 3,
                numberOfWeeksInView: 6,
              ),
              onViewChanged: (ViewChangedDetails details) {
                final visibleDates = details.visibleDates;
                if (visibleDates.isNotEmpty) {
                  final DateTime middleDate = visibleDates[visibleDates.length ~/ 2];
                  if (!DateUtils.isSameMonth(middleDate, _focusedDate)) {
                    setState(() {
                      _focusedDate = middleDate;
                    });
                  }
                }
              },
              monthCellBuilder: (context, details) {
                final DateTime date = details.date;
                final bool isToday = DateUtils.isSameDay(date, DateTime.now());
                final bool isCurrentMonth = date.month == _focusedDate.month;
                final String dateKey = DateFormat('yyyy-MM-dd').format(date);
                final List<Map<String, String>>? tasks = widget.taskMap[dateKey];

                bool allCompleted = false;
                bool hasOverdueUncompleted = false;

                if (tasks != null && tasks.isNotEmpty) {
                  final now = DateTime.now();
                  final isPast = date.isBefore(DateTime(now.year, now.month, now.day));
                  final completedCount =
                      tasks.where((task) => task['completed'] == 'true').length;

                  allCompleted = completedCount == tasks.length;
                  hasOverdueUncompleted = isPast && completedCount < tasks.length;
                }

                Color textColor;
                FontWeight fontWeight = FontWeight.normal;
                Color borderColor = Colors.transparent;
                Color bgColor = Colors.white;

                if (!isCurrentMonth) {
                  textColor = Colors.grey.shade400;
                } else if (isToday) {
                  textColor = Colors.blueAccent;
                  fontWeight = FontWeight.bold;
                  borderColor = Colors.blueAccent;
                } else {
                  textColor = Colors.black;
                  borderColor = Colors.grey.shade300;
                }

                if (allCompleted) {
                  bgColor = const Color(0xFFE0F2F1); // 淡綠背景
                }

                return Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    border: Border.all(color: borderColor, width: 1),
                    borderRadius: BorderRadius.circular(8),
                    color: bgColor,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${date.day}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: fontWeight,
                            color: textColor,
                          ),
                        ),
                        const Spacer(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (allCompleted)
                              const Icon(Icons.check_circle, color: Colors.green, size: 14),
                            if (hasOverdueUncompleted)
                              const Padding(
                                padding: EdgeInsets.only(left: 4),
                                child: Icon(Icons.circle, color: Colors.red, size: 8),
                              ),
                          ],
                        )
                      ],
                    ),
                  ),
                );
              },
              appointmentBuilder: (context, details) {
                final Appointment appointment = details.appointments.first;
                final String raw = appointment.subject;
                final bool isDone = raw.startsWith('✔️');
                final bool isExtra = raw.startsWith('+');
                final String title = raw.replaceAll(RegExp(r'^[✔️❗]+'), '').trim();

                final IconData icon = isDone ? Icons.check_circle : Icons.warning_amber;

                return Container(
                  height: 24,
                  margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: appointment.color,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (!isExtra)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Icon(icon, color: Colors.white, size: 14),
                        ),
                      Flexible(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
              onTap: (CalendarTapDetails details) {
                final DateTime? selectedDate = details.date;
                if (selectedDate != null) {
                  widget.onSelectDate(selectedDate);
                  Navigator.pop(context);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskCalendarDataSource extends CalendarDataSource {
  _TaskCalendarDataSource(Map<String, List<Map<String, String>>> taskMap) {
    appointments = [];

    taskMap.forEach((dateKey, tasks) {
      final date = DateTime.tryParse(dateKey);
      if (date == null || tasks.isEmpty) return;

      final first = tasks.first;
      final title = first['task'] ?? '任務';
      final isCompleted = first['completed'] == 'true';
      final color = isCompleted
          ? const Color(0xFF81C784) // 綠
          : const Color(0xFFE57373); // 紅

      appointments!.add(Appointment(
        startTime: date,
        endTime: date.add(const Duration(minutes: 30)),
        subject: isCompleted ? '✔️ $title' : '❗ $title',
        color: color,
      ));

      if (tasks.length > 1) {
        appointments!.add(Appointment(
          startTime: date,
          endTime: date.add(const Duration(minutes: 30)),
          subject: '+${tasks.length - 1} 更多',
          color: Colors.grey.shade400,
        ));
      }
    });
  }
}
