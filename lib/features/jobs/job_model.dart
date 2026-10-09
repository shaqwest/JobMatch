class Job {
  final String id;
  final String title;
  final String company;
  final String? website;
  final String location;
  final String type;
  final String employment;
  final String? contractDuration;
  final int? salaryMin;
  final int? salaryMax;
  final DateTime postedAt;
  final String source;
  final String description;
  final String? responsibilities;
  final String? benefits;
  final String? workload;
  final String applyUrl;
  final double? rating;
  final double matchScore;

  const Job({
    required this.id,
    required this.title,
    required this.company,
    this.website,
    required this.location,
    required this.type,
    required this.employment,
    this.contractDuration,
    this.salaryMin,
    this.salaryMax,
    required this.postedAt,
    required this.source,
    required this.description,
    this.responsibilities,
    this.benefits,
    this.workload,
    required this.applyUrl,
    this.rating,
    this.matchScore = 0,
  });

  DateTime get postedAtJakarta => postedAt.add(const Duration(hours: 7));

  String get salaryLabel {
    if (salaryMin == null && salaryMax == null) return 'Not disclosed';
    if (salaryMin != null && salaryMax != null) return 'Rp ${salaryMin} - ${salaryMax}';
    if (salaryMin != null) return 'From Rp $salaryMin';
    return 'Up to Rp $salaryMax';
  }

  factory Job.fromJson(Map<String, dynamic> j) => Job(
        id: j['id']?.toString() ?? '',
        title: j['title'] ?? '',
        company: j['company'] ?? j['company_name'] ?? '',
        website: j['website'] ?? j['company_website'],
        location: j['location'] ?? '',
        type: j['type'] ?? j['work_type'] ?? 'WFO',
        employment: j['employment'] ?? j['contract_type'] ?? 'full_time',
        contractDuration: j['contract_duration']?.toString(),
        salaryMin: j['salary_min'] is int ? j['salary_min'] : int.tryParse('${j['salary_min'] ?? ''}'),
        salaryMax: j['salary_max'] is int ? j['salary_max'] : int.tryParse('${j['salary_max'] ?? ''}'),
        postedAt: DateTime.tryParse(j['posted_at'] ?? j['created_at'] ?? '') ?? DateTime.now().toUtc(),
        source: j['source'] ?? 'api',
        description: j['description'] ?? '',
        responsibilities: j['responsibilities']?.toString(),
        benefits: j['benefits']?.toString(),
        workload: j['workload']?.toString(),
        applyUrl: j['apply_url'] ?? j['url'] ?? '',
        rating: (j['company_rating'] ?? j['rating']) is num ? (j['company_rating'] ?? j['rating']).toDouble() : null,
        matchScore: (j['match_score'] is num) ? (j['match_score'] as num).toDouble() : 0,
      );

  Job copyWithMatch(double score) => Job(
        id: id,
        title: title,
        company: company,
        website: website,
        location: location,
        type: type,
        employment: employment,
        contractDuration: contractDuration,
        salaryMin: salaryMin,
        salaryMax: salaryMax,
        postedAt: postedAt,
        source: source,
        description: description,
        responsibilities: responsibilities,
        benefits: benefits,
        workload: workload,
        applyUrl: applyUrl,
        rating: rating,
        matchScore: score,
      );

  Map<String, dynamic> toCardMap() => {'id': id, 'title': title, 'company': company};
}

List<Job> mockJobs() {
  final now = DateTime.now().toUtc();
  return [
    Job(id: '1', title: 'Flutter Developer', company: 'GoTo Group', location: 'Jakarta, Indonesia', type: 'Hybrid', employment: 'full_time', salaryMin: 12000000, salaryMax: 20000000, postedAt: now.subtract(const Duration(hours: 5)), source: 'mock', description: 'Build Flutter apps for high-scale consumer products. Collaborate with backend and design.', responsibilities: 'Develop, test, and ship Flutter features. Write clean Dart. Review PRs.', benefits: 'Health insurance, annual bonus, hybrid work', workload: '40h/week', applyUrl: 'https://example.com/apply/1', website: 'https://goto.com', rating: 4.2, matchScore: 86),
    Job(id: '2', title: 'Backend Engineer (Go)', company: 'Bukalapak', location: 'Remote - Indonesia', type: 'Remote', employment: 'full_time', salaryMin: 15000000, salaryMax: 25000000, postedAt: now.subtract(const Duration(days: 1, hours: 2)), source: 'mock', description: 'Design and maintain Go microservices on GCP. Postgres, Redis, Kafka.', responsibilities: 'API design, performance tuning, observability.', benefits: 'Remote, stock options', workload: '40h/week', applyUrl: 'https://example.com/apply/2', website: 'https://bukalapak.com', matchScore: 72),
    Job(id: '3', title: 'Data Analyst (Contract)', company: 'Telkom Indonesia', location: 'Bandung, Indonesia', type: 'WFO', employment: 'contract', contractDuration: '6 months', salaryMin: 8000000, salaryMax: 12000000, postedAt: now.subtract(const Duration(days: 3)), source: 'mock', description: 'Analyze telco data, build dashboards, SQL + Python.', responsibilities: 'ETL, dashboards, stakeholder reporting.', benefits: 'Contract benefits', workload: '40h/week', applyUrl: 'https://example.com/apply/3', matchScore: 64),
    Job(id: '4', title: 'UI/UX Designer', company: 'Traveloka', location: 'Jakarta, Indonesia', type: 'Hybrid', employment: 'full_time', salaryMin: null, salaryMax: null, postedAt: now.subtract(const Duration(hours: 12)), source: 'mock', description: 'Design travel booking flows. Figma, research, prototyping.', responsibilities: 'User research, wireframes, design system.', benefits: 'Hybrid, wellness allowance', workload: '40h/week', applyUrl: 'https://example.com/apply/4', matchScore: 78),
    Job(id: '5', title: 'Mobile QA (Part-time)', company: 'Ruangguru', location: 'Jakarta, Indonesia', type: 'WFO', employment: 'part_time', salaryMin: 5000000, salaryMax: 7000000, postedAt: now.subtract(const Duration(days: 5)), source: 'mock', description: 'Test Android/iOS apps. Manual + automation.', responsibilities: 'Test plans, bug reports, regression.', benefits: 'Flexible hours', workload: '20h/week', applyUrl: 'https://example.com/apply/5', matchScore: 55),
  ];
}
