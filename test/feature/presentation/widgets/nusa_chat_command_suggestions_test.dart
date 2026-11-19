import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nusa_chat/nusa_chat.dart';

void main() {
  final many = [for (var i = 0; i < 10; i++) ChatCommand(command: '/cmd$i', description: 'Perintah $i')];
  const few = [ChatCommand(command: '/status', description: 'Cek status')];
  final moreBelow = find.byKey(const ValueKey('nusa_chat.command.more_below'));

  Future<void> pump(
    WidgetTester tester,
    List<ChatCommand> commands, {
    NusaChatTheme? theme,
    ValueChanged<ChatCommand>? onSelected,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NusaChatThemeScope(
            theme: theme ?? NusaChatTheme.fallback(),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: NusaChatCommandSuggestions(commands: commands, onSelected: onSelected ?? (_) {}),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('pastikan fade dan scrollbar tampil saat masih ada item di bawah', (tester) async {
    await pump(tester, many);

    expect(moreBelow, findsOneWidget);
    expect(tester.widget<Scrollbar>(find.byType(Scrollbar)).thumbVisibility, isTrue);

    await tester.drag(find.byType(ListView), const Offset(0, -2000));
    await tester.pumpAndSettle();

    expect(moreBelow, findsNothing);
    expect(tester.widget<Scrollbar>(find.byType(Scrollbar)).thumbVisibility, isTrue);
  });

  testWidgets('pastikan tanpa fade dan scrollbar kalau semua item terlihat', (tester) async {
    await pump(tester, few);

    expect(moreBelow, findsNothing);
    expect(tester.widget<Scrollbar>(find.byType(Scrollbar)).thumbVisibility, isFalse);
  });

  testWidgets('pastikan fade muncul saat daftar berubah jadi panjang', (tester) async {
    await pump(tester, few);
    expect(moreBelow, findsNothing);

    await pump(tester, many);
    await tester.pump();

    expect(moreBelow, findsOneWidget);
  });

  testWidgets('pastikan gaya diambil dari tema', (tester) async {
    const commandStyle = TextStyle(fontSize: 18, color: Colors.green);
    const descriptionStyle = TextStyle(fontSize: 11, color: Colors.orange);
    final theme = NusaChatTheme.fallback().copyWith(
      commandColor: Colors.yellow,
      commandBorderColor: Colors.red,
      commandTextStyle: commandStyle,
      commandDescriptionStyle: descriptionStyle,
      commandMaxHeight: 100,
    );
    await pump(tester, many, theme: theme);

    final material = tester.widget<Material>(
      find.descendant(of: find.byType(NusaChatCommandSuggestions), matching: find.byType(Material)).first,
    );
    expect(material.color, Colors.yellow);
    expect((material.shape! as Border).top.color, Colors.red);
    expect(tester.widget<Text>(find.text('/cmd0')).style, commandStyle);
    expect(tester.widget<Text>(find.text('Perintah 0')).style, descriptionStyle);
    expect(tester.getSize(find.byType(NusaChatCommandSuggestions)).height, lessThanOrEqualTo(101));
  });

  testWidgets('pastikan gaya bawaan mengikuti composer', (tester) async {
    final theme = NusaChatTheme.fallback();
    await pump(tester, few, theme: theme);

    final material = tester.widget<Material>(
      find.descendant(of: find.byType(NusaChatCommandSuggestions), matching: find.byType(Material)).first,
    );
    expect(material.color, theme.composerColor);
    expect(tester.widget<Text>(find.text('/status')).style!.color, theme.primaryColor);
    expect(tester.widget<Text>(find.text('Cek status')).style, theme.inputHintStyle);
    expect(theme.commandMaxHeight, 240);
  });

  testWidgets('pastikan ketuk baris memanggil onSelected', (tester) async {
    ChatCommand? selected;
    await pump(tester, few, onSelected: (command) => selected = command);

    await tester.tap(find.text('/status'));

    expect(selected, few.single);
  });
}
