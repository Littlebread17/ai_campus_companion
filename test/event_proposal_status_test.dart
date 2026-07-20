import 'package:ai_campus_companion/screens/admin_panel_screen.dart';
import 'package:ai_campus_companion/screens/event_proposal_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('proposal statuses use student-friendly labels', () {
    expect(proposalStatusText('submitted'), 'Pending review');
    expect(proposalStatusText('needs_changes'), 'Pending edit');
    expect(proposalStatusText('approved_published'), 'Approved and published');
    expect(proposalStatusText('admin_rejected'), 'Rejected');
  });

  test('proposal approval requires a reviewable status and a PDF', () {
    expect(
      canApproveEventProposal('submitted', 'https://example.com/a.pdf'),
      isTrue,
    );
    expect(canApproveEventProposal('submitted', ''), isFalse);
    expect(
      canApproveEventProposal(
        'approved_published',
        'https://example.com/a.pdf',
      ),
      isFalse,
    );
  });
}
