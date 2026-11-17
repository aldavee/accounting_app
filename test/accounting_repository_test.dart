import 'package:accounting_app/features/accounting/data/accounting_repository.dart';
import 'package:accounting_app/features/accounting/domain/entities/accounting_models.dart';
import 'package:accounting_app/features/app_update/data/app_update_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('AccountingRepository enforces double-entry balance and computes statements', () async {
    final repo = AccountingRepository();
    await repo.initialize();

    final initial = repo.getFinancialStatements();
    expect(initial.isAccountingEquationBalanced, isTrue);
    expect(initial.isTrialBalanced, isTrue);
    // Seeded: +10000 Capital, +1500 Revenue, -600 Expense => Net Income 900, Equity 10900, Assets 10900
    expect(initial.totalAssets, closeTo(10900.0, 0.01));
    expect(initial.netIncome, closeTo(900.0, 0.01));

    // Reject unbalanced journal entry
    expect(
      () => repo.postJournalEntry(
        date: DateTime.now(),
        reference: 'BAD-1',
        description: 'Unbalanced test',
        lines: const [
          JournalLine(accountId: 'acc_1100', debit: 100.0),
          JournalLine(accountId: 'acc_4000', credit: 50.0),
        ],
      ),
      throwsArgumentError,
    );

    // Post balanced equipment purchase on loan
    await repo.postJournalEntry(
      date: DateTime.now(),
      reference: 'JE-004',
      description: 'Purchase equipment on loan',
      lines: const [
        JournalLine(accountId: 'acc_1500', debit: 2000.0),
        JournalLine(accountId: 'acc_2100', credit: 2000.0),
      ],
    );

    final after = repo.getFinancialStatements();
    expect(after.totalAssets, closeTo(12900.0, 0.01));
    expect(after.totalLiabilities, closeTo(2000.0, 0.01));
    expect(after.isAccountingEquationBalanced, isTrue);
    expect(after.isTrialBalanced, isTrue);

    final equipAcc = repo.findAccount('acc_1500')!;
    final postings = repo.getLedgerPostings(equipAcc);
    expect(postings.length, 1);
    expect(postings.first.runningBalance, closeTo(2000.0, 0.01));
  });

  test('AppUpdateService.compareVersions works for Accounting App', () {
    expect(AppUpdateService.compareVersions('1.0.0+2', '1.0.0+1'), greaterThan(0));
    expect(AppUpdateService.compareVersions('1.0.0+1', '1.0.0+1'), 0);
  });
}
