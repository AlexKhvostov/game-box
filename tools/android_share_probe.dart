// Isolated physical-device UI QA. No accounts, economy, ads, audio or game loop.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:game_box/features/result/share_social_sheet.dart';
import 'package:game_box/features/result/social_share_card.dart';
import 'package:game_box/l10n/app_localizations.dart';

final navigator = GlobalKey<NavigatorState>();
final probe = GlobalKey<_ProbeState>();
final errors = <String>[];
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (error) {
    errors.add(error.exceptionAsString());
    FlutterError.presentError(error);
  };
  runApp(_Probe(key: probe));
  unawaited(_serve());
}

class _Probe extends StatefulWidget {
  const _Probe({super.key});
  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  String language = 'ru';
  double scale = 1;
  BuildContext? home;
  @override
  Widget build(BuildContext context) => MaterialApp(
    navigatorKey: navigator,
    theme: ThemeData.dark(useMaterial3: true),
    locale: Locale(language),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: Builder(
      builder: (context) {
        home = context;
        return Scaffold(
          backgroundColor: const Color(0xFF061B2D),
          body: Center(
            child: TextButton(
              onPressed: () => showShareSocialSheet(
                context,
                timeMs: 21349,
                riskCount: 16,
                runSteps: 1998,
              ),
              child: const Text('Share QA'),
            ),
          ),
        );
      },
    ),
  );
  Future<void> open(Uri uri) async {
    navigator.currentState?.popUntil((route) => route.isFirst);
    setState(() {
      language = uri.queryParameters['locale'] ?? 'ru';
      scale = double.tryParse(uri.queryParameters['scale'] ?? '1') ?? 1;
    });
    await WidgetsBinding.instance.endOfFrame;
    unawaited(
      showShareSocialSheet(
        home!,
        timeMs: int.tryParse(uri.queryParameters['time'] ?? '21349') ?? 21349,
        riskCount: int.tryParse(uri.queryParameters['risk'] ?? '16'),
        runSteps: int.tryParse(uri.queryParameters['steps'] ?? '1998'),
      ),
    );
    await WidgetsBinding.instance.endOfFrame;
  }
}

Element? _cardElement() {
  Element? found;
  void visit(Element element) {
    if (element.widget is RepaintBoundary &&
        (element.widget as RepaintBoundary).child is SocialShareCard) {
      found = element;
    }
    element.visitChildren(visit);
  }

  probe.currentContext?.visitChildElements(visit);
  return found;
}

Future<void> _serve() async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8898);
  await for (final request in server) {
    try {
      if (request.uri.path == '/open' && request.method == 'POST') {
        await probe.currentState!.open(request.uri);
      }
      if (request.uri.path == '/shared.png') {
        final file = File(
          '${(await getTemporaryDirectory()).path}/untouch_share.png',
        );
        request.response.headers.contentType = ContentType('image', 'png');
        request.response.add(await file.readAsBytes());
      } else if (request.uri.path == '/card.png') {
        await precacheImage(
          SocialShareCard.imageProvider,
          probe.currentContext!,
        );
        await WidgetsBinding.instance.endOfFrame;
        final boundary =
            _cardElement()!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 3),
            data = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        request.response.headers.contentType = ContentType('image', 'png');
        request.response.add(data!.buffer.asUint8List());
      } else {
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'ready': probe.currentState?.home != null,
            'open': navigator.currentState?.canPop(),
            'locale': probe.currentState?.language,
            'scale': probe.currentState?.scale,
            'errors': errors,
          }),
        );
      }
    } catch (error) {
      request.response.statusCode = 500;
      request.response.write(error.toString());
    } finally {
      await request.response.close();
    }
  }
}
