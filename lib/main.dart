import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

void main() {
  runApp(const SportsHubApp());
}

const String apiKey = 'a659233966294c0a9cfda289bc9e4a3c';

// -- App-wide enums and config --

enum SportsCategory { nfl, soccer }
const Map<SportsCategory, String> categoryNames = {
  SportsCategory.nfl: "NFL",
  SportsCategory.soccer: "Soccer (EPL)"
};
const Map<SportsCategory, String> leagueCodes = {
  SportsCategory.nfl: "",
  SportsCategory.soccer: "EPL",
};
const Map<SportsCategory, List<int>> seasonYears = {
  SportsCategory.nfl: [2024, 2023, 2022],
  SportsCategory.soccer: [2024, 2023, 2022],
};

class SportsHubApp extends StatelessWidget {
  const SportsHubApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sports Hub',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.grey[50],
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
          elevation: 1,
          centerTitle: true,
        ),
        cardTheme: const CardThemeData(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(14))),
          elevation: 3,
          margin: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          color: Colors.white,
        ),
        tabBarTheme: const TabBarThemeData(
          labelColor: Colors.indigo,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.indigo,
        ),
      ),
      home: const HomeTabScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomeTabScreen extends StatefulWidget {
  const HomeTabScreen({Key? key}) : super(key: key);

  @override
  State<HomeTabScreen> createState() => _HomeTabScreenState();
}

class _HomeTabScreenState extends State<HomeTabScreen> {
  SportsCategory _selectedCategory = SportsCategory.nfl;
  late int _selectedSeason;

  @override
  void initState() {
    super.initState();
    _selectedSeason = seasonYears[_selectedCategory]!.first;
  }

