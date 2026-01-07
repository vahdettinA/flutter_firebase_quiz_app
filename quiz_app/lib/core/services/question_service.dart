import 'package:cloud_firestore/cloud_firestore.dart';

class Question {
  final String id;
  final String question;
  final Map<String, String> options;
  final String correctOption;
  final String category;
  final String difficulty;
  final int duration;

  Question({
    required this.id,
    required this.question,
    required this.options,
    required this.correctOption,
    required this.category,
    required this.difficulty,
    required this.duration,
  });

  Map<String, dynamic> toMap() {
    return {
      'question': question,
      'options': options,
      'correctOption': correctOption,
      'category': category,
      'difficulty': difficulty,
      'duration': duration,
    };
  }

  factory Question.fromMap(String id, Map<String, dynamic> map) {
    return Question(
      id: id,
      question: map['question'] ?? '',
      options: Map<String, String>.from(map['options'] ?? {}),
      correctOption: map['correctOption'] ?? 'a',
      category: map['category'] ?? 'Genel',
      difficulty: map['difficulty'] ?? 'basit',
      duration: map['duration'] ?? 15,
    );
  }
}

class QuestionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> seedQuestionsIfEmpty() async {
    final snapshot = await _firestore.collection('questions').limit(1).get();
    if (snapshot.docs.isEmpty) {
      final sampleQuestions = [
        Question(
          id: '',
          question: 'İstanbul\'u kim fethetmiştir?',
          options: {
            'a': 'Fatih Sultan Mehmet',
            'b': 'Osman Bey',
            'c': 'Yıldırım Beyazıt',
            'd': 'Orhan Bey',
          },
          correctOption: 'a',
          category: 'Tarih',
          difficulty: 'basit',
          duration: 10,
        ),
        Question(
          id: '',
          question: 'Türkiye\'nin başkenti neresidir?',
          options: {'a': 'İstanbul', 'b': 'İzmir', 'c': 'Ankara', 'd': 'Bursa'},
          correctOption: 'c',
          category: 'Coğrafya',
          difficulty: 'basit',
          duration: 10,
        ),
        Question(
          id: '',
          question: 'Su kaç derecede kaynar?',
          options: {'a': '90', 'b': '80', 'c': '100', 'd': '120'},
          correctOption: 'c',
          category: 'Bilim',
          difficulty: 'basit',
          duration: 15,
        ),
        Question(
          id: '',
          question: 'Futbol maçı kaç kişiyle oynanır?',
          options: {'a': '10', 'b': '11', 'c': '12', 'd': '9'},
          correctOption: 'b',
          category: 'Spor',
          difficulty: 'basit',
          duration: 10,
        ),
        Question(
          id: '',
          question: 'En büyük gezegen hangisidir?',
          options: {'a': 'Mars', 'b': 'Dünya', 'c': 'Jüpiter', 'd': 'Satürn'},
          correctOption: 'c',
          category: 'Uzay',
          difficulty: 'orta',
          duration: 15,
        ),
        Question(
          id: '',
          question: 'Hangi elementin sembolü O\'dur?',
          options: {'a': 'Oksijen', 'b': 'Osmiyum', 'c': 'Opak', 'd': 'Ozon'},
          correctOption: 'a',
          category: 'Kimya',
          difficulty: 'basit',
          duration: 10,
        ),
        Question(
          id: '',
          question: 'Mona Lisa tablosunu kim yapmıştır?',
          options: {
            'a': 'Picasso',
            'b': 'Van Gogh',
            'c': 'Da Vinci',
            'd': 'Michelangelo',
          },
          correctOption: 'c',
          category: 'Sanat',
          difficulty: 'orta',
          duration: 15,
        ),
        Question(
          id: '',
          question: 'Hangi hayvan memelidir?',
          options: {'a': 'Yılan', 'b': 'Timsah', 'c': 'Yunus', 'd': 'Penguen'},
          correctOption: 'c',
          category: 'Biyoloji',
          difficulty: 'orta',
          duration: 15,
        ),
        Question(
          id: '',
          question: '1 Byte kaç bittir?',
          options: {'a': '4', 'b': '8', 'c': '16', 'd': '32'},
          correctOption: 'b',
          category: 'Teknoloji',
          difficulty: 'basit',
          duration: 10,
        ),
        Question(
          id: '',
          question: 'Ayasofya hangi şehirdedir?',
          options: {
            'a': 'Ankara',
            'b': 'Konya',
            'c': 'İstanbul',
            'd': 'Edirne',
          },
          correctOption: 'c',
          category: 'Tarih',
          difficulty: 'basit',
          duration: 10,
        ),
      ];

      final batch = _firestore.batch();
      for (var q in sampleQuestions) {
        final docRef = _firestore.collection('questions').doc();
        batch.set(docRef, q.toMap());
      }
      await batch.commit();
    }
  }

  Future<List<Question>> getRandomQuestions(int count) async {
    await seedQuestionsIfEmpty();

    final snapshot = await _firestore.collection('questions').get();
    final allQuestions = snapshot.docs
        .map((d) => Question.fromMap(d.id, d.data()))
        .toList();

    allQuestions.shuffle();
    return allQuestions.take(count).toList();
  }
}
