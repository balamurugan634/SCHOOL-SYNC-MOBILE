import '../json.dart';

class EmergencyContact {
  const EmergencyContact({required this.name, required this.phone, this.relationship});
  final String name;
  final String phone;
  final String? relationship;
  factory EmergencyContact.fromJson(Json j) => EmergencyContact(name: jStrOr(j['name']), phone: jStrOr(j['phone']), relationship: jStr(j['relationship']));
}

class ChildContacts {
  const ChildContacts({required this.studentId, required this.studentName, required this.contacts});
  final String studentId;
  final String studentName;
  final List<EmergencyContact> contacts;
  factory ChildContacts.fromJson(Json j) => ChildContacts(studentId: jStrOr(j['studentId']), studentName: jStrOr(j['studentName']), contacts: jsonList(j['contacts']).map(EmergencyContact.fromJson).toList(growable: false));
}

class ProfileDetails {
  const ProfileDetails({required this.displayName, required this.username, this.email, this.phone, this.address, this.avatarUrl, this.emergency = const []});
  final String displayName;
  final String username;
  final String? email;
  final String? phone;
  final String? address;
  final String? avatarUrl;
  final List<ChildContacts> emergency;

  factory ProfileDetails.fromJson(Json j) {
    final a = j['address'] is Map ? jsonMap(j['address']) : const <String, dynamic>{};
    final addr = [a['line1'], a['line2'], a['city'], a['state'], a['postalCode']].map(jStr).whereType<String>().where((s) => s.isNotEmpty).join(', ');
    return ProfileDetails(
      displayName: jStrOr(j['displayName']),
      username: jStrOr(j['username']),
      email: jStr(j['email']),
      phone: jStr(j['phone']),
      address: addr.isEmpty ? null : addr,
      avatarUrl: jStr(j['avatarUrl']),
      emergency: jsonList(j['emergencyContacts']).map(ChildContacts.fromJson).toList(growable: false),
    );
  }
}