  @override
  Widget build(BuildContext context) {
    final seasons = seasonYears[_selectedCategory]!;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Sports Hub'),
          actions: [
            // Category Picker
            DropdownButtonHideUnderline(
              child: DropdownButton<SportsCategory>(
                dropdownColor: Colors.white,
                value: _selectedCategory,
                items: categoryNames.entries.map((entry) {
                  return DropdownMenuItem<SportsCategory>(
                    value: entry.key,
                    child: Text(entry.value),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null && val != _selectedCategory) {
                    setState(() {
                      _selectedCategory = val;
                      _selectedSeason = seasonYears[val]!.first;
                    });
                  }
                },
                style: const TextStyle(
                    color: Colors.indigo, fontWeight: FontWeight.w600),
                icon: const Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: Icon(Icons.sports, color: Colors.white),
                ),
              ),
            ),
            // Season Picker
            DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                dropdownColor: Colors.white,
                value: _selectedSeason,
                items: seasons.map((season) {
                  return DropdownMenuItem<int>(
                    value: season,
                    child: Text(season.toString()),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null && val != _selectedSeason) {
                    setState(() => _selectedSeason = val);
                  }
                },
                style: const TextStyle(
                    color: Colors.indigo, fontWeight: FontWeight.w600),
                icon: const Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: Icon(Icons.calendar_today, color: Colors.white, size: 20),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Matches', icon: Icon(Icons.sports_soccer)),
              Tab(text: 'Standings', icon: Icon(Icons.leaderboard)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            MatchesScreen(
              category: _selectedCategory,
              season: _selectedSeason,
            ),
            StandingsScreen(
              category: _selectedCategory,
              season: _selectedSeason,
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------ MATCHES SCREEN ------------------

class SportsMatch {
  // Covers both NFL and Soccer (EPL)
  final String homeTeam;
  final String awayTeam;
  final DateTime dateTime;
  final int? homeScore;
  final int? awayScore;
  final String status; // "Scheduled", "InProgress", "Final", etc.
  final String stadium;
  final String description; // e.g., week/round

  SportsMatch({
    required this.homeTeam,
    required this.awayTeam,
    required this.dateTime,
    this.homeScore,
    this.awayScore,
    required this.status,
    required this.stadium,
    required this.description,
  });

  factory SportsMatch.fromJsonNFL(Map<String, dynamic> json) {
    return SportsMatch(
      homeTeam: json['HomeTeam'] ?? '',
      awayTeam: json['AwayTeam'] ?? '',
      dateTime: DateTime.tryParse(json['Date']) ?? DateTime.now(),
      homeScore: json['HomeScore'] is int ? json['HomeScore'] : null,
      awayScore: json['AwayScore'] is int ? json['AwayScore'] : null,
      status: json['Status'] ?? '',
      stadium: json['StadiumDetails']?['Name'] ?? '',
      description: json['Week'] != null ? 'Week ${json['Week']}' : '',
    );
  }

  factory SportsMatch.fromJsonSoccer(Map<String, dynamic> json) {
    return SportsMatch(
      homeTeam: json['HomeTeamName'] ?? '',
      awayTeam: json['AwayTeamName'] ?? '',
      dateTime: DateTime.tryParse(json['DateTime']) ?? DateTime.now(),
      homeScore: json['HomeTeamScore'] is int ? json['HomeTeamScore'] : null,
      awayScore: json['AwayTeamScore'] is int ? json['AwayTeamScore'] : null,
      status: json['Status'] ?? '',
      stadium: json['Stadium'] ?? '',
      description: json['Round'] != null ? 'Round ${json['Round']}' : '',
    );
  }
}

Future<List<SportsMatch>> fetchMatches({
  required SportsCategory category,
  required int season,
}) async {
  if (category == SportsCategory.nfl) {
    // NFL - Games/{season}
    final url =
        'https://api.sportsdata.io/v3/nfl/scores/json/Games/$season?key=$apiKey';
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final List data = json.decode(response.body);
      return data.map((json) => SportsMatch.fromJsonNFL(json)).toList();
    } else {
      throw Exception('Failed to load NFL matches');
    }
  } else if (category == SportsCategory.soccer) {
    // Soccer (EPL) - GamesBySeason/{season}
    final url =
        'https://api.sportsdata.io/v3/soccer/scores/json/GamesBySeason/EPL/$season?key=$apiKey';
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final List data = json.decode(response.body);
      return data.map((json) => SportsMatch.fromJsonSoccer(json)).toList();
    } else {
      throw Exception('Failed to load Soccer matches');
    }
  }
  return [];
}

class MatchesScreen extends StatefulWidget {
  final SportsCategory category;
  final int season;
  const MatchesScreen({Key? key, required this.category, required this.season})
      : super(key: key);

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen> {
  late Future<List<SportsMatch>> _futureMatches;

  @override
  void didUpdateWidget(MatchesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.category != widget.category || oldWidget.season != widget.season) {
      _futureMatches = fetchMatches(category: widget.category, season: widget.season);
    }
  }

  @override
  void initState() {
    super.initState();
    _futureMatches = fetchMatches(category: widget.category, season: widget.season);
  }

  Future<void> _refresh() async {
    setState(() {
      _futureMatches =
          fetchMatches(category: widget.category, season: widget.season);
    });
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'inprogress':
      case 'in progress':
        return Colors.orange;
      case 'final':
      case 'completed':
        return Colors.green;
      case 'scheduled':
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<SportsMatch>>(
        future: _futureMatches,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return _ErrorState(
                message: "Failed to load matches.\n${snapshot.error}");
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const _ErrorState(
                message: "No matches found for this category/season.");
          }

          final matches = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.only(top: 12, bottom: 24),
            itemCount: matches.length,
            itemBuilder: (context, idx) {
              final m = matches[idx];
              return Card(
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 18),
                  leading: CircleAvatar(
                    backgroundColor: _statusColor(m.status),
                    child: Text(
                      m.status.isNotEmpty ? m.status[0] : "",
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(
                    '${m.awayTeam} @ ${m.homeTeam}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (m.status.toLowerCase() == 'final' ||
                                m.status.toLowerCase() == 'completed' ||
                                m.status.toLowerCase() == 'inprogress' ||
                                m.status.toLowerCase() == 'in progress')
                            ? '${m.awayScore ?? "-"} - ${m.homeScore ?? "-"}'
                            : 'Kickoff: ${DateFormat('MMM dd, h:mm a').format(m.dateTime)}',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: m.status.toLowerCase() == 'final' ||
                                  m.status.toLowerCase() == 'completed'
                              ? Colors.green
                              : (m.status.toLowerCase() == 'inprogress' ||
                                      m.status.toLowerCase() == 'in progress'
                                  ? Colors.orange
                                  : Colors.blueGrey),
                        ),
                      ),
                      if (m.stadium.isNotEmpty)
                        Text(
                          m.stadium,
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      if (m.description.isNotEmpty)
                        Text(
                          m.description,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.indigoAccent),
                        ),
                    ],
                  ),
                  trailing: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusColor(m.status).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      m.status,
                      style: TextStyle(
                        color: _statusColor(m.status),
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ------------------ STANDINGS SCREEN ------------------

class TeamStanding {
  final String team;
  final int wins;
  final int losses;
  final int ties; // draws for soccer
  final int pointsFor;
  final int pointsAgainst;
  final String conference;
  final String division;
  final int? points; // for soccer

  TeamStanding({
    required this.team,
    required this.wins,
    required this.losses,
    required this.ties,
    required this.pointsFor,
    required this.pointsAgainst,
    required this.conference,
    required this.division,
    this.points,
  });

  factory TeamStanding.fromJsonNFL(Map<String, dynamic> json) {
    return TeamStanding(
      team: json['Name'] ?? '',
      wins: json['Wins'] ?? 0,
      losses: json['Losses'] ?? 0,
      ties: json['Ties'] ?? 0,
      pointsFor: json['PointsFor']?.toInt() ?? 0,
      pointsAgainst: json['PointsAgainst']?.toInt() ?? 0,
      conference: json['Conference'] ?? '',
      division: json['Division'] ?? '',
      points: null,
    );
  }

  factory TeamStanding.fromJsonSoccer(Map<String, dynamic> json) {
    return TeamStanding(
      team: json['Name'] ?? '',
      wins: json['Wins'] ?? 0,
      losses: json['Losses'] ?? 0,
      ties: json['Draws'] ?? 0,
      pointsFor: json['GoalsFor']?.toInt() ?? 0,
      pointsAgainst: json['GoalsAgainst']?.toInt() ?? 0,
      conference: '', // Soccer doesn't have this
      division: '', // Soccer doesn't have this
      points: json['Points'] ?? 0,
    );
  }
}

Future<List<TeamStanding>> fetchStandings(
    {required SportsCategory category, required int season}) async {
  if (category == SportsCategory.nfl) {
    final url =
        'https://api.sportsdata.io/v3/nfl/scores/json/Standings/$season?key=$apiKey';
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final List data = json.decode(response.body);
      return data.map((json) => TeamStanding.fromJsonNFL(json)).toList();
    } else {
      throw Exception('Failed to load NFL standings');
    }
  } else if (category == SportsCategory.soccer) {
    final url =
        'https://api.sportsdata.io/v3/soccer/scores/json/Standings/EPL/$season?key=$apiKey';
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final List data = json.decode(response.body);
      return data.map((json) => TeamStanding.fromJsonSoccer(json)).toList();
    } else {
      throw Exception('Failed to load Soccer standings');
    }
  }
  return [];
}

class StandingsScreen extends StatefulWidget {
  final SportsCategory category;
  final int season;
  const StandingsScreen({Key? key, required this.category, required this.season})
      : super(key: key);

  @override
  State<StandingsScreen> createState() => _StandingsScreenState();
}

class _StandingsScreenState extends State<StandingsScreen> {
  late Future<List<TeamStanding>> _futureStandings;

  @override
  void didUpdateWidget(StandingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.category != widget.category || oldWidget.season != widget.season) {
      _futureStandings =
          fetchStandings(category: widget.category, season: widget.season);
    }
  }

  @override
  void initState() {
    super.initState();
    _futureStandings =
        fetchStandings(category: widget.category, season: widget.season);
  }

  Future<void> _refresh() async {
    setState(() {
      _futureStandings =
          fetchStandings(category: widget.category, season: widget.season);
    });
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<TeamStanding>>(
        future: _futureStandings,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return _ErrorState(
                message: "Failed to load standings.\n${snapshot.error}");
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const _ErrorState(
                message: "No standings found for this category/season.");
          }
          final teams = snapshot.data!;
          if (widget.category == SportsCategory.nfl) {
            // NFL - Conference and Division headers
            teams.sort((a, b) {
              int cmp = a.conference.compareTo(b.conference);
              if (cmp != 0) return cmp;
              cmp = a.division.compareTo(b.division);
              if (cmp != 0) return cmp;
              return b.wins.compareTo(a.wins);
            });

            String? lastHeader;
            return ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 10),
              itemCount: teams.length,
              itemBuilder: (context, idx) {
                final t = teams[idx];
                final header = '${t.conference} ${t.division}';
                final showHeader = header != lastHeader;
                lastHeader = header;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (showHeader && header.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 22, 16, 6),
                        child: Text(
                          header,
                          style: const TextStyle(
                            color: Colors.indigo,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 10),
                        title: Text(t.team,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Row(
                          children: [
                            Text('W: ${t.wins}',
                                style: const TextStyle(color: Colors.green)),
                            const SizedBox(width: 12),
                            Text('L: ${t.losses}',
                                style: const TextStyle(color: Colors.red)),
                            const SizedBox(width: 12),
                            Text('T: ${t.ties}',
                                style: const TextStyle(color: Colors.orange)),
                          ],
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('PF: ${t.pointsFor}',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.black54)),
                            Text('PA: ${t.pointsAgainst}',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.black54)),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          } else {
            // Soccer - Simple table
            teams.sort((a, b) => b.points!.compareTo(a.points!));
            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
              itemCount: teams.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, idx) {
                final t = teams[idx];
                return Card(
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    leading: CircleAvatar(
                      backgroundColor: Colors.indigo,
                      child: Text(
                        '${idx + 1}',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ),
                    title: Text(t.team,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Row(
                      children: [
                        Text('W: ${t.wins}',
                            style: const TextStyle(color: Colors.green)),
                        const SizedBox(width: 10),
                        Text('D: ${t.ties}',
                            style: const TextStyle(color: Colors.orange)),
                        const SizedBox(width: 10),
                        Text('L: ${t.losses}',
                            style: const TextStyle(color: Colors.red)),
                        const SizedBox(width: 10),
                        Text('Pts: ${t.points}',
                            style: const TextStyle(
                                color: Colors.black87, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('GF: ${t.pointsFor}',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.black54)),
                        Text('GA: ${t.pointsAgainst}',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.black54)),
                      ],
                    ),
                  ),
                );
              },
            );
          }
        },
      ),
    );
  }
}

// -------------- ErrorState Widget --------------
class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({Key? key, required this.message}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 16, color: Colors.black54, height: 1.4),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              onPressed: () => Navigator.pushReplacement(
                context,
                PageRouteBuilder(
                  pageBuilder: (_, __, ___) => const HomeTabScreen(),
                  transitionDuration: Duration.zero,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}