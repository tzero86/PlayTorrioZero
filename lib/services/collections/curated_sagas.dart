import 'curated_collection.dart';

/// Film sagas, hand-picked and verified against Cinemeta: every [CuratedItem]
/// title is the meta `name` Cinemeta returns for that imdb id, so a poster and
/// a tappable details card need no catalog lookup.
const List<CuratedCollection> curatedSagas = [
  CuratedCollection(
    id: 'saga_godfather',
    title: 'Godfather Collection',
    subtitle: '3 films, 1972 to 1990',
    kind: CuratedKind.saga,
    items: [
      CuratedItem(imdbId: 'tt0068646', title: 'The Godfather', year: 1972),
      CuratedItem(
        imdbId: 'tt0071562',
        title: 'The Godfather Part II',
        year: 1974,
      ),
      CuratedItem(
        imdbId: 'tt0099674',
        title: 'The Godfather Part III',
        year: 1990,
      ),
    ],
  ),
  CuratedCollection(
    id: 'saga_rocky',
    title: 'Rocky and Creed',
    subtitle: '9 films, 1976 to 2023',
    kind: CuratedKind.saga,
    items: [
      CuratedItem(imdbId: 'tt0075148', title: 'Rocky', year: 1976),
      CuratedItem(imdbId: 'tt0079817', title: 'Rocky II', year: 1979),
      CuratedItem(imdbId: 'tt0084602', title: 'Rocky III', year: 1982),
      CuratedItem(imdbId: 'tt0089927', title: 'Rocky IV', year: 1985),
      CuratedItem(imdbId: 'tt0100507', title: 'Rocky V', year: 1990),
      CuratedItem(imdbId: 'tt0479143', title: 'Rocky Balboa', year: 2006),
      CuratedItem(imdbId: 'tt3076658', title: 'Creed', year: 2015),
      CuratedItem(imdbId: 'tt6343314', title: 'Creed II', year: 2018),
      CuratedItem(imdbId: 'tt11145118', title: 'Creed III', year: 2023),
    ],
  ),
  CuratedCollection(
    id: 'saga_back_to_the_future',
    title: 'Back to the Future',
    subtitle: '3 films, 1985 to 1990',
    kind: CuratedKind.saga,
    items: [
      CuratedItem(imdbId: 'tt0088763', title: 'Back to the Future', year: 1985),
      CuratedItem(
        imdbId: 'tt0096874',
        title: 'Back to the Future Part II',
        year: 1989,
      ),
      CuratedItem(
        imdbId: 'tt0099088',
        title: 'Back to the Future Part III',
        year: 1990,
      ),
    ],
  ),
  CuratedCollection(
    id: 'saga_alien',
    title: 'Alien',
    subtitle: '7 films, 1979 to 2024',
    kind: CuratedKind.saga,
    items: [
      CuratedItem(imdbId: 'tt0078748', title: 'Alien', year: 1979),
      CuratedItem(imdbId: 'tt0090605', title: 'Aliens', year: 1986),
      CuratedItem(imdbId: 'tt0103644', title: 'Alien³', year: 1992),
      CuratedItem(
        imdbId: 'tt0118583',
        title: 'Alien: Resurrection',
        year: 1997,
      ),
      CuratedItem(imdbId: 'tt1446714', title: 'Prometheus', year: 2012),
      CuratedItem(imdbId: 'tt2316204', title: 'Alien: Covenant', year: 2017),
      CuratedItem(imdbId: 'tt18412256', title: 'Alien: Romulus', year: 2024),
    ],
  ),
  CuratedCollection(
    id: 'saga_die_hard',
    title: 'Die Hard',
    subtitle: '5 films, 1988 to 2013',
    kind: CuratedKind.saga,
    items: [
      CuratedItem(imdbId: 'tt0095016', title: 'Die Hard', year: 1988),
      CuratedItem(imdbId: 'tt0099423', title: 'Die Hard 2', year: 1990),
      CuratedItem(
        imdbId: 'tt0112864',
        title: 'Die Hard with a Vengeance',
        year: 1995,
      ),
      CuratedItem(
        imdbId: 'tt0337978',
        title: 'Live Free or Die Hard',
        year: 2007,
      ),
      CuratedItem(
        imdbId: 'tt1606378',
        title: 'A Good Day to Die Hard',
        year: 2013,
      ),
    ],
  ),
  CuratedCollection(
    id: 'saga_lethal_weapon',
    title: 'Lethal Weapon',
    subtitle: '4 films, 1987 to 1998',
    kind: CuratedKind.saga,
    items: [
      CuratedItem(imdbId: 'tt0093409', title: 'Lethal Weapon', year: 1987),
      CuratedItem(imdbId: 'tt0097733', title: 'Lethal Weapon 2', year: 1989),
      CuratedItem(imdbId: 'tt0104714', title: 'Lethal Weapon 3', year: 1992),
      CuratedItem(imdbId: 'tt0122151', title: 'Lethal Weapon 4', year: 1998),
    ],
  ),
  CuratedCollection(
    id: 'saga_terminator',
    title: 'The Terminator',
    subtitle: '6 films, 1984 to 2019',
    kind: CuratedKind.saga,
    items: [
      CuratedItem(imdbId: 'tt0088247', title: 'The Terminator', year: 1984),
      CuratedItem(
        imdbId: 'tt0103064',
        title: 'Terminator 2: Judgment Day',
        year: 1991,
      ),
      CuratedItem(
        imdbId: 'tt0181852',
        title: 'Terminator 3: Rise of the Machines',
        year: 2003,
      ),
      CuratedItem(
        imdbId: 'tt0438488',
        title: 'Terminator Salvation',
        year: 2009,
      ),
      CuratedItem(imdbId: 'tt1340138', title: 'Terminator Genisys', year: 2015),
      CuratedItem(
        imdbId: 'tt6450804',
        title: 'Terminator: Dark Fate',
        year: 2019,
      ),
    ],
  ),
  CuratedCollection(
    id: 'saga_predator',
    title: 'Predator',
    subtitle: '5 films, 1987 to 2022',
    kind: CuratedKind.saga,
    items: [
      CuratedItem(imdbId: 'tt0093773', title: 'Predator', year: 1987),
      CuratedItem(imdbId: 'tt0100403', title: 'Predator 2', year: 1990),
      CuratedItem(imdbId: 'tt1424381', title: 'Predators', year: 2010),
      CuratedItem(imdbId: 'tt3829266', title: 'The Predator', year: 2018),
      CuratedItem(imdbId: 'tt11866324', title: 'Prey', year: 2022),
    ],
  ),
  CuratedCollection(
    id: 'saga_jurassic_park',
    title: 'Jurassic Park',
    subtitle: '6 films, 1993 to 2022',
    kind: CuratedKind.saga,
    items: [
      CuratedItem(imdbId: 'tt0107290', title: 'Jurassic Park', year: 1993),
      CuratedItem(
        imdbId: 'tt0119567',
        title: 'The Lost World: Jurassic Park',
        year: 1997,
      ),
      CuratedItem(imdbId: 'tt0163025', title: 'Jurassic Park III', year: 2001),
      CuratedItem(imdbId: 'tt0369610', title: 'Jurassic World', year: 2015),
      CuratedItem(
        imdbId: 'tt4881806',
        title: 'Jurassic World: Fallen Kingdom',
        year: 2018,
      ),
      CuratedItem(
        imdbId: 'tt8041270',
        title: 'Jurassic World: Dominion',
        year: 2022,
      ),
    ],
  ),
  CuratedCollection(
    id: 'saga_rambo',
    title: 'Rambo',
    subtitle: '5 films, 1982 to 2019',
    kind: CuratedKind.saga,
    items: [
      CuratedItem(imdbId: 'tt0083944', title: 'First Blood', year: 1982),
      CuratedItem(
        imdbId: 'tt0089880',
        title: 'Rambo: First Blood Part II',
        year: 1985,
      ),
      CuratedItem(imdbId: 'tt0095956', title: 'Rambo III', year: 1988),
      CuratedItem(imdbId: 'tt0462499', title: 'Rambo', year: 2008),
      CuratedItem(imdbId: 'tt1206885', title: 'Rambo: Last Blood', year: 2019),
    ],
  ),
  CuratedCollection(
    id: 'saga_indiana_jones',
    title: 'Indiana Jones',
    subtitle: '5 films, 1981 to 2023',
    kind: CuratedKind.saga,
    items: [
      CuratedItem(
        imdbId: 'tt0082971',
        title: 'Raiders of the Lost Ark',
        year: 1981,
      ),
      CuratedItem(
        imdbId: 'tt0087469',
        title: 'Indiana Jones and the Temple of Doom',
        year: 1984,
      ),
      CuratedItem(
        imdbId: 'tt0097576',
        title: 'Indiana Jones and the Last Crusade',
        year: 1989,
      ),
      CuratedItem(
        imdbId: 'tt0367882',
        title: 'Indiana Jones and the Kingdom of the Crystal Skull',
        year: 2008,
      ),
      CuratedItem(
        imdbId: 'tt1462764',
        title: 'Indiana Jones and the Dial of Destiny',
        year: 2023,
      ),
    ],
  ),
  CuratedCollection(
    id: 'saga_marx_brothers',
    title: 'The Marx Brothers',
    subtitle: 'Groucho and his brothers, 13 films, 1929 to 1949',
    kind: CuratedKind.saga,
    items: [
      CuratedItem(imdbId: 'tt0019777', title: 'The Cocoanuts', year: 1929),
      CuratedItem(imdbId: 'tt0020640', title: 'Animal Crackers', year: 1930),
      CuratedItem(imdbId: 'tt0022158', title: 'Monkey Business', year: 1931),
      CuratedItem(imdbId: 'tt0023027', title: 'Horse Feathers', year: 1932),
      CuratedItem(imdbId: 'tt0023969', title: 'Duck Soup', year: 1933),
      CuratedItem(imdbId: 'tt0026778', title: 'A Night at the Opera', year: 1935),
      CuratedItem(imdbId: 'tt0028772', title: 'A Day at the Races', year: 1937),
      CuratedItem(imdbId: 'tt0030696', title: 'Room Service', year: 1938),
      CuratedItem(imdbId: 'tt0031060', title: 'At the Circus', year: 1939),
      CuratedItem(imdbId: 'tt0032536', title: 'Go West', year: 1940),
      CuratedItem(imdbId: 'tt0033388', title: 'The Big Store', year: 1941),
      CuratedItem(imdbId: 'tt0038777', title: 'A Night in Casablanca', year: 1946),
      CuratedItem(imdbId: 'tt0041604', title: 'Love Happy', year: 1949),
    ],
  ),
];
