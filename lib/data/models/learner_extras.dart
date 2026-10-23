import '../json.dart';

class LibraryLoan {
  const LibraryLoan({required this.id, required this.title, required this.status, this.author, this.issuedOn, this.dueOn, this.returnedOn, this.daysOverdue = 0, this.fineMinor = 0});
  final String id;
  final String title;
  final String? author;
  final DateTime? issuedOn;
  final DateTime? dueOn;
  final DateTime? returnedOn;

  /// issued | overdue | returned ...
  final String status;
  final int daysOverdue;
  final int fineMinor;

  bool get overdue => status == 'overdue';

  factory LibraryLoan.fromJson(Json j) {
    final book = jsonMap(j['book']);
    return LibraryLoan(
      id: jStrOr(j['id']),
      title: jStrOr(book['title']),
      author: jStr(book['author']),
      issuedOn: jDay(j['issuedOn']),
      dueOn: jDay(j['dueOn']),
      returnedOn: jDay(j['returnedOn']),
      status: jStrOr(j['status']),
      daysOverdue: jInt(j['daysOverdue']),
      fineMinor: jInt(j['fineMinor']),
    );
  }
}

class BusAllocation {
  const BusAllocation({required this.studentName, required this.allocated, this.routeName, this.stopName, this.pickupTime, this.dropTime, this.vehicle, this.driverName, this.driverPhone, this.attendantName});
  final String studentName;
  final bool allocated;
  final String? routeName;
  final String? stopName;
  final String? pickupTime;
  final String? dropTime;
  final String? vehicle;
  final String? driverName;
  final String? driverPhone;
  final String? attendantName;

  factory BusAllocation.fromJson(Json j) {
    final stop = jsonMap(j['stop']);
    final veh = jsonMap(j['vehicle']);
    final driver = jsonMap(j['driver']);
    return BusAllocation(
      studentName: jStrOr(j['studentName']),
      allocated: jBool(j['allocated']),
      routeName: jStr(jsonMap(j['route'])['name']),
      stopName: jStr(stop['name']),
      pickupTime: jStr(stop['pickupTime']),
      dropTime: jStr(stop['dropTime']),
      vehicle: [jStr(veh['model']), jStr(veh['registrationNo'])].whereType<String>().join(' · '),
      driverName: jStr(driver['name']),
      driverPhone: jStr(driver['phone']),
      attendantName: jStr(j['attendantName']),
    );
  }
}
