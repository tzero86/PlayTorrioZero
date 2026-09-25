import 'curated_collection.dart';
import 'curated_eras.dart';
import 'curated_sagas.dart';

/// Every curated pack the app ships, sagas first: the order here is the order
/// the Home rails and the Browse vertical present.
final List<CuratedCollection> curatedCollections = [
  ...curatedSagas,
  ...curatedEras,
];
