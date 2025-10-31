import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  _SupportPageState createState() => _SupportPageState();
}

class _SupportPageState extends State<SupportScreen> {
  late PackageInfo _packageInfo;

  @override
  void initState() {
    super.initState();
    _fetchAppVersion();
  }

  Future<void> _fetchAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _packageInfo = packageInfo;
    });
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Support Page')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Center(child: Image.asset('assets/images/onimta.png')),
              const SizedBox(height: 50),
              InkWell(
                onTap: () => _launchUrl("https://www.onimtait.com"),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.language, size: 30),
                    SizedBox(width: 10),
                    Text('www.onimtait.com', style: TextStyle(fontSize: 20)),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              InkWell(
                onTap: () => _launchUrl("tel:+94759888888"),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.phone, size: 30),
                    SizedBox(width: 10),
                    Text('+94759888888', style: TextStyle(fontSize: 20)),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              InkWell(
                onTap: () => _launchUrl("mailto:help@onimtait.com"),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.email, size: 30),
                    SizedBox(width: 10),
                    Text('help@onimtait.com', style: TextStyle(fontSize: 20)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                "Version: ${_packageInfo.version} ${_packageInfo.buildNumber}",
                style: const TextStyle(
                  fontSize: 14,
                  color: Color.fromARGB(117, 124, 124, 124),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
