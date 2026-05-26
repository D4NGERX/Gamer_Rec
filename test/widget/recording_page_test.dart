// test/widget/recording_page_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gamer_rec/features/recording/presentation/bloc/recording_bloc.dart';
import 'package:gamer_rec/features/recording/presentation/widgets/record_button.dart';
import 'package:gamer_rec/core/theme/app_theme.dart';

// We provide a fake bloc via BlocProvider to isolate the widget.
class _FakeRecordingBloc extends Fake implements RecordingBloc {
  @override
  RecordingState get state => RecordingIdle();

  @override
  Stream<RecordingState> get stream => const Stream.empty();

  @override
  Future<void> close() async {}

  @override
  void add(RecordingEvent event) {}
}

void main() {
  group('RecordButton Widget', () {
    Widget makeButton(RecordButtonState btnState) => MaterialApp(
          theme: appTheme,
          home: Scaffold(
            body: Center(
              child: RecordButton(state: btnState, onTap: () {}),
            ),
          ),
        );

    testWidgets('renders in idle state without error', (tester) async {
      await tester.pumpWidget(makeButton(RecordButtonState.idle));
      expect(find.byType(RecordButton), findsOneWidget);
    });

    testWidgets('renders in recording state without error', (tester) async {
      await tester.pumpWidget(makeButton(RecordButtonState.recording));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(RecordButton), findsOneWidget);
    });

    testWidgets('renders in loading state with CircularProgressIndicator',
        (tester) async {
      await tester.pumpWidget(makeButton(RecordButtonState.loading));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renders in paused state with play icon', (tester) async {
      await tester.pumpWidget(makeButton(RecordButtonState.paused));
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    });

    testWidgets('onTap is called when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecordButton(
              state: RecordButtonState.idle,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );
      await tester.tap(find.byType(RecordButton));
      expect(tapped, isTrue);
    });
  });
}
