import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:pomo/l10n/l10n.dart';
import 'package:pomo/pages/settings/cubit/settings_cubit.dart';
import 'package:pomo/pages/timer/cubit/timer_cubit.dart';
import 'package:pomo/pages/timer/view/timer_page.dart';
import 'package:pomo/singletons/prefs.dart';

class ActionButtons extends StatefulWidget {
  const ActionButtons({
    required this.notify,
    super.key,
  });

  final Future<void> Function(
    NotificationType type,
    SettingsState settingsState,
    TimerStatus status,
  ) notify;

  @override
  State<ActionButtons> createState() => _ActionButtonsState();
}

class _ActionButtonsState extends State<ActionButtons>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _resetController;
  late AnimationController _skipController;
  late Animation<double> _animation;

  final player = AudioPlayer();

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: Durations.long2,
      value: Prefs.timerStatus == TimerStatus.running ? 1 : 0,
    );

    _resetController = AnimationController(
      vsync: this,
      duration: Durations.extralong2,
      animationBehavior: AnimationBehavior.preserve,
    );

    _skipController = AnimationController(
      vsync: this,
      duration: Durations.short2,
      animationBehavior: AnimationBehavior.preserve,
    );

    _animation = Tween<double>(begin: 0, end: 1).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    _resetController.dispose();
    _skipController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return MultiBlocListener(
      listeners: [
        BlocListener<TimerCubit, TimerState>(
          listenWhen: (previous, current) => previous.status != current.status,
          listener: (context, state) {
            if (state.status == TimerStatus.running) {
              _controller.forward();
            } else {
              _controller.reverse();
            }
          },
        ),
        BlocListener<TimerCubit, TimerState>(
          listenWhen: (previous, current) =>
              previous.duration != current.duration && !_controller.isAnimating,
          listener: (context, state) {
            if (state.status == TimerStatus.running && _controller.value < 1) {
              _controller.reverse();
            } else if (_controller.value > 0) {
              _controller.forward();
            }
          },
        ),
      ],
      child: BlocBuilder<TimerCubit, TimerState>(
        builder: (context, state) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton.filledTonal(
                color: Theme.of(context).colorScheme.onTertiaryContainer,
                style: IconButton.styleFrom(
                  backgroundColor:
                      Theme.of(context).colorScheme.tertiaryContainer,
                ),
                tooltip: l10n.reset,
                onPressed: state.status == TimerStatus.running
                    ? null
                    : () {
                        _resetController.forward(from: 0);

                        context.read<TimerCubit>().reset();
                      },
                icon: RotationTransition(
                  turns:
                      Tween<double>(begin: 0, end: 1).animate(_resetController),
                  child: const Icon(Icons.refresh),
                ),
              ),
              const SizedBox(width: 16),
              IconButton.filled(
                style: IconButton.styleFrom(
                  fixedSize: const Size.square(64),
                  iconSize: 32,
                ),
                tooltip: state.status == TimerStatus.stopped
                    ? l10n.startTimer
                    : l10n.pauseTimer,
                onPressed: () {
                  context.read<TimerCubit>().toggle();
                },
                icon: AnimatedIcon(
                  icon: AnimatedIcons.play_pause,
                  progress: _animation,
                ),
              ),
              const SizedBox(width: 16),
              BlocBuilder<SettingsCubit, SettingsState>(
                builder: (context, settingsState) {
                  return IconButton.filledTonal(
                    tooltip: l10n.skipLap,
                    onPressed: () {
                      widget.notify(
                        NotificationType.nextLap,
                        settingsState,
                        state.status,
                      );

                      _skipController
                          .forward(from: 0)
                          .then((_) => _skipController.reverse());

                      context.read<TimerCubit>().lap(
                            autoAdvance: state.status == TimerStatus.running,
                            settingsState: settingsState,
                          );
                    },
                    icon: SlideTransition(
                      position: Tween<Offset>(
                        begin: Offset.zero,
                        end: const Offset(0.15, 0),
                      ).animate(_skipController),
                      child: const Icon(Icons.skip_next),
                    ),
                  );
                },
              ),
              if (state.activeTask != null) ...[
                const SizedBox(width: 16),
                IconButton.filledTonal(
                  color: Theme.of(context).colorScheme.onTertiaryContainer,
                  style: IconButton.styleFrom(
                    backgroundColor:
                        Theme.of(context).colorScheme.tertiaryContainer,
                    foregroundColor:
                        Theme.of(context).colorScheme.onTertiaryContainer,
                  ),
                  tooltip:
                      'Sync to Notion (${state.duration.inMinutes - state.syncedMinutes}m available)',
                  onPressed: state.duration.inMinutes - state.syncedMinutes < 1
                      ? () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'At least 1 unsynced minute must elapse to sync to Notion.',
                              ),
                              duration: Duration(seconds: 3),
                            ),
                          );
                        }
                      : () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final minutesToSync =
                              state.duration.inMinutes - state.syncedMinutes;
                          final taskTitle = state.activeTask?.title ?? 'Task';

                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                'Syncing ${minutesToSync}m to Notion...',
                              ),
                              duration: const Duration(seconds: 1),
                            ),
                          );

                          final success =
                              await context.read<TimerCubit>().syncNow();

                          if (success) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Successfully synced ${minutesToSync}m for "$taskTitle"!',
                                ),
                                duration: const Duration(seconds: 3),
                              ),
                            );
                          } else {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Failed to sync to Notion. Check API key or connection.',
                                ),
                                duration: Duration(seconds: 4),
                              ),
                            );
                          }
                        },
                  icon: SvgPicture.asset(
                    'assets/images/notion_logo.svg',
                    width: 20,
                    height: 20,
                    colorFilter: ColorFilter.mode(
                      Theme.of(context).colorScheme.onTertiaryContainer,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
