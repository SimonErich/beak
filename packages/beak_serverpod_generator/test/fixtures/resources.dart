import 'package:uuid/uuid_value.dart';

enum ResourceStatus { active, paused }

enum ResourceSort { title, status }

class Entry {
  Entry({
    required this.id,
    required this.title,
    required this.status,
    this.email,
  });
  final UuidValue id;
  final String title;
  final ResourceStatus status;
  final String? email;
}

class EntryView {
  EntryView({required this.entry});
  final Entry entry;
}

class EntryInput {
  EntryInput({
    required this.title,
    required this.status,
    required this.email,
    required this.roleIds,
  });
  final String title;
  final ResourceStatus status;
  final String email;
  final List<UuidValue> roleIds;
}

class EntryQuery {
  EntryQuery({
    this.page = 0,
    this.pageSize = 25,
    this.search,
    this.sort = ResourceSort.title,
    this.descending = true,
    this.status,
    this.includeArchived = false,
  });
  final int page;
  final int pageSize;
  final String? search;
  final ResourceSort sort;
  final bool descending;
  final ResourceStatus? status;
  final bool includeArchived;
}

class EntryPage {
  EntryPage({required this.records, required this.totalCount});
  final List<EntryView> records;
  final int totalCount;
}

class Client {
  Client(this.entry);
  final EntryEndpoint entry;
}

class EntryEndpoint {
  EntryEndpoint(this.value);
  EntryView value;
  EntryQuery? lastQuery;
  String? lastLocale;
  int writes = 0;
  Future<EntryPage> list({
    required EntryQuery query,
    required String locale,
  }) async {
    lastQuery = query;
    lastLocale = locale;
    return EntryPage(records: [value], totalCount: 42);
  }

  Future<EntryView> getById(UuidValue id) async => value;
  Future<EntryView> create(EntryInput input) async {
    writes++;
    return value = EntryView(
      entry: Entry(
        id: value.entry.id,
        title: input.title,
        status: input.status,
        email: input.email,
      ),
    );
  }

  Future<EntryView> update({
    required UuidValue id,
    required EntryInput input,
  }) => create(input);
  Future<void> archive(UuidValue id) async {
    writes++;
  }

  Future<List<EntryView>> getMany({required List<UuidValue> ids}) async => [
    value,
  ];
}
