class GameDetail {
  final String gameType;
  final int playTime;
  final String playDate;

  GameDetail({
    required this.gameType,
    required this.playTime,
    required this.playDate,
  });

  factory GameDetail.fromJson(Map<String, dynamic> json) {
    return GameDetail(
      gameType: json['GameType'],
      playTime: json['PlayTime'],
      playDate: json['PlayDate'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'GameType': gameType,
      'PlayTime': playTime,
      'PlayDate': playDate,
    };
  }
}

class GamesSummary {
  final int totalTimespent;
  final String mostPlayedGame;
  final List<GameDetail> gameDetails;

  GamesSummary({
    required this.totalTimespent,
    required this.mostPlayedGame,
    required this.gameDetails,
  });

  factory GamesSummary.fromJson(Map<String, dynamic> json) {
    // var list = json['gameDetails'] as List;
    // List<GameDetail> gameDetailsList =
    //     list.map((i) => GameDetail.fromJson(i)).toList();
final data = json['data'] ?? json;
  final rawList = data['GameDetails'] ?? data['gameDetails'] ?? [];
    final List<GameDetail> gameDetailsList = (rawList as List)
        .map((i) => GameDetail.fromJson(i))
        .toList();
    return GamesSummary(
      totalTimespent: data['totalTimespent']?? data['TotalTimeSpent'],
      mostPlayedGame: data['mostPlayedGame']?? data['MostPlayedGame'],
      gameDetails: gameDetailsList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalTimespent': totalTimespent,
      'mostPlayedGame': mostPlayedGame,
      'gameDetails':
          gameDetails.map((gameDetail) => gameDetail.toJson()).toList(),
    };
  }
}
