import 'dart:async';

import 'package:firedart/firedart.dart' show Emulator;
import 'package:firedart/generated/google/firestore/v1/document.pb.dart';
import 'package:firedart/generated/google/firestore/v1/firestore.pbgrpc.dart';
import 'package:firedart/generated/google/firestore/v1/query.pb.dart';
import 'package:grpc/grpc.dart';

class FirestoreSnapshotData {
  final List<Map<String, dynamic>> tasks;
  final List<Map<String, dynamic>> entries;
  final List<Map<String, dynamic>> timers;

  FirestoreSnapshotData(this.tasks, this.entries, this.timers);
}

/// A single Firestore Listen RPC for all three user collections. CURRENT and
/// read-time markers matter: an empty collection still has an initial snapshot.
class FirestoreWatch {
  final String projectId;
  final Future<String> Function() idToken;
  final ClientChannel _channel;
  late final FirestoreClient _client = FirestoreClient(
    _channel,
    options: CallOptions(providers: [
      (metadata, _) async {
        metadata['authorization'] = 'Bearer ${await idToken()}';
      }
    ]),
  );

  FirestoreWatch(this.projectId, this.idToken, {Emulator? emulator})
      : _channel = emulator == null
            ? ClientChannel('firestore.googleapis.com')
            : ClientChannel(emulator.host,
                port: emulator.port,
                options: const ChannelOptions(
                    credentials: ChannelCredentials.insecure()));

  Stream<FirestoreSnapshotData> snapshots(String uid) async* {
    final database = 'projects/$projectId/databases/(default)';
    final parent = '$database/documents/users/$uid';
    final requests = StreamController<ListenRequest>();
    final call = _client.listen(requests.stream,
        options:
            CallOptions(metadata: {'google-cloud-resource-prefix': database}));
    const names = ['tasks', 'entries', 'active_timers'];
    final data = {
      for (var id = 1; id <= names.length; id++)
        id: <String, Map<String, dynamic>>{}
    };
    final current = <int>{};

    for (var i = 0; i < names.length; i++) {
      requests.add(ListenRequest()
        ..database = database
        ..addTarget = (Target()
          ..targetId = i + 1
          ..query = (Target_QueryTarget()
            ..parent = parent
            ..structuredQuery = (StructuredQuery()
              ..from.add(StructuredQuery_CollectionSelector()
                ..collectionId = names[i])))));
    }
    try {
      await for (final response in call) {
        if (response.hasDocumentChange()) {
          final change = response.documentChange;
          final map = change.document.fields
              .map((key, value) => MapEntry(key, _decode(value)));
          for (final id in change.targetIds) {
            data[id]?[change.document.name] = map;
          }
          for (final id in change.removedTargetIds) {
            data[id]?.remove(change.document.name);
          }
        } else if (response.hasDocumentDelete()) {
          for (final id in response.documentDelete.removedTargetIds) {
            data[id]?.remove(response.documentDelete.document);
          }
        } else if (response.hasDocumentRemove()) {
          for (final id in response.documentRemove.removedTargetIds) {
            data[id]?.remove(response.documentRemove.document);
          }
        } else if (response.hasTargetChange()) {
          final change = response.targetChange;
          if (change.hasCause() && change.cause.code != 0) {
            throw StateError(
                'Firestore listen failed: ${change.cause.message}');
          }
          if (change.targetChangeType ==
              TargetChange_TargetChangeType.CURRENT) {
            current.addAll(change.targetIds);
          } else if (change.targetChangeType ==
              TargetChange_TargetChangeType.RESET) {
            for (final id in change.targetIds) {
              data[id]?.clear();
              current.remove(id);
            }
          }
          if (current.length == names.length && change.hasReadTime()) {
            yield FirestoreSnapshotData(data[1]!.values.toList(),
                data[2]!.values.toList(), data[3]!.values.toList());
          }
        }
      }
    } finally {
      await call.cancel();
      await requests.close();
    }
  }

  static dynamic _decode(Value value) {
    if (value.hasStringValue()) return value.stringValue;
    if (value.hasIntegerValue()) return value.integerValue.toInt();
    if (value.hasDoubleValue()) return value.doubleValue;
    if (value.hasBooleanValue()) return value.booleanValue;
    if (value.hasNullValue()) return null;
    if (value.hasMapValue()) {
      return value.mapValue.fields
          .map((key, value) => MapEntry(key, _decode(value)));
    }
    if (value.hasArrayValue()) {
      return value.arrayValue.values.map(_decode).toList();
    }
    if (value.hasTimestampValue()) return value.timestampValue.toDateTime();
    throw FormatException(
        'Unsupported Firestore value: ${value.whichValueType()}');
  }

  Future<void> close() => _channel.terminate();
}
