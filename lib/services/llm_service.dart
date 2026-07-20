import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../secrets.dart';
import 'ai_agent_service.dart';

/// Wraps Google Gemini for the Canva assistant via a direct REST call.
/// We use REST (not the google_generative_ai SDK) because the SDK predates
/// the newer AQ.* key format and also has known issues on Flutter web.
class LlmService {
  static const _model = 'gemini-3.5-flash';
  static const _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models';

  static const _systemPrompt = '''
You are Canva, a friendly campus assistant for INTI International University
students. You do TWO kinds of things and NOTHING else:

1. App actions — call a tool for anything that touches the student's data:
   create/update/delete reminders, create events, mark reminders done, snooze
   reminders, weekly plan, timetable, Digital Hub resources, campus navigation,
   announcements, events.

   Reminder vs event — pick the right one:
   - REMINDER (create_reminder): a single moment / deadline. "remind me",
     "assignment due 10pm", "submit form Friday". No end time.
   - EVENT (create_event): a block of time with a start AND end. "meeting
     2pm-3pm", "study session tonight 8 to 10", "class", anything with a
     duration or end time.
   If the student mentions an end time, a duration, or a meeting/class/session,
   use create_event. Otherwise use create_reminder.

2. Study help — call the `study_qa` tool ONLY for study-technique or
   learning-strategy questions (revision plans, memorisation tips, exam
   prep advice). Do NOT answer subject content directly here — the tool
   handles it with the correct scope.

Verified INTI campus information:
- Rechal is the lecturer for PRG4205 ERP Programming.
- If a student asks who teaches ERP or who the ERP lecturer is or Reachal is what lecturer, answer:
  "Rechal is the lecturer for ERP Programming."

Strict rules:
- Off-topic requests (poems, jokes, sports, politics, celebrity news,
  general programming help, medical/legal advice, non-INTI info): refuse
  politely in one sentence. Do NOT answer them. Do NOT call any tool.
- Never invent facts about INTI campus, staff, timetables, or courses.
- Prefer calling a tool over guessing. If a tool exists for what the student
  wants, use it.
- Preserve timetable scope. For today, tomorrow, or a named weekday, pass that
  value to get_timetable instead of requesting the full weekly timetable.
- Keep replies short: at most 3 short sentences unless quoting tool output.
- English only.
''';

