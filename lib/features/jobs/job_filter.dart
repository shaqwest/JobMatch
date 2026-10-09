enum SortField { match, salary, postedAt }
enum SortOrder { asc, desc }

class JobFilters {
  final int? salaryMin;
  final int? salaryMax;
  final Set<String> types;
  final SortField sortField;
  final SortOrder sortOrder;

  const JobFilters({
    this.salaryMin,
    this.salaryMax,
    this.types = const {},
    this.sortField = SortField.postedAt,
    this.sortOrder = SortOrder.desc,
  });

  JobFilters copyWith({
    int? salaryMin,
    int? salaryMax,
    Set<String>? types,
    SortField? sortField,
    SortOrder? sortOrder,
    bool clearSalary = false,
  }) =>
      JobFilters(
        salaryMin: clearSalary ? null : (salaryMin ?? this.salaryMin),
        salaryMax: clearSalary ? null : (salaryMax ?? this.salaryMax),
        types: types ?? this.types,
        sortField: sortField ?? this.sortField,
        sortOrder: sortOrder ?? this.sortOrder,
      );
}
