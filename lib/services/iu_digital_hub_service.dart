class DigitalHubResource {
  final String title;
  final String description;
  final String category;
  final String url;
  final bool fromFirestore;

  const DigitalHubResource({
    required this.title,
    required this.description,
    required this.category,
    required this.url,
    this.fromFirestore = false,
  });

  factory DigitalHubResource.fromMap(Map<String, dynamic> data) {
    return DigitalHubResource(
      title: (data['title'] ?? 'Untitled').toString(),
      description:
          (data['description'] ?? data['source'] ?? 'IU Digital Hub link')
              .toString(),
      category: (data['category'] ?? 'IU Digital Hub').toString(),
      url: (data['linkUrl'] ?? data['url'] ?? data['fileUrl'] ?? '').toString(),
      fromFirestore: true,
    );
  }

  bool matches(String keyword) {
    if (keyword.trim().isEmpty) return true;
    final query = keyword.toLowerCase();
    return title.toLowerCase().contains(query) ||
        description.toLowerCase().contains(query) ||
        category.toLowerCase().contains(query);
  }
}

class IUDigitalHubService {
  static const sourceUrl =
      'https://sites.google.com/student.newinti.edu.my/iudigitalhub/';

  static const fallbackResources = <DigitalHubResource>[
    DigitalHubResource(
      title: 'Student Email',
      description: 'Access INTI student email from IU Digital Hub.',
      category: 'Student Account',
      url: sourceUrl,
    ),
    DigitalHubResource(
      title: 'Canvas LMS',
      description: 'Open Canvas learning management system support link.',
      category: 'Learning',
      url:
          'https://sites.google.com/student.newinti.edu.my/iudigitalhub/resources/canvas-lms',
    ),
    DigitalHubResource(
      title: 'Online Enrolment',
      description: 'Find online enrolment information and links.',
      category: 'Registry',
      url: sourceUrl,
    ),
    DigitalHubResource(
      title: 'E-Library',
      description: 'Open TSAM Library and e-book resources.',
      category: 'Library',
      url:
          'https://sites.google.com/student.newinti.edu.my/iudigitalhub/student-services/tsam-library/ebooks',
    ),
    DigitalHubResource(
      title: 'AFM Helpdesk For Students',
      description: 'Facilities, safety, logistics, and AFM help links.',
      category: 'Student Services',
      url:
          'https://sites.google.com/student.newinti.edu.my/iudigitalhub/student-services/afm',
    ),
    DigitalHubResource(
      title: 'Frequently Asked Questions',
      description: 'Student counselling FAQ and support information.',
      category: 'Counselling',
      url:
          'https://sites.google.com/student.newinti.edu.my/iudigitalhub/student-services/student-counselling/counselling/frequently-asked-questions-faq',
    ),
    DigitalHubResource(
      title: 'Exam Timetable',
      description: 'Find current examination timetable links.',
      category: 'Exam',
      url:
          'https://sites.google.com/student.newinti.edu.my/iudigitalhub/resources/exam-timetable',
    ),
    DigitalHubResource(
      title: 'Forms',
      description: 'Common student forms from IU Digital Hub.',
      category: 'Forms',
      url:
          'https://sites.google.com/student.newinti.edu.my/iudigitalhub/resources/forms',
    ),
    DigitalHubResource(
      title: 'Handbook',
      description: 'Student handbook and programme information.',
      category: 'Handbook',
      url:
          'https://sites.google.com/student.newinti.edu.my/iudigitalhub/resources/handbook',
    ),
    DigitalHubResource(
      title: 'Registry Online Services',
      description: 'Registry services and student records links.',
      category: 'Registry',
      url:
          'https://sites.google.com/student.newinti.edu.my/iudigitalhub/resources/registry-online-services',
    ),
    DigitalHubResource(
      title: 'Past Year Examination Papers',
      description: 'Past year exam paper resource page.',
      category: 'Exam',
      url:
          'https://sites.google.com/student.newinti.edu.my/iudigitalhub/resources/past-year-examination-papers',
    ),
    DigitalHubResource(
      title: 'User Guides',
      description: 'Student user guides for campus systems.',
      category: 'Guide',
      url:
          'https://sites.google.com/student.newinti.edu.my/iudigitalhub/resources/user-guides',
    ),
    DigitalHubResource(
      title: 'Academic Calendar',
      description: 'Academic calendar dates and semester planning links.',
      category: 'Academic Calendar',
      url:
          'https://sites.google.com/student.newinti.edu.my/iudigitalhub/resources/academic-calendar',
    ),
    DigitalHubResource(
      title: 'Office 365 For Students',
      description: 'Office 365 student setup and access link.',
      category: 'Student Account',
      url:
          'https://sites.google.com/student.newinti.edu.my/iudigitalhub/resources/office-365-for-students',
    ),
    DigitalHubResource(
      title: 'INTI IU Ecampus',
      description: 'Open INTI IU eCampus resources.',
      category: 'Learning',
      url:
          'https://sites.google.com/student.newinti.edu.my/iudigitalhub/resources/inti-iu-ecampus',
    ),
    DigitalHubResource(
      title: 'Student Services',
      description: 'Visa, counselling, finance, scholarship, and career links.',
      category: 'Student Services',
      url:
          'https://sites.google.com/student.newinti.edu.my/iudigitalhub/student-services',
    ),
    DigitalHubResource(
      title: 'Finance',
      description: 'Finance department student information.',
      category: 'Finance',
      url:
          'https://sites.google.com/student.newinti.edu.my/iudigitalhub/student-services/finance',
    ),
    DigitalHubResource(
      title: 'Career Services',
      description: 'Career services, internship, and employability links.',
      category: 'Career',
      url:
          'https://sites.google.com/student.newinti.edu.my/iudigitalhub/student-services/career-services',
    ),
    DigitalHubResource(
      title: 'IT Services',
      description: 'IT support and digital service information.',
      category: 'IT Services',
      url:
          'https://sites.google.com/student.newinti.edu.my/iudigitalhub/student-services/it-services',
    ),
  ];
}
