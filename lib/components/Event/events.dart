import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

enum EventType {
  christmas,
  independence,
  lohri,
  thaiPongal,
  republicDay,
  valentineDay,
  chineseNewYear,
  holi,
}

class EventOverlay extends StatelessWidget {
  final EventType? activeEvent;

  const EventOverlay({
    Key? key,
    this.activeEvent,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (activeEvent == null) {
      return const SizedBox.shrink();
    }

    switch (activeEvent!) {
      case EventType.christmas:
        return _buildChristmasEvent();
      case EventType.independence:
        return _buildIndependenceEvent();
      case EventType.lohri:
        return _buildLohriEvent();
      case EventType.thaiPongal:
        return _buildHappyPongalEvent();
      case EventType.republicDay:
        return _buildRepublicDayEvent();
      case EventType.valentineDay:
        return _buildValentineDayEvent();
      case EventType.chineseNewYear:
        return _buildChineseNewYearEvent();
      case EventType.holi:
        return _buildHoliEvent();
    }
  }

  /// ❄️ Christmas Event (December)
  Widget _buildChristmasEvent() {
    return Material(
      color: Colors.transparent,
      child: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: Stack(
          children: [
            // Full screen snow
            Positioned.fill(
              child: Lottie.asset(
                'assets/events/snow.json',
                fit: BoxFit.cover,
                repeat: true,
              ),
            ),
            // Christmas tree
            Positioned(
              left: 0,
              bottom: 0,
              child: Lottie.asset(
                'assets/events/ChristmasTree.json',
                width: 250,
                height: 250,
                fit: BoxFit.contain,
                repeat: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 🇱🇰 Independence Day Event (February 4th)
  Widget _buildIndependenceEvent() {
    return IgnorePointer(
      child: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: Center(
            child: Lottie.asset(
              'assets/events/independenceDaySl.json',
              width: 500,
              height: 500,
              fit: BoxFit.contain,
              repeat: true,
            ),
          ),
        ),
      ),
    );
  }

  /// 🔥 Lohri Festival Event
  Widget _buildLohriEvent() {
    return IgnorePointer(
      child: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: Center(
            child: Lottie.asset(
              'assets/events/LohriFestival.json',
              width: 500,
              height: 500,
              fit: BoxFit.contain,
              repeat: true,
            ),
          ),
        ),
      ),
    );
  }
    Widget _buildHappyPongalEvent() {
    return IgnorePointer(
      child: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: Center(
            child: Lottie.asset(
              'assets/events/HappyPongal.json',
              width: 500,
              height: 500,
              fit: BoxFit.contain,
              repeat: true,
            ),
          ),
        ),
      ),
    );
  }
  Widget _buildRepublicDayEvent() {
    return IgnorePointer(
      child: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: Center(
            child: Lottie.asset(
              'assets/events/RepublicDay.json',
              width: 500,
              height: 500,
              fit: BoxFit.contain,
              repeat: true,
            ),
          ),
        ),
      ),
    );
  }
   Widget _buildValentineDayEvent() {
    return IgnorePointer(
      child: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: Center(
            child: Lottie.asset(
              'assets/events/ValentineDayHeart.json',
              width: 500,
              height: 500,
              fit: BoxFit.contain,
              repeat: true,
            ),
          ),
        ),
      ),
    );
  }
   Widget _buildChineseNewYearEvent() {
    return IgnorePointer(
      child: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: Center(
            child: Lottie.asset(
              'assets/events/ChineseNewYear.json',
              width: 500,
              height: 500,
              fit: BoxFit.contain,
              repeat: true,
            ),
          ),
        ),
      ),
    );
  }
  Widget _buildHoliEvent() {
    return IgnorePointer(
      child: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: Center(
            child: Lottie.asset(
              'assets/events/HappyHoli.json',
              width: 500,
              height: 500,
              fit: BoxFit.contain,
              repeat: true,
            ),
          ),
        ),
      ),
    );
  }
}