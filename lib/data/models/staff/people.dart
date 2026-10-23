import '../../json.dart';

/// A class section as the academic structure returns it (`GET /academics/sections`).
class SectionItem {
  const SectionItem({required this.id, required this.gradeId, required this.gradeName, required this.name, this.room, this.capacity, this.classTeacherId, this.classTeacherName, this.studentCount = 0, this.gradeOrdinal = 0});

  final String id;
  final String gradeId;
  final String gradeName;
  final int gradeOrdinal;
  final String name;
  final String? room;
  final int? capacity;
  final String? classTeacherId;
  final String? classTeacherName;
  final int studentCount;

  /// "Grade 6 A".
  String get title => '$gradeName $name'.trim();

  factory SectionItem.fromJson(Json j) => SectionItem(
    id: jStrOr(j['id']),
    gradeId: jStrOr(j['gradeId']),
    gradeName: jStrOr(j['gradeName']),
    gradeOrdinal: jInt(j['gradeOrdinal']),
    name: jStrOr(j['name']),
    room: jStr(j['room']),
    capacity: jIntN(j['capacity']),
    classTeacherId: jStr(j['classTeacherId']),
    classTeacherName: jStr(j['classTeacherName']),
    studentCount: jInt(j['studentCount']),
  );
}

class SectionTeaching {
  const SectionTeaching({required this.id, required this.subjectId, required this.subjectName, required this.staffId, required this.staffName, this.subjectCode = ''});
  final String id;
  final String subjectId;
  final String subjectCode;
  final String subjectName;
  final String staffId;
  final String staffName;

  factory SectionTeaching.fromJson(Json j) => SectionTeaching(id: jStrOr(j['id']), subjectId: jStrOr(j['subjectId']), subjectCode: jStrOr(j['subjectCode']), subjectName: jStrOr(j['subjectName']), staffId: jStrOr(j['staffId']), staffName: jStrOr(j['staffName']));
}

class SectionDetail {
  const SectionDetail({required this.section, this.teaching = const []});
  final SectionItem section;
  final List<SectionTeaching> teaching;

  factory SectionDetail.fromJson(Json j) => SectionDetail(section: SectionItem.fromJson(j), teaching: jsonList(j['teachingAssignments']).map(SectionTeaching.fromJson).toList(growable: false));
}

/// A (section, subject) pair taught by the signed-in teacher (`GET /academics/teaching-assignments?staffId=`).
class MyAssignment {
  const MyAssignment({required this.sectionId, required this.sectionName, required this.gradeId, required this.gradeName, required this.subjectId, required this.subjectName, this.periodsPerWeek});
  final String sectionId;
  final String sectionName;
  final String gradeId;
  final String gradeName;
  final String subjectId;
  final String subjectName;
  final int? periodsPerWeek;

  String get sectionTitle => '$gradeName $sectionName'.trim();

  factory MyAssignment.fromJson(Json j) => MyAssignment(
    sectionId: jStrOr(j['sectionId']),
    sectionName: jStrOr(j['sectionName']),
    gradeId: jStrOr(j['gradeId']),
    gradeName: jStrOr(j['gradeName']),
    subjectId: jStrOr(j['subjectId']),
    subjectName: jStrOr(j['subjectName']),
    periodsPerWeek: jIntN(j['periodsPerWeek']),
  );
}

class Grade {
  const Grade({required this.id, required this.name, this.ordinal = 0});
  final String id;
  final String name;
  final int ordinal;
  factory Grade.fromJson(Json j) => Grade(id: jStrOr(j['id']), name: jStrOr(j['name']), ordinal: jInt(j['ordinal']));
}

/// A row of the student list (`GET /students`).
class StudentRow {
  const StudentRow({required this.id, required this.admissionNo, required this.name, this.gender, this.dob, this.photoUrl, this.status = 'active', this.gradeName, this.sectionId, this.sectionName, this.rollNo});
  final String id;
  final String admissionNo;
  final String name;
  final String? gender;
  final DateTime? dob;
  final String? photoUrl;
  final String status;
  final String? gradeName;
  final String? sectionId;
  final String? sectionName;
  final int? rollNo;

  String get classLabel {
    final parts = [gradeName, sectionName].where((e) => e != null && e.isNotEmpty).cast<String>().toList();
    return parts.isEmpty ? 'Not assigned to a class' : parts.join(' ');
  }

  factory StudentRow.fromJson(Json j) => StudentRow(
    id: jStrOr(j['id']),
    admissionNo: jStrOr(j['admissionNo']),
    name: jStrOr(j['name']),
    gender: jStr(j['gender']),
    dob: jDay(j['dob']),
    photoUrl: jStr(j['photoUrl']),
    status: jStrOr(j['status'], 'active'),
    gradeName: jStr(j['gradeName']),
    sectionId: jStr(j['sectionId']),
    sectionName: jStr(j['sectionName']),
    rollNo: jIntN(j['rollNo']),
  );
}

class GuardianLink {
  const GuardianLink({required this.guardianId, required this.name, required this.relationship, this.isPrimary = false, this.verified = false, this.phone, this.email, this.canPickup = false, this.isEmergencyContact = false});
  final String guardianId;
  final String name;
  final String relationship;
  final bool isPrimary;
  final bool verified;
  final bool canPickup;
  final bool isEmergencyContact;

  /// Hidden by the API from callers without guardians:view.
  final String? phone;
  final String? email;

  factory GuardianLink.fromJson(Json j) => GuardianLink(
    guardianId: jStrOr(j['guardianId']),
    name: jStrOr(j['name']),
    relationship: jStrOr(j['relationship'], 'guardian'),
    isPrimary: jBool(j['isPrimary']),
    verified: jBool(j['verified']),
    canPickup: jBool(j['canPickup']),
    isEmergencyContact: jBool(j['isEmergencyContact']),
    phone: jStr(j['phone']),
    email: jStr(j['email']),
  );
}

