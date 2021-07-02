import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:html2image/template.dart';
import 'package:puppeteer/puppeteer.dart' as puppeteer;
import 'package:image/image.dart' as image;

InAppLocalhostServer localhostServer = InAppLocalhostServer();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isAndroid) {
    await AndroidInAppWebViewController.setWebContentsDebuggingEnabled(true);
  }

  await localhostServer.start();

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key, required this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;
  HeadlessInAppWebView? headlessWebView;
  Uint8List? _screenshot;
  int _startTime = 0;
  puppeteer.Page? _page;
  late Generator _generator;

  @override
  void initState() {
    super.initState();
    () async {
      final profile = await CapabilityProfile.load();
      _generator = Generator(PaperSize.mm80, profile);
      if (Platform.isAndroid || Platform.isIOS) {
        headlessWebView = new HeadlessInAppWebView(
          initialUrlRequest: URLRequest(
              url: Uri.parse("http://localhost:8080/assets/index.html")),
          onLoadStop: (controller, url) async {
            print(
                "onLoadStop = ${DateTime.now().millisecondsSinceEpoch - _startTime} ms");
            await _captureWebView();
          },
        );
        headlessWebView!
            .setSize(Size(300, 800))
            .then((value) => headlessWebView!.run());
      } else if (Platform.isWindows) {
        () async {
          var browser = await puppeteer.puppeteer
              .launch(defaultViewport: puppeteer.DeviceViewport(width: 300));
          _page = await browser.newPage();
        }();
      }
    }();
  }

  @override
  void dispose() {
    super.dispose();
    headlessWebView?.dispose();
  }

  _loadAndCapture() async {
    var html = BUILD_RECEIPT_TEMPLATE(orderNumber: this._counter.toString());
    if (Platform.isAndroid || Platform.isIOS) {
      await headlessWebView!.loadData(data: html);
    } else if (Platform.isWindows) {
      await _page!.setContent(html, wait: puppeteer.Until.load);
      print(
          "onLoadStop = ${DateTime.now().millisecondsSinceEpoch - _startTime} ms");
      var screenshot = await _page!.screenshot(fullPage: true);
      print(
          "onScreenShotByte = ${DateTime.now().millisecondsSinceEpoch - _startTime} ms");
      setState(() {
        _screenshot = screenshot;
      });
    }
  }

  _captureWebView() async {
    if (Platform.isAndroid || Platform.isIOS) {
      var screenshot = await headlessWebView!.capture();
      print(
          "onScreenShotByte = ${DateTime.now().millisecondsSinceEpoch - _startTime} ms");
      _generator.image(image.decodeImage(screenshot!.toList()));
      print(
          "onImageGenerated = ${DateTime.now().millisecondsSinceEpoch - _startTime} ms");
      setState(() {
        _screenshot = screenshot;
      });
    }
  }

  void _incrementCounter() async {
    _startTime = DateTime.now().millisecondsSinceEpoch;
    await _loadAndCapture();
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    Widget body = Container();
    if (_screenshot != null) {
      body = SingleChildScrollView(
        child: Image.memory(_screenshot!),
      );
    }
    return new Scaffold(
      appBar: new AppBar(title: new Text('Example App')),
      body: body,
      resizeToAvoidBottomInset: false,
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: Icon(Icons.add),
      ),
    );
  }
}
