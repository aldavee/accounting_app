import 'package:material_ui/material_ui.dart';

enum AccountType {
  asset('Asset', true, Color(0xFF059669)),
  liability('Liability', false, Color(0xFFD97706)),
  equity('Equity', false, Color(0xFF4F46E5)),
  revenue('Revenue', false, Color(0xFF0284C7)),
  expense('Expense', true, Color(0xFFE11D48));

  const AccountType(this.label, this.isDebitNormal, this.badgeColor);

  final String label;
  final bool isDebitNormal;
  final Color badgeColor;

  static AccountType fromName(String? raw) {
    return AccountType.values.firstWhere(
      (t) => t.name == raw,
      orElse: () => AccountType.asset,
    );
  }
}

class Account {
  const Account({
    required this.id,
    required this.code,
    required this.name,
    required this.type,
    this.description = '',
    this.isSystem = false,
  });

  final String id;
  final String code;
  final String name;
  final AccountType type;
  final String description;
  final bool isSystem;

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'name': name,
        'type': type.name,
        'description': description,
        'isSystem': isSystem,
      };

  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      id: (json['id'] ?? '').toString(),
      code: (json['code'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      type: AccountType.fromName(json['type']?.toString()),
      description: (json['description'] ?? '').toString(),
      isSystem: json['isSystem'] == true,
    );
  }
}

class JournalLine {
  const JournalLine({
    required this.accountId,
    this.debit = 0.0,
    this.credit = 0.0,
    this.memo = '',
  });

  final String accountId;
  final double debit;
  final double credit;
  final String memo;

  Map<String, dynamic> toJson() => {
        'accountId': accountId,
        'debit': debit,
        'credit': credit,
        if (memo.isNotEmpty) 'memo': memo,
      };

  factory JournalLine.fromJson(Map<String, dynamic> json) {
    return JournalLine(
      accountId: (json['accountId'] ?? '').toString(),
      debit: (json['debit'] as num?)?.toDouble() ?? 0.0,
      credit: (json['credit'] as num?)?.toDouble() ?? 0.0,
      memo: (json['memo'] ?? '').toString(),
    );
  }
}

class JournalEntry {
  const JournalEntry({
    required this.id,
    required this.date,
    required this.reference,
    required this.description,
    required this.lines,
    required this.createdAt,
  });

  final String id;
  final DateTime date;
  final String reference;
  final String description;
  final List<JournalLine> lines;
  final DateTime createdAt;

  double get totalDebit => lines.fold(0.0, (sum, l) => sum + l.debit);
  double get totalCredit => lines.fold(0.0, (sum, l) => sum + l.credit);
  bool get isBalanced =>
      lines.length >= 2 &&
      totalDebit > 0.0 &&
      (totalDebit - totalCredit).abs() < 0.005;

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toUtc().toIso8601String(),
        'reference': reference,
        'description': description,
        'lines': lines.map((l) => l.toJson()).toList(),
        'createdAt': createdAt.toUtc().toIso8601String(),
      };

  factory JournalEntry.fromJson(Map<String, dynamic> json) {
    final rawLines = json['lines'] as List? ?? const [];
    return JournalEntry(
      id: (json['id'] ?? '').toString(),
      date: DateTime.tryParse((json['date'] ?? '').toString()) ??
          DateTime.now().toUtc(),
      reference: (json['reference'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      lines: rawLines
          .whereType<Map>()
          .map((e) => JournalLine.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.now().toUtc(),
    );
  }
}

class LedgerPosting {
  const LedgerPosting({
    required this.entryId,
    required this.date,
    required this.reference,
    required this.description,
    required this.debit,
    required this.credit,
    required this.runningBalance,
  });

  final String entryId;
  final DateTime date;
  final String reference;
  final String description;
  final double debit;
  final double credit;
  final double runningBalance;
}

class AccountBalanceSummary {
  const AccountBalanceSummary({
    required this.account,
    required this.totalDebit,
    required this.totalCredit,
    required this.normalBalance,
  });

  final Account account;
  final double totalDebit;
  final double totalCredit;
  final double normalBalance;

  double get trialDebit =>
      account.type.isDebitNormal
          ? (normalBalance >= 0 ? normalBalance : 0.0)
          : (normalBalance < 0 ? -normalBalance : 0.0);

  double get trialCredit =>
      !account.type.isDebitNormal
          ? (normalBalance >= 0 ? normalBalance : 0.0)
          : (normalBalance < 0 ? -normalBalance : 0.0);
}

class FinancialStatementsSummary {
  const FinancialStatementsSummary({
    required this.totalAssets,
    required this.totalLiabilities,
    required this.totalContributedEquity,
    required this.totalRevenue,
    required this.totalExpenses,
    required this.trialBalanceDebits,
    required this.trialBalanceCredits,
  });

  final double totalAssets;
  final double totalLiabilities;
  final double totalContributedEquity;
  final double totalRevenue;
  final double totalExpenses;
  final double trialBalanceDebits;
  final double trialBalanceCredits;

  double get netIncome => totalRevenue - totalExpenses;
  double get totalEquity => totalContributedEquity + netIncome;
  bool get isTrialBalanced =>
      (trialBalanceDebits - trialBalanceCredits).abs() < 0.01;
  bool get isAccountingEquationBalanced =>
      (totalAssets - (totalLiabilities + totalEquity)).abs() < 0.01;
}