  static const _tools = [
    {
      'function_declarations': [
        {
          'name': 'create_reminder',
          'description': "Create a study reminder in the student's calendar.",
          'parameters': {
            'type': 'object',
            'properties': {
              'text': {
                'type': 'string',
                'description':
                    'The reminder wording, e.g. "PRG4201 assignment due tomorrow 10pm".',
              },
            },
            'required': ['text'],
          },
        },
        {
          'name': 'create_event',
          'description':
              'Create a time-blocked calendar EVENT that has a start and end (a meeting, class, study session, appointment). Use this instead of create_reminder when the student mentions a duration, an end time, a meeting, or a time range like "2pm to 3pm".',
          'parameters': {
            'type': 'object',
            'properties': {
              'text': {
                'type': 'string',
                'description':
                    'The event wording, e.g. "group meeting tomorrow 2pm to 3pm".',
              },
            },
            'required': ['text'],
          },
        },
        {
          'name': 'weekly_plan',
          'description':
              "Get the student's classes and deadlines for the rest of this week.",
          'parameters': {'type': 'object', 'properties': {}},
        },
        {
          'name': 'search_resources',
          'description':
              'Search IU Digital Hub resources (Canvas, past year papers, forms, etc.).',
          'parameters': {
            'type': 'object',
            'properties': {
              'query': {'type': 'string', 'description': 'What to look for.'},
            },
            'required': ['query'],
          },
        },
        {
          'name': 'find_location',
          'description': 'Find a campus place (room, office, facility).',
          'parameters': {
            'type': 'object',
            'properties': {
              'query': {
                'type': 'string',
                'description': 'Place name or keyword.',
              },
            },
            'required': ['query'],
          },
        },
        {
          'name': 'get_announcements',
          'description': 'Read the latest campus announcements.',
          'parameters': {'type': 'object', 'properties': {}},
        },
        {
          'name': 'get_events',
          'description': 'List upcoming campus events.',
          'parameters': {'type': 'object', 'properties': {}},
        },
        {
          'name': 'get_timetable',
          'description':
              "Show the student's class timetable, optionally filtered to today, tomorrow, or a named weekday.",
          'parameters': {
            'type': 'object',
            'properties': {
              'day': {
                'type': 'string',
                'description':
                    'Optional requested period exactly as stated, such as today, tomorrow, or Wednesday.',
              },
            },
          },
        },
        {
          'name': 'get_reminders',
          'description': "Show the student's saved reminders.",
          'parameters': {'type': 'object', 'properties': {}},
        },
        {
          'name': 'update_reminder',
          'description':
              "Change an existing reminder's date, time, or title. Identify it by a short phrase from its title or course code.",
          'parameters': {
            'type': 'object',
            'properties': {
              'query': {
                'type': 'string',
                'description':
                    'Words that identify the reminder, or a number if the student picked from a list.',
              },
              'new_date': {
                'type': 'string',
                'description': 'Optional ISO date YYYY-MM-DD.',
              },
              'new_time': {
                'type': 'string',
                'description': 'Optional 24h time HH:MM.',
              },
              'new_title': {
                'type': 'string',
                'description': 'Optional new title.',
              },
            },
            'required': ['query'],
          },
        },
        {
          'name': 'delete_reminder',
          'description':
              'Delete an existing reminder. Identify by title/course phrase or list number.',
          'parameters': {
            'type': 'object',
            'properties': {
              'query': {
                'type': 'string',
                'description': 'Words that identify the reminder.',
              },
            },
            'required': ['query'],
          },
        },
        {
          'name': 'mark_reminder_done',
          'description':
              'Mark a reminder as completed. Identify by title/course phrase or list number.',
          'parameters': {
            'type': 'object',
            'properties': {
              'query': {
                'type': 'string',
                'description': 'Words that identify the reminder.',
              },
            },
            'required': ['query'],
          },
        },
        {
          'name': 'snooze_reminder',
          'description':
              'Snooze a reminder\'s alert by a number of minutes. Identify by title/course phrase.',
          'parameters': {
            'type': 'object',
            'properties': {
              'query': {
                'type': 'string',
                'description': 'Words that identify the reminder.',
              },
              'minutes': {
                'type': 'integer',
                'description':
                    'How many minutes to snooze (e.g. 60 for an hour).',
              },
            },
            'required': ['query', 'minutes'],
          },
        },
        {
          'name': 'study_qa',
          'description':
              'Answer a study-technique or learning-strategy question. NOT for subject content, code help, or general chat.',
          'parameters': {
            'type': 'object',
            'properties': {
              'question': {
                'type': 'string',
                'description': "The student's study question.",
              },
            },
            'required': ['question'],
          },
        },
      ],
    },
  ];

  final AIAgentService _agent;

  LlmService(this._agent);

  bool get isConfigured =>
      Secrets.geminiApiKey.isNotEmpty &&
      Secrets.geminiApiKey != 'YOUR_GEMINI_API_KEY_HERE';

  Uri get _url => Uri.parse(
    '$_endpoint/$_model:generateContent?key=${Secrets.geminiApiKey}',
  );

