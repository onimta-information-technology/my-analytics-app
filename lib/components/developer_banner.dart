// lib/widgets/developer_banner.dart
import 'dart:async';
import 'package:flutter/material.dart';

import '../utils/developer_mode_util.dart';

class DeveloperBanner extends StatefulWidget {
  final Widget child;
  const DeveloperBanner({required this.child, Key? key}) : super(key: key);

  @override
  State<DeveloperBanner> createState() => _DeveloperBannerState();
}

class _DeveloperBannerState extends State<DeveloperBanner>
    with SingleTickerProviderStateMixin {
  bool _isDevMode = false;
  Timer? _pollTimer;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );
    _startPolling();
  }

  void _startPolling() {
    _check();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _check());
  }

  Future<void> _check() async {
    final enabled = await DeveloperModeUtil.isDeveloperModeEnabled();
    if (!mounted) return;
    if (enabled != _isDevMode) {
      setState(() => _isDevMode = enabled);
      if (enabled) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_isDevMode)
          FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF1a1a2e),
                    const Color(0xFF16213e),
                    const Color(0xFF0f3460),
                  ],
                ),
              ),
              child: Center(
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 32),
                    padding: const EdgeInsets.all(40),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.1),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.orange.shade400,
                                Colors.red.shade600,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.orange.withOpacity(0.5),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.developer_mode,
                            size: 56,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          'Developer Mode Active',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.5,
                             decoration: TextDecoration.none,
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.3),
                                offset: const Offset(0, 2),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          width: 60,
                          height: 4,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2),
                            gradient: LinearGradient(
                              colors: [
                                Colors.orange.shade400,
                                Colors.red.shade600,
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'For security reasons, this app cannot run\nwith Developer Options enabled.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withOpacity(0.9),
                            height: 1.5,
                            letterSpacing: 0.3,
                             decoration: TextDecoration.none,
                          ),
                        ),
                        const SizedBox(height: 32),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.15),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              
                              Icon(
                                Icons.info_outline,
                                color: Colors.blue.shade300,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Flexible(
                                child: Text(
                                  'Please disable Developer Mode\nin your device settings',
                                  textAlign: TextAlign.center,
                                  
                                  style: TextStyle(
                                    fontSize: 14,
                                     decoration: TextDecoration.none,
                                    color: Colors.white.withOpacity(0.85),
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}