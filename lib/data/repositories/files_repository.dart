import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/network/api_client.dart';
import '../../core/providers.dart';
import '../json.dart';

/// File upload (`POST /files`) and authenticated download (`GET /files/{id}`, PDFs).
class FilesRepository {
  FilesRepository(this._api);
  final ApiClient _api;

  /// Uploads [path] and returns the attachment record to embed in a submission/leave request.
  Future<Attachment> upload(String path, {String? name, String purpose = 'submission', void Function(int, int)? onProgress}) async {
    final body = jsonMap(await _api.upload('/files', filePath: path, fileName: name, fields: {'purpose': purpose}, query: {'purpose': purpose}, onProgress: onProgress));
    return Attachment.fromJson(jsonMap(body['attachment']).isNotEmpty ? jsonMap(body['attachment']) : body);
  }

  /// Downloads to the temp directory and opens with the system viewer.
  Future<void> openFile(String apiPath, {required String fileName}) async {
    final bytes = await _api.download(apiPath);
    final dir = await getTemporaryDirectory();
    final safe = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final f = File('${dir.path}/$safe');
    await f.writeAsBytes(bytes, flush: true);
    await OpenFilex.open(f.path);
  }

  Future<void> openStored(Attachment a) => openFile('/files/${a.fileId}', fileName: a.name);
  Future<void> openFileId(String fileId, {String name = 'file'}) => openFile('/files/$fileId', fileName: name);
}

final filesRepositoryProvider = Provider<FilesRepository>((ref) => FilesRepository(ref.watch(apiClientProvider)));
