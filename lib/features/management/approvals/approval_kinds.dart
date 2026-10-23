import 'package:flutter/material.dart';

import '../../../data/models/me.dart';
import '../../../data/models/staff/dashboards.dart';
import '../../../router/routes.dart';
import '../../../router/routes_management.dart';

/// What one approval queue is, who may see it and who may decide in it.
class ApprovalKindSpec {
  const ApprovalKindSpec({
    required this.kind,
    required this.label,
    required this.icon,
    required this.viewAny,
    required this.actPermission,
    required this.statuses,
    required this.count,
    required this.emptyTitle,
    required this.emptyMessage,
    this.needsFees = false,
  });

  /// One of [ApprovalKind].
  final String kind;
  final String label;
  final IconData icon;

  /// The queue can be opened with any of these permissions (the API still enforces scope).
  final List<String> viewAny;

  /// Needed to approve / reject (details stay read-only without it).
  final String actPermission;

  /// Status filter chips: (API value, label). The first is the default ("waiting for a decision").
  final List<(String, String)> statuses;
  final int? Function(ApprovalCounts) count;
  final String emptyTitle;
  final String emptyMessage;

  /// Only exists when the school has the fees module on.
  final bool needsFees;

  bool canView(Me me) => me.canAny(viewAny) || me.can(actPermission);
  bool canAct(Me me) => me.can(actPermission);
}

const approvalSpecs = <ApprovalKindSpec>[
  ApprovalKindSpec(
    kind: ApprovalKind.studentLeave,
    label: 'Student leave',
    icon: Icons.event_busy_outlined,
    viewAny: ['leave:view'],
    actPermission: 'leave:approve',
    statuses: [('pending', 'Pending'), ('approved', 'Approved'), ('rejected', 'Rejected')],
    count: _studentLeave,
    emptyTitle: 'No leave requests',
    emptyMessage: 'Requests from parents and students will appear here.',
  ),
  ApprovalKindSpec(
    kind: ApprovalKind.staffLeave,
    label: 'Staff leave',
    icon: Icons.beach_access_outlined,
    viewAny: ['staff_leave:view'],
    actPermission: 'staff_leave:approve',
    statuses: [('pending', 'Pending'), ('approved', 'Approved'), ('rejected', 'Rejected')],
    count: _staffLeave,
    emptyTitle: 'No staff leave requests',
    emptyMessage: 'Requests from teachers and staff will appear here.',
  ),
  ApprovalKindSpec(
    kind: ApprovalKind.attendance,
    label: 'Attendance corrections',
    icon: Icons.rule_rounded,
    viewAny: ['attendance:view'],
    actPermission: 'attendance:approve',
    statuses: [('pending', 'Pending'), ('approved', 'Approved'), ('rejected', 'Rejected')],
    count: _corrections,
    emptyTitle: 'No correction requests',
    emptyMessage: 'Teachers ask here to change a saved roll call after the edit window closes.',
  ),
  ApprovalKindSpec(
    kind: ApprovalKind.marks,
    label: 'Mark sheets',
    icon: Icons.grading_rounded,
    viewAny: ['marks:view'],
    actPermission: 'marks:approve',
    statuses: [('submitted', 'To review'), ('approved', 'Approved'), ('returned', 'Returned')],
    count: _marks,
    emptyTitle: 'No mark sheets to review',
    emptyMessage: 'Sheets teachers submit for review will appear here.',
  ),
  ApprovalKindSpec(
    kind: ApprovalKind.concessions,
    label: 'Fee concessions',
    icon: Icons.percent_rounded,
    viewAny: ['fees:view'],
    actPermission: 'fees:approve',
    statuses: [('pending', 'Pending'), ('approved', 'Approved'), ('rejected', 'Rejected')],
    count: _concessions,
    needsFees: true,
    emptyTitle: 'No concession requests',
    emptyMessage: 'Concessions and scholarships waiting for approval will appear here.',
  ),
  ApprovalKindSpec(
    kind: ApprovalKind.refunds,
    label: 'Refunds',
    icon: Icons.currency_rupee_rounded,
    viewAny: ['payments:view'],
    actPermission: 'payments:approve',
    statuses: [('requested', 'Requested'), ('approved', 'Approved'), ('processed', 'Processed'), ('rejected', 'Rejected')],
    count: _refunds,
    needsFees: true,
    emptyTitle: 'No refund requests',
    emptyMessage: 'Refund requests waiting for approval will appear here.',
  ),
  ApprovalKindSpec(
    kind: ApprovalKind.expenses,
    label: 'Expenses',
    icon: Icons.request_quote_outlined,
    viewAny: ['expenses:view'],
    actPermission: 'expenses:approve',
    statuses: [('pending', 'Pending'), ('approved', 'Approved'), ('rejected', 'Rejected')],
    count: _expenses,
    needsFees: true,
    emptyTitle: 'No expenses to approve',
    emptyMessage: 'Expenses above the approval limit will appear here.',
  ),
  ApprovalKindSpec(
    kind: ApprovalKind.admissions,
    label: 'Admissions',
    icon: Icons.how_to_reg_outlined,
    viewAny: ['admissions:view'],
    actPermission: 'admissions:approve',
    statuses: [('submitted', 'New'), ('under_review', 'Under review'), ('waitlisted', 'Waitlisted'), ('accepted', 'Accepted'), ('rejected', 'Rejected')],
    count: _admissions,
    emptyTitle: 'No applications',
    emptyMessage: 'Applications will appear here as they come in.',
  ),
];

