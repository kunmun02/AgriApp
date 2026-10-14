/// Generic offset-paged result returned by all list repositories.
class Paginated<T> {
  const Paginated({
    required this.items,
    required this.total,
    required this.page,
    this.pageSize = 20,
  });

  final List<T> items;
  final int total;
  final int page;
  final int pageSize;

  bool get hasMore => (page * pageSize) < total;
}
