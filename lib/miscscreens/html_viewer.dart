import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/services.dart'; // For rootBundle
import 'package:flutter_html/flutter_html.dart'; // For Web support

class LocalHtmlViewer extends StatefulWidget {
  final String filePath;
  final String screenTitle;
  const LocalHtmlViewer({super.key, required this.filePath, required this.screenTitle});

  @override
  _LocalHtmlViewerState createState() => _LocalHtmlViewerState();
}

class _LocalHtmlViewerState extends State<LocalHtmlViewer> {
  late WebViewController _controller;
  String _htmlContent = ""; // Used for web

  @override
  void initState() {
    super.initState();
    _loadHtmlFromAssets();

    // Initialize WebView only for mobile platforms
    if (!kIsWeb) {
      final WebViewController controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted);
      _controller = controller;
    }
  }

  Future<void> _loadHtmlFromAssets() async {
    // Load the HTML file from assets
    String fileText = await rootBundle.loadString(widget.filePath);
    setState(() {
      _htmlContent = fileText;
    });

    if (!kIsWeb) {
      _controller.loadHtmlString(fileText);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.screenTitle)),
      body: kIsWeb
          ? SingleChildScrollView(
              child: Html(data: _htmlContent), // Render HTML for web
            )
          : WebViewWidget(controller: _controller), // Use WebView for mobile
    );
  }
}
