import 'package:uuid/uuid_value.dart';

import 'resources.dart';

export 'resources.dart';

class ReadClient {
  ReadClient(this.entries);
  final ReadEndpoint entries;
}

class ReadEndpoint {
  Future<EntryPage> list(EntryQuery query) async =>
      EntryPage(records: [], totalCount: 0);
  Future<EntryView?> get({required UuidValue id}) async => null;
  Future<List<EntryView>> create(EntryInput input) async => [];
  Future<bool> edit(UuidValue id, EntryInput input) async => true;
}
