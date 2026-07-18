import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:pomo/helpers/notion_url_helper.dart';
import 'package:pomo/pages/tracker/view/hourly_tracker_view.dart';
import 'package:pomo/pages/tracker/view/missed_tracking_view.dart';
import 'package:pomo/singletons/prefs.dart';
import 'package:url_launcher/url_launcher.dart';

/// Main container page for the Hourly Time Tracker & Analytics tab.
class TrackerShellPage extends StatelessWidget {
  const TrackerShellPage({super.key});

  void _openHourlyTimeline(BuildContext context) {
    if (!NotionUrlHelper.hasHourlyTimelineDatabaseId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Set Hourly Timeline Database ID in Settings',
          ),
        ),
      );
      return;
    }
    final url = NotionUrlHelper.hourlyTimelineDatabaseUrl;
    launchUrl(Uri.parse(url));
  }

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
          actions: [
            if (Prefs.enableNotionSync)
              IconButton(
                tooltip: 'Open Notion Hourly Timeline',
                icon: SvgPicture.asset(
                  'assets/images/notion_logo.svg',
                  width: 20,
                  height: 20,
                  colorFilter: ColorFilter.mode(
                    Theme.of(context).colorScheme.onSurface,
                    BlendMode.srcIn,
                  ),
                ),
                onPressed: () => _openHourlyTimeline(context),
              ),
          ],
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
