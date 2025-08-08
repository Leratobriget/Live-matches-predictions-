
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:math';

void main() {
  runApp(const MatchPredictionApp());
}

class MatchPredictionApp extends StatelessWidget {
  const MatchPredictionApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => PredictionProvider(),
      child: MaterialApp(
        title: 'Match Predictions',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          scaffoldBackgroundColor: Colors.grey[50],
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.indigo,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
        ),
        home: const PredictionsScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class MatchPrediction {
  final String id;
  final String homeTeam;
  final String awayTeam;
  final DateTime matchTime;
  final String league;
  final double homeWinProbability;
  final double drawProbability;
  final double awayWinProbability;
  final String predictedOutcome;
  final double confidence;
  final String status;
  final int? homeScore;
  final int? awayScore;

  MatchPrediction({
    required this.id,
    required this.homeTeam,
    required this.awayTeam,
    required this.matchTime,
    required this.league,
    required this.homeWinProbability,
    required this.drawProbability,
    required this.awayWinProbability,
    required this.predictedOutcome,
    required this.confidence,
    required this.status,
    this.homeScore,
    this.awayScore,
  });

  Color get confidenceColor {
    if (confidence >= 0.8) return Colors.green;
    if (confidence >= 0.6) return Colors.orange;
    return Colors.red;
  }

  String get confidenceText {
    if (confidence >= 0.8) return 'High';
    if (confidence >= 0.6) return 'Medium';
    return 'Low';
  }
}

class PredictionProvider extends ChangeNotifier {
  List<MatchPrediction> _predictions = [];
  bool _isLoading = false;

  List<MatchPrediction> get predictions => _predictions;
  bool get isLoading => _isLoading;

  Future<void> loadPredictions() async {
    _isLoading = true;
    notifyListeners();

    await Future.delayed(const Duration(seconds: 1));

    final random = Random();
    final teams = [
      'Manchester United', 'Liverpool', 'Arsenal', 'Chelsea', 'Manchester City',
      'Barcelona', 'Real Madrid', 'Bayern Munich', 'AC Milan', 'PSG'
    ];
    
    final leagues = ['Premier League', 'La Liga', 'Bundesliga', 'Serie A'];
    final statuses = ['LIVE', 'UPCOMING', 'FINISHED'];
    
    _predictions = List.generate(10, (index) {
      final homeTeam = teams[random.nextInt(teams.length)];
      var awayTeam = teams[random.nextInt(teams.length)];
      while (awayTeam == homeTeam) {
        awayTeam = teams[random.nextInt(teams.length)];
      }
      
      final homeWin = 0.1 + random.nextDouble() * 0.7;
      final draw = (1.0 - homeWin) * (0.2 + random.nextDouble() * 0.4);
      final awayWin = 1.0 - homeWin - draw;
      
      final predictedOutcome = homeWin > draw && homeWin > awayWin 
          ? 'Home Win' 
          : awayWin > draw 
              ? 'Away Win' 
              : 'Draw';
      
      final confidence = 0.5 + random.nextDouble() * 0.4;
      final status = statuses[random.nextInt(statuses.length)];
      
      DateTime matchTime;
      if (status == 'LIVE') {
        matchTime = DateTime.now().subtract(Duration(minutes: random.nextInt(90)));
      } else if (status == 'UPCOMING') {
        matchTime = DateTime.now().add(Duration(hours: random.nextInt(48) + 1));
      } else {
        matchTime = DateTime.now().subtract(Duration(hours: random.nextInt(72) + 1));
      }
      
      return MatchPrediction(
        id: 'match_$index',
        homeTeam: homeTeam,
        awayTeam: awayTeam,
        matchTime: matchTime,
        league: leagues[random.nextInt(leagues.length)],
        homeWinProbability: homeWin,
        drawProbability: draw,
        awayWinProbability: awayWin,
        predictedOutcome: predictedOutcome,
        confidence: confidence,
        status: status,
        homeScore: status == 'FINISHED' || status == 'LIVE' ? random.nextInt(4) : null,
        awayScore: status == 'FINISHED' || status == 'LIVE' ? random.nextInt(4) : null,
      );
    });

    _isLoading = false;
    notifyListeners();
  }
}

class PredictionsScreen extends StatefulWidget {
  const PredictionsScreen({Key? key}) : super(key: key);

  @override
  State<PredictionsScreen> createState() => _PredictionsScreenState();
}

class _PredictionsScreenState extends State<PredictionsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<PredictionProvider>(context, listen: false).loadPredictions();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Match Predictions'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              Provider.of<PredictionProvider>(context, listen: false).loadPredictions();
            },
          ),
        ],
      ),
      body: Consumer<PredictionProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.predictions.isEmpty) {
            return const Center(
              child: Text(
                'No predictions available',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.predictions.length,
            itemBuilder: (context, index) {
              final prediction = provider.predictions[index];
              return PredictionCard(prediction: prediction);
            },
          );
        },
      ),
    );
  }
}

class PredictionCard extends StatelessWidget {
  final MatchPrediction prediction;

  const PredictionCard({Key? key, required this.prediction}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with league and status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.indigo.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    prediction.league,
                    style: const TextStyle(
                      color: Colors.indigo,
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusColor(),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        prediction.status,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('MMM dd, HH:mm').format(prediction.matchTime),
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Teams and score
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        prediction.homeTeam,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text('Home', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    ],
                  ),
                ),
                
                if (prediction.homeScore != null && prediction.awayScore != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${prediction.homeScore} - ${prediction.awayScore}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ] else ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('vs', style: TextStyle(fontSize: 16, color: Colors.grey)),
                  ),
                ],
                
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        prediction.awayTeam,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                      ),
                      Text('Away', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Prediction bars
            Column(
              children: [
                const Text(
                  'Win Probability',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      flex: (prediction.homeWinProbability * 100).round(),
                      child: Container(
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(4),
                            bottomLeft: Radius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: (prediction.drawProbability * 100).round(),
                      child: Container(height: 8, color: Colors.orange),
                    ),
                    Expanded(
                      flex: (prediction.awayWinProbability * 100).round(),
                      child: Container(
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.only(
                            topRight: Radius.circular(4),
                            bottomRight: Radius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${(prediction.homeWinProbability * 100).toStringAsFixed(1)}%',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.blue)),
                    Text('${(prediction.drawProbability * 100).toStringAsFixed(1)}%',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.orange)),
                    Text('${(prediction.awayWinProbability * 100).toStringAsFixed(1)}%',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.green)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Prediction summary
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Predicted Outcome', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 2),
                      Text(prediction.predictedOutcome, 
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Confidence', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: prediction.confidenceColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${prediction.confidenceText} (${(prediction.confidence * 100).toStringAsFixed(0)}%)',
                          style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor() {
    switch (prediction.status) {
      case 'LIVE': return Colors.red;
      case 'UPCOMING': return Colors.blue;
      case 'FINISHED': return Colors.grey;
      default: return Colors.grey;
    }
  }
}