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
  happyWomen,
  ramadan,
  easter,
  sinhalatamilNewYear,
  earthDay,
  labourDay,
  mothersDay,
  eidAlAdha,
  environmentDay,
  fathersDay,
  friendshipDay,
  youthDay,
  pakistanIndependenceDay,
  indianIndependenceDay,
  rakshaBandhan,
  janmashtamiEvent,
  ganeshchaturthi,
  peaceDay,
  autumnFestival,
  travellingBags,
  halloween,
  diwali,
}

class EventOverlay extends StatelessWidget {
  final EventType? activeEvent;

  const EventOverlay({Key? key, this.activeEvent}) : super(key: key);

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
      case EventType.happyWomen:
        return _buildHappyWomenEvent();
      case EventType.ramadan:
        return _buildRamadanEvent();
      case EventType.easter:
        return _buildEasterEvent();
      case EventType.sinhalatamilNewYear:
        return _buildSinhalatamilNewYearEvent();
      case EventType.earthDay:
        return _buildEarthDayEvent();
      case EventType.labourDay:
        return _buildLabourDayEvent();
      case EventType.mothersDay:
        return _buildMotherDayEvent();
      case EventType.eidAlAdha:
        return _buildEidAlAdhaEvent();
      case EventType.environmentDay:
        return _buildSaveTheEarthEvent();
      case EventType.fathersDay:
        return _buildFathersDayEvent();
      case EventType.friendshipDay:
        return _buildFriendsipDayEvent();
      case EventType.youthDay:
        return _buildYouthDayEvent();
      case EventType.pakistanIndependenceDay:
        return _buildPakisthanIndependenceEvent();
      case EventType.indianIndependenceDay:
        return _buildindianindependenceDayEvent();
      case EventType.rakshaBandhan:
        return _buildRakshaBandhanEvent();
      case EventType.janmashtamiEvent:
        return _buildHappyJanmashtamiEvent();
      case EventType.ganeshchaturthi:
        return _buildGaneshChathurthiEvent();
      case EventType.peaceDay:
        return _buildPeaceDayEvent();
      case EventType.autumnFestival:
        return _buildAutumnFestivalEvent();
      case EventType.travellingBags:
        return _buildTravellingBagsEvent();
      case EventType.halloween:
        return _buildHalloweenEvent();
      case EventType.diwali:
        return _buildDiwaliEvent();
    }
  }

  /// ❄️ Christmas Event (December)
  Widget _buildChristmasEvent() {
    return IgnorePointer(
      child: Material(
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

  Widget _buildHappyWomenEvent() {
    return IgnorePointer(
      child: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: Center(
            child: Lottie.asset(
              'assets/events/HappyWomen.json',
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

  Widget _buildRamadanEvent() {
    return IgnorePointer(
      child: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: Stack(
            children: [
              Positioned(
                right: 20,
                top: -20,
                child: Lottie.asset(
                  'assets/events/Moon Night Ramadan.json',
                  width: 150,
                  height: 150,
                  fit: BoxFit.contain,
                  repeat: true,
                ),
              ),
              // Family animation - positioned at bottom left
              Positioned(
                left: -5,
                bottom: -20,
                child: Lottie.asset(
                  'assets/events/Muslim family going to mosque.json',
                  width: 250, // Reduced size
                  height: 250, // Reduced size
                  fit: BoxFit.contain,
                  repeat: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEasterEvent() {
    return IgnorePointer(
      child: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: Center(
            child: Lottie.asset(
              'assets/events/Happy Easter.json',
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

  Widget _buildSinhalatamilNewYearEvent() {
    return IgnorePointer(
      child: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: Stack(
            children: [
              Positioned(
                right: 10,
                top: 20,
                child: Lottie.asset(
                  'assets/events/Lunarnewyear.json',
                  width: 200,
                  height: 200,
                  fit: BoxFit.contain,
                  repeat: true,
                ),
              ),
  
              // Positioned(
              //   left: -5,
              //   bottom: -20,
              //   child: Lottie.asset(
              //     'assets/events/Happy New Year.json',
              //     width: 250,
              //     height: 250,
              //     fit: BoxFit.contain,
              //     repeat: true,
              //   ),
              // ),
              SizedBox(
                width: double.infinity,
                height: double.infinity,
                child: Center(
                  child: Lottie.asset(
                    'assets/events/Happy New Year.json',
                    width: 500,
                    height: 500,
                    fit: BoxFit.contain,
                    repeat: true,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEarthDayEvent() {
    return IgnorePointer(
      child: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: Center(
            child: Lottie.asset(
              'assets/events/Earth day.json',
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

  Widget _buildLabourDayEvent() {
    return IgnorePointer(
      child: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: Center(
            child: Lottie.asset(
              'assets/events/Happy Labour Day.json',
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

  Widget _buildMotherDayEvent() {
    return IgnorePointer(
      child: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: Center(
            child: Lottie.asset(
              'assets/events/Happy mothers day.json',
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

  Widget _buildEidAlAdhaEvent() {
    return IgnorePointer(
      child: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: Center(
            child: Lottie.asset(
              'assets/events/Happy Eid al Adha.json',
              width: 600,
              height: 600,
              fit: BoxFit.contain,
              repeat: true,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSaveTheEarthEvent() {
    return IgnorePointer(
      child: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: Center(
            child: Lottie.asset(
              'assets/events/Save the Earth campaign.json',
              width: 600,
              height: 600,
              fit: BoxFit.contain,
              repeat: true,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFathersDayEvent() {
    return IgnorePointer(
      child: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: Center(
            child: Lottie.asset(
              'assets/events/Father Hugging his Daughter.json',
              width: 600,
              height: 600,
              fit: BoxFit.contain,
              repeat: true,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFriendsipDayEvent() {
    return IgnorePointer(
      child: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: Stack(
            children: [
              SizedBox(
                width: double.infinity,
                height: double.infinity,
                child: Center(
                  child: Lottie.asset(
                    'assets/events/friends.json',
                    width: 600,
                    height: 600,
                    fit: BoxFit.contain,
                    repeat: true,
                  ),
                ),
              ),
              // Family animation - positioned at bottom left
              Positioned(
                left: -5,
                bottom: -20,
                child: Lottie.asset(
                  'assets/events/Friendship Day.json',
                  width: 250, // Reduced size
                  height: 250, // Reduced size
                  fit: BoxFit.contain,
                  repeat: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildYouthDayEvent() {
    return IgnorePointer(
      child: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: Center(
            child: Lottie.asset(
              'assets/events/Youth Day.json',
              width: 600,
              height: 600,
              fit: BoxFit.contain,
              repeat: true,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPakisthanIndependenceEvent() {
    return IgnorePointer(
      child: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: Center(
            child: Lottie.asset(
              'assets/events/Pakistan flag.json',
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

  Widget _buildindianindependenceDayEvent() {
    return IgnorePointer(
      child: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: Stack(
            children: [
              SizedBox(
                width: double.infinity,
                height: double.infinity,
                child: Center(
                  child: Lottie.asset(
                    'assets/events/Indian Independence Day.json',
                    width: 600,
                    height: 600,
                    fit: BoxFit.contain,
                    repeat: true,
                  ),
                ),
              ),
              // Family animation - positioned at bottom left
              Positioned(
                // right: 20,
                top: -100,
                child: Lottie.asset(
                  'assets/events/Republic Day india.json',
                  width: 500, // Reduced size
                  height: 500, // Reduced size
                  fit: BoxFit.contain,
                  repeat: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRakshaBandhanEvent() {
    return IgnorePointer(
      child: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: Center(
            child: Lottie.asset(
              'assets/events/Raksha Bandhan.json',
              width: 600,
              height: 600,
              fit: BoxFit.contain,
              repeat: true,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHappyJanmashtamiEvent() {
    return IgnorePointer(
      child: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: Center(
            child: Lottie.asset(
              'assets/events/Happy Janmashtami.json',
              width: 600,
              height: 600,
              fit: BoxFit.contain,
              repeat: true,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGaneshChathurthiEvent() {
    return IgnorePointer(
      child: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: Center(
            child: Lottie.asset(
              'assets/events/Happy Ganesh Chathurthi.json',
              width: 600,
              height: 600,
              fit: BoxFit.contain,
              repeat: true,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPeaceDayEvent() {
    return IgnorePointer(
      child: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: Center(
            child: Lottie.asset(
              'assets/events/Peace Day.json',
              width: 600,
              height: 600,
              fit: BoxFit.contain,
              repeat: true,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAutumnFestivalEvent() {
    return IgnorePointer(
      child: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: Center(
            child: Lottie.asset(
              'assets/events/Mid-Autumn Festival Food.json',
              width: 600,
              height: 600,
              fit: BoxFit.contain,
              repeat: true,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTravellingBagsEvent() {
    return IgnorePointer(
      child: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: Center(
            child: Lottie.asset(
              'assets/events/Travelling Bags.json',
              width: 600,
              height: 600,
              fit: BoxFit.contain,
              repeat: true,
            ),
          ),
        ),
      ),
    );
  }

   Widget _buildHalloweenEvent() {
    return IgnorePointer(
      child: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: Stack(
            children: [
              SizedBox(
                width: double.infinity,
                height: double.infinity,
                child: Center(
                  child: Lottie.asset(
                    'assets/events/Halloween ghost.json',
                    width: 600,
                    height: 600,
                    fit: BoxFit.contain,
                    repeat: true,
                  ),
                ),
              ),
              // Family animation - positioned at bottom left
              Positioned(
                 right: 20,
                top: 10,
                child: Lottie.asset(
                  'assets/events/Searching.json',
                  width: 250, // Reduced size
                  height: 250, // Reduced size
                  fit: BoxFit.contain,
                  repeat: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  Widget _buildDiwaliEvent() {
    return IgnorePointer(
      child: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: Center(
            child: Lottie.asset(
              'assets/events/Diwali.json',
              width: 600,
              height: 600,
              fit: BoxFit.contain,
              repeat: true,
            ),
          ),
        ),
      ),
    );
  }
}