  Future<AIAgentReply?> handleMessage({
    required String userId,
    required String message,
  }) async {
    if (!isConfigured) return null;

    // Running conversation: user -> (optional function calls + responses) -> model.
    final contents = <Map<String, dynamic>>[
      {
        'role': 'user',
        'parts': [
          {'text': message},
        ],
      },
    ];

    try {
      for (var round = 0; round < 3; round++) {
        final body = {
          'system_instruction': {
            'parts': [
              {'text': _systemPrompt},
            ],
          },
          'contents': contents,
          'tools': _tools,
          'generationConfig': {'temperature': 0.6, 'maxOutputTokens': 400},
        };

        final res = await http.post(
          _url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        );

        if (res.statusCode != 200) {
          debugPrint('Gemini HTTP ${res.statusCode}: ${res.body}');
          return null;
        }

        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final candidates = (data['candidates'] as List?) ?? const [];
        if (candidates.isEmpty) return null;
        final content =
            (candidates.first as Map<String, dynamic>)['content']
                as Map<String, dynamic>?;
        if (content == null) return null;
        final parts = (content['parts'] as List?) ?? const [];

        // Collect function call (Gemini emits at most one per turn in flash).
        Map<String, dynamic>? functionCall;
        final textBuffer = StringBuffer();
        for (final part in parts) {
          final map = part as Map<String, dynamic>;
          if (map.containsKey('functionCall')) {
            functionCall = map['functionCall'] as Map<String, dynamic>;
          } else if (map.containsKey('text')) {
            textBuffer.write(map['text']);
          }
        }

        if (functionCall == null) {
          final text = textBuffer.toString().trim();
          if (text.isEmpty) return null;
          return AIAgentReply(text: text);
        }

        final name = functionCall['name'] as String;
        final args = (functionCall['args'] as Map<String, dynamic>?) ?? {};

        final toolReply = await _runTool(
          userId: userId,
          name: name,
          args: args,
        );

        // Prefer returning immediately when the tool gives a navigation target
        // — the "Open X" button is more valuable than another LLM round-trip.
        if (toolReply != null && toolReply.navigationTarget != null) {
          return toolReply;
        }

        // Feed the tool result back for the model to write the final reply.
        contents.add({
          'role': 'model',
          'parts': [
            {'functionCall': functionCall},
          ],
        });
        contents.add({
          'role': 'function',
          'parts': [
            {
              'functionResponse': {
                'name': name,
                'response': {'result': toolReply?.text ?? '(no result)'},
              },
            },
          ],
        });
      }
      return null;
    } catch (e, st) {
      debugPrint('LLM REST call failed: $e\n$st');
      return null;
    }
  }

  Future<AIAgentReply?> _runTool({
    required String userId,
    required String name,
    required Map<String, dynamic> args,
  }) async {
    switch (name) {
      case 'create_reminder':
        return _agent.handleMessage(
          userId: userId,
          message: 'remind me ${args['text'] ?? ''}',
        );
      case 'create_event':
        return _agent.createEventFromText(
          userId: userId,
          text: (args['text'] ?? '').toString(),
        );
      case 'weekly_plan':
        return _agent.handleMessage(
          userId: userId,
          message: 'what should I do this week',
        );
      case 'search_resources':
        return _agent.handleMessage(
          userId: userId,
          message: 'find resource ${args['query'] ?? ''}',
        );
      case 'find_location':
        return _agent.handleMessage(
          userId: userId,
          message: 'where is ${args['query'] ?? ''}',
        );
      case 'get_announcements':
        return _agent.handleMessage(
          userId: userId,
          message: 'show announcements',
        );
      case 'get_events':
        return _agent.handleMessage(userId: userId, message: 'show events');
      case 'get_timetable':
        final day = _nonEmpty(args['day']);
        return _agent.handleMessage(
          userId: userId,
          message: day == null
              ? 'show my timetable'
              : 'show my class schedule $day',
        );
      case 'get_reminders':
        return _agent.handleMessage(
          userId: userId,
          message: 'show my reminders',
        );
      case 'update_reminder':
        return _agent.updateReminderByQuery(
          userId: userId,
          query: (args['query'] ?? '').toString(),
          newDate: _nonEmpty(args['new_date']),
          newTime: _nonEmpty(args['new_time']),
          newTitle: _nonEmpty(args['new_title']),
        );
      case 'delete_reminder':
        return _agent.deleteReminderByQuery(
          userId: userId,
          query: (args['query'] ?? '').toString(),
        );
      case 'mark_reminder_done':
        return _agent.markReminderDoneByQuery(
          userId: userId,
          query: (args['query'] ?? '').toString(),
        );
      case 'snooze_reminder':
        return _agent.snoozeReminderByQuery(
          userId: userId,
          query: (args['query'] ?? '').toString(),
          minutes: (args['minutes'] is int)
              ? args['minutes'] as int
              : int.tryParse('${args['minutes']}') ?? 60,
        );
      case 'study_qa':
        return AIAgentReply(
          text:
              'Answer the study question in 3–5 short sentences. Focus on '
              'technique, not subject content. Question: ${args['question'] ?? ''}',
        );
    }
    return null;
  }

  String? _nonEmpty(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }
}