int? _studentLeave(ApprovalCounts c) => c.studentLeave;
int? _staffLeave(ApprovalCounts c) => c.staffLeave;
int? _corrections(ApprovalCounts c) => c.attendanceCorrections;
int? _marks(ApprovalCounts c) => c.markSheetsForReview;
int? _concessions(ApprovalCounts c) => c.concessions;
int? _refunds(ApprovalCounts c) => c.refunds;
int? _expenses(ApprovalCounts c) => c.expenses;
int? _admissions(ApprovalCounts c) => c.admissions;

ApprovalKindSpec? approvalSpecFor(String kind) {
  for (final s in approvalSpecs) {
    if (s.kind == kind) return s;
  }
  return null;
}

/// The queues to show in the home card / hub: the dashboard returned a count (null = the caller cannot act on it),
/// the person may open it, and the school has the module.
List<(ApprovalKindSpec, int)> visibleQueues(ApprovalCounts counts, Me me, {required bool feesEnabled}) => [
  for (final s in approvalSpecs)
    if ((!s.needsFees || feesEnabled) && s.count(counts) != null && s.canView(me)) (s, s.count(counts)!),
];

/// Can this person open the queue [kind] at all (permission and module)?
bool canOpenApproval(ApprovalKindSpec spec, Me me, {required bool feesEnabled}) => (!spec.needsFees || feesEnabled) && spec.canView(me);

/// Where an alert's server route leads inside the app, or null when the app has no such screen.
String? appRouteForAlert(String? route) {
  if (route == null || !route.startsWith('/')) return null;
  final path = Uri.tryParse(route)?.path ?? route;
  bool under(String p) => path == p || path.startsWith('$p/');
  if (under('/attendance')) return ManagementRoutes.attendance;
  if (under('/leave')) return ManagementRoutes.approval(ApprovalKind.studentLeave);
  if (under('/staff-leave')) return ManagementRoutes.approval(ApprovalKind.staffLeave);
  if (under('/admissions')) return ManagementRoutes.approval(ApprovalKind.admissions);
  if (under('/marks') || under('/exams')) return ManagementRoutes.approval(ApprovalKind.marks);
  if (under('/fees') || under('/finance')) return Routes.tab(3);
  if (under('/announcements')) return ManagementRoutes.announcements;
  if (under('/meetings')) return ManagementRoutes.meetings;
  return null;
}

/// One status change an admissions officer can make.
class AdmissionMove {
  const AdmissionMove({required this.to, required this.label, required this.consequence, this.noteRequired = false, this.destructive = false});
  final String to;
  final String label;
  final String consequence;
  final bool noteRequired;
  final bool destructive;
}

const _admissionTransitions = <String, List<String>>{
  'submitted': ['under_review', 'rejected'],
  'under_review': ['waitlisted', 'accepted', 'rejected'],
  'waitlisted': ['under_review', 'accepted', 'rejected'],
  'accepted': ['rejected'],
  'rejected': ['under_review'],
  'enrolled': [],
};

/// The moves the API allows from [from] (mirrors its transition table) that this person holds the permission for:
/// starting a review from "submitted" needs `admissions:edit`, every other move needs `admissions:approve`.
List<AdmissionMove> admissionMoves(String from, {required bool canEdit, required bool canApprove}) {
  AdmissionMove? move(String to) {
    final needsEdit = to == 'under_review' && from == 'submitted';
    if (needsEdit ? !canEdit : !canApprove) return null;
    return switch (to) {
      'under_review' => AdmissionMove(to: to, label: from == 'rejected' ? 'Reopen for review' : (from == 'waitlisted' ? 'Back to review' : 'Start review'), consequence: 'The application moves to "Under review". The family is not notified.'),
      'waitlisted' => const AdmissionMove(to: 'waitlisted', label: 'Waitlist', consequence: 'The applicant goes on the waiting list until a seat is free.'),
      'accepted' => const AdmissionMove(to: 'accepted', label: 'Accept', consequence: 'The application is accepted. The office can then enrol the student.'),
      'rejected' => const AdmissionMove(to: 'rejected', label: 'Reject', consequence: 'The application is rejected and your reason is kept on record.', noteRequired: true, destructive: true),
      _ => null,
    };
  }

  return [for (final to in _admissionTransitions[from] ?? const <String>[]) ?move(to)];
}