class ContactPerson {
  const ContactPerson({required this.name, this.relationship, this.phone});
  final String name;
  final String? relationship;
  final String? phone;
  factory ContactPerson.fromJson(Json j) => ContactPerson(name: jStrOr(j['name']), relationship: jStr(j['relationship']), phone: jStr(j['phone']));
}

/// `GET /students/:id`. Medical notes and documents only appear when the API permits.
class StudentDetail {
  const StudentDetail({required this.row, this.bloodGroup, this.address, this.admissionDate, this.guardians = const [], this.emergencyContacts = const [], this.medicalNotes});
  final StudentRow row;
  final String? bloodGroup;
  final String? address;
  final DateTime? admissionDate;
  final List<GuardianLink> guardians;
  final List<ContactPerson> emergencyContacts;
  final String? medicalNotes;

  factory StudentDetail.fromJson(Json j) {
    final a = jsonMap(j['address']);
    final addr = [a['line1'], a['line2'], a['city'], a['state'], a['postalCode']].where((e) => e != null && '$e'.trim().isNotEmpty).join(', ');
    return StudentDetail(
      row: StudentRow.fromJson(j),
      bloodGroup: jStr(j['bloodGroup']),
      address: addr.isEmpty ? null : addr,
      admissionDate: jDay(j['admissionDate']),
      guardians: jsonList(j['guardians']).map(GuardianLink.fromJson).toList(growable: false),
      emergencyContacts: jsonList(j['emergencyContacts']).map(ContactPerson.fromJson).toList(growable: false),
      medicalNotes: jStr(j['medicalNotes']),
    );
  }
}

/// A row of the staff directory (`GET /staff`).
class StaffMember {
  const StaffMember({required this.id, required this.employeeId, required this.name, this.designation, this.department, this.staffType = 'teaching', this.status = 'active', this.email, this.phone, this.photoUrl, this.roles = const []});
  final String id;
  final String employeeId;
  final String name;
  final String? designation;
  final String? department;
  final String staffType;
  final String status;
  final String? email;
  final String? phone;
  final String? photoUrl;
  final List<String> roles;

  factory StaffMember.fromJson(Json j) => StaffMember(
    id: jStrOr(j['id']),
    employeeId: jStrOr(j['employeeId']),
    name: jStrOr(j['name']),
    designation: jStr(j['designation']),
    department: jStr(j['department']),
    staffType: jStrOr(j['staffType'], 'teaching'),
    status: jStrOr(j['status'], 'active'),
    email: jStr(j['email']),
    phone: jStr(j['phone']),
    photoUrl: jStr(j['photoUrl']),
    roles: [for (final r in (j['roles'] is List ? j['roles'] as List : const [])) '$r'],
  );
}

class StaffWorkload {
  const StaffWorkload({this.sectionsLed = const [], this.assignments = const [], this.periodsPerWeek = 0});
  final List<String> sectionsLed;
  final List<String> assignments;
  final int periodsPerWeek;

  factory StaffWorkload.fromJson(Json j) => StaffWorkload(
    sectionsLed: [for (final s in jsonList(j['sectionsLed'])) '${jStrOr(s['gradeName'])} ${jStrOr(s['sectionName'])}'.trim()],
    assignments: [for (final a in jsonList(j['assignments'])) '${jStrOr(a['subjectName'])} · ${jStrOr(a['gradeName'])} ${jStrOr(a['sectionName'])}'.trim()],
    periodsPerWeek: jInt(jsonMap(j['totals'])['periodsPerWeek']),
  );
}

/// An admission application (`GET /admissions`).
class AdmissionApplication {
  const AdmissionApplication({required this.id, required this.applicationNo, required this.name, this.dob, this.gradeAppliedName, this.guardianName = '', this.guardianPhone = '', this.previousSchool, this.notes, required this.status, this.decisionNote, this.createdAt});
  final String id;
  final String applicationNo;
  final String name;
  final DateTime? dob;
  final String? gradeAppliedName;
  final String guardianName;
  final String guardianPhone;
  final String? previousSchool;
  final String? notes;

  /// submitted | under_review | waitlisted | accepted | rejected | enrolled
  final String status;
  final String? decisionNote;
  final DateTime? createdAt;

  factory AdmissionApplication.fromJson(Json j) => AdmissionApplication(
    id: jStrOr(j['id']),
    applicationNo: jStrOr(j['applicationNo']),
    name: jStrOr(j['name']),
    dob: jDay(j['dob']),
    gradeAppliedName: jStr(j['gradeAppliedName']),
    guardianName: jStrOr(j['guardianName']),
    guardianPhone: jStrOr(j['guardianPhone']),
    previousSchool: jStr(j['previousSchool']),
    notes: jStr(j['notes']),
    status: jStrOr(j['status'], 'submitted'),
    decisionNote: jStr(j['decisionNote']),
    createdAt: jDate(j['createdAt']),
  );
}

/// `GET /staff/:id`: the directory row plus the extra detail fields.
class StaffDetail {
  const StaffDetail({required this.member, this.joinDate, this.qualification, this.username, this.userStatus});
  final StaffMember member;
  final DateTime? joinDate;
  final String? qualification;
  final String? username;

  /// invited | active | suspended | deactivated
  final String? userStatus;

  factory StaffDetail.fromJson(Json j) => StaffDetail(member: StaffMember.fromJson(j), joinDate: jDay(j['joinDate']), qualification: jStr(j['qualification']), username: jStr(j['username']), userStatus: jStr(j['userStatus']));
}
