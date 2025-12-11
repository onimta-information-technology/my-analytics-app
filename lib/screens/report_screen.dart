import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            context.go('/menu');
          },
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 4, 158, 143).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.edit_document,
                  size: 100,
                  color: Color.fromARGB(255, 4, 158, 143),
                ),
              ),
              
              const SizedBox(height: 40),
              
              // Coming Soon Text
              const Text(
                'Coming Soon!',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color.fromARGB(255, 4, 158, 143),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Description
              const Text(
                'Reports feature is under development',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey,
                ),
              ),
              
              const SizedBox(height: 8),
              
              const Text(
                'We\'re working hard to bring you detailed reports and analytics',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              
              const SizedBox(height: 50),
              
              // Back Button
              ElevatedButton.icon(
                onPressed: () {
                  context.go('/menu');
                },
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                label: const Text(
                  'Back to Menu',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 4, 158, 143),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}