import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:url_launcher/url_launcher.dart';

class ProposalPdfScreen extends StatelessWidget {
  const ProposalPdfScreen({
    super.key,
    required this.url,
    required this.fileName,
  });

  final String url;
  final String fileName;

  Future<void> _openExternally() async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final isAsset = url.startsWith('asset:');
    return Scaffold(
      appBar: AppBar(
        title: Text(fileName, overflow: TextOverflow.ellipsis),
        actions: [
          if (!isAsset)
            IconButton(
              tooltip: 'Open externally',
              onPressed: _openExternally,
              icon: const Icon(Icons.open_in_new),
            ),
        ],
      ),
      body: isAsset
          ? PdfViewer.asset(url.substring('asset:'.length))
          : PdfViewer.uri(Uri.parse(url)),
    );
  }
}
