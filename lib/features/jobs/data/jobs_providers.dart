import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import 'jobs_api.dart';
import 'jobs_repository.dart';

final jobsApiProvider = Provider<JobsApi>(
  (ref) => JobsApi(ref.watch(apiClientProvider)),
);

final jobsRepositoryProvider = Provider<JobsRepository>(
  (ref) => JobsRepository(ref.watch(jobsApiProvider)),
);
