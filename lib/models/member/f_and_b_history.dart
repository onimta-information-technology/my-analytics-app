class NongameDetail {
  final String product;
  final String deptName;
  final String orderTime;
  final String orderDate;
  final double amount;

  NongameDetail({
    required this.product,
    required this.deptName,
    required this.orderTime,
    required this.orderDate,
    required this.amount,
  });

  factory NongameDetail.fromJson(Map<String, dynamic> json) {
    return NongameDetail(
      product: json['Product'],
      deptName: json['Dept_Name'],
      orderTime: json['OrderTime'],
      orderDate: json['OrderDate'],
      amount: json['Amount'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Product': product,
      'Dept_Name': deptName,
      'OrderTime': orderTime,
      'OrderDate': orderDate,
      'Amount': amount,
    };
  }
}

class FAndBHistory {
  final String mostOrderedBeverage;
  final String mostOrderedTobacco;
  final String mostOrderedFood;
  final double totalCost;
  final List<NongameDetail> nongameDetails;

  FAndBHistory({
    required this.mostOrderedBeverage,
    required this.mostOrderedTobacco,
    required this.mostOrderedFood,
    required this.totalCost,
    required this.nongameDetails,
  });

  factory FAndBHistory.fromJson(Map<String, dynamic> json) {
    var list = json['NongameDetails'] as List;
    List<NongameDetail> nongameDetailsList = list.map((i) => NongameDetail.fromJson(i)).toList();

    return FAndBHistory(
      mostOrderedBeverage: json['MostOrderedBeverage'],
      mostOrderedTobacco: json['MostOrderedTobacco'],
      mostOrderedFood: json['MostOrderedFood'],
      totalCost: json['Total_Cost'],
      nongameDetails: nongameDetailsList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'MostOrderedBeverage': mostOrderedBeverage,
      'MostOrderedTobacco': mostOrderedTobacco,
      'MostOrderedFood': mostOrderedFood,
      'Total_Cost': totalCost,
      'NongameDetails': nongameDetails.map((e) => e.toJson()).toList(),
    };
  }
}