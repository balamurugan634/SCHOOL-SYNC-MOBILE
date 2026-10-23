import 'package:flutter/material.dart';

import '../../core/network/app_exception.dart';
import '../../core/util/site_address.dart';

class ConnectFailure {
  const ConnectFailure(this.title, this.message, this.icon, {this.tone = ConnectTone.error});
  final String title;
  final String message;
  final IconData icon;
  final ConnectTone tone;
}

enum ConnectTone { error, warning }

/// Plain-language explanation of why a school could not be verified.
ConnectFailure describeConnectFailure(Object error, {String? host}) {
  if (error is SiteInputException) {
    return ConnectFailure('Check the address', error.message, Icons.edit_note_rounded, tone: ConnectTone.warning);
  }
  final ex = AppException.from(error);
  final where = host ?? 'the school';
  switch (ex.code) {
    case 'SITE_NOT_FOUND':
      return const ConnectFailure(
        'School not found',
        'We could not find a school with that code or address. Check the spelling, or ask your school office for the correct one.',
        Icons.search_off_rounded,
      );
    case 'SITE_SUSPENDED':
      return const ConnectFailure(
        'School unavailable',
        'This school\'s SchoolSync account is suspended. Please contact the school office.',
        Icons.pause_circle_outline_rounded,
      );
    case 'NOT_SCHOOLSYNC':
    case 'ROUTE_NOT_FOUND':
      return const ConnectFailure(
        'Not a SchoolSync address',
        'That address answered, but it does not look like a SchoolSync school. Check the web address you were given.',
        Icons.link_off_rounded,
      );
  }
  switch (ex.kind) {
    case ErrorKind.network:
      return ConnectFailure('Cannot reach $where', 'Check your internet connection and the address, then try again.', Icons.wifi_off_rounded);
    case ErrorKind.timeout:
      return ConnectFailure('$where is not responding', 'The connection timed out. Check your internet and try again in a moment.', Icons.timer_off_outlined);
    case ErrorKind.badCertificate:
      return const ConnectFailure(
        'Secure connection failed',
        'We could not verify that this address is secure. For your safety the connection was refused.',
        Icons.gpp_bad_outlined,
      );
    case ErrorKind.forbidden:
      return ConnectFailure('Access refused', ex.displayMessage, Icons.block_rounded);
    case ErrorKind.notFound:
      return const ConnectFailure('School not found', 'We could not find a school at that address.', Icons.search_off_rounded);
    case ErrorKind.server:
      return const ConnectFailure('The school\'s server has a problem', 'Please try again in a few minutes.', Icons.cloud_off_rounded);
    case ErrorKind.rateLimited:
      return const ConnectFailure('Too many attempts', 'Please wait a minute and try again.', Icons.hourglass_top_rounded, tone: ConnectTone.warning);
    default:
      return ConnectFailure('Could not connect', ex.displayMessage, Icons.error_outline_rounded);
  }
}
