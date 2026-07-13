import 'package:flutter/material.dart';
import 'package:pomo/pages/tracker/view/hourly_tracker_view.dart';
import 'package:pomo/pages/tracker/view/missed_tracking_view.dart';

/// Main container page for the Hourly Time Tracker & Analytics tab.
class TrackerShellPage extends StatelessWidget {
  const TrackerShellPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Hourly Time Tracker',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          bottom: const TabBar(
            tabs: [
              Tab(
                icon: Icon(Icons.analytics_outlined),
                text: 'Activity Grid & Analytics',
              ),
              Tab(
                icon: Icon(Icons.timer_off_outlined),
                text: 'Missed Hours Check',
              ),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            HourlyTrackerView(),
            MissedTrackingView(),
          ],
        ),
      ),
    );
  }
}
