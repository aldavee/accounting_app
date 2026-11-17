import 'dart:convert';
import 'dart:io';

import 'package:accounting_app/features/accounting/domain/entities/accounting_models.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AccountingRepository extends ChangeNotifier {
  AccountingRepository({
    Future<SharedPreferences> Function()? prefsProvider,
    Future<Directory?> Function()? directoryProvider,
  })  : _prefsProvider = prefsProvider ?? SharedPreferences.getInstance,
        _directoryProvider = directoryProvider ?? _defaultDirectoryProvider;

  static final AccountingRepository instance = AccountingRepository();

  static const String _prefsAccountsKey = 'accounting_app_accounts_v1';
  static const String _prefsEntriesKey = 'accounting_app_entries_v1';
  static const String _prefsSeededKey = 'accounting_app_seeded_v1';

  final Future<SharedPreferences> Function() _prefsProvider;
  final Future<Directory?> Function() _directoryProvider;

  List<Account> _accounts = <Account>[];
  List<JournalEntry> _entries = <JournalEntry>[];
  bool _initialized = false;

  static Future<Directory?> _defaultDirectoryProvider() async {
    if (kIsWeb || Platform.environment.containsKey('FLUTTER_TEST')) {
      return null;
    }
    try {
      return await getApplicationDocumentsDirectory();
    } catch (_) {
      return null;
    }
  }

  List<Account> get accounts => List.unmodifiable(_accounts);
  List<JournalEntry> get entries {
    final copy = List<JournalEntry>.from(_entries);
    copy.sort((a, b) {
      final cmp = b.date.compareTo(a.date);
      return cmp != 0 ? cmp : b.createdAt.compareTo(a.createdAt);
    });
    return copy;
  }

  static List<Account> defaultChartOfAccounts() => const [
        Account(id: 'acc_1000', code: '1000', name: 'Cash on Hand', type: AccountType.asset, isSystem: true),
        Account(id: 'acc_1100', code: '1100', name: 'Bank / Checking', type: AccountType.asset, isSystem: true),
        Account(id: 'acc_1200', code: '1200', name: 'Accounts Receivable', type: AccountType.asset, isSystem: true),
        Account(id: 'acc_1300', code: '1300', name: 'Supplies & Inventory', type: AccountType.asset, isSystem: true),
        Account(id: 'acc_1500', code: '1500', name: 'Equipment', type: AccountType.asset, isSystem: true),
        Account(id: 'acc_2000', code: '2000', name: 'Accounts Payable', type: AccountType.liability, isSystem: true),
        Account(id: 'acc_2100', code: '2100', name: 'Loans Payable', type: AccountType.liability, isSystem: true),
        Account(id: 'acc_2200', code: '2200', name: 'Taxes Payable', type: AccountType.liability, isSystem: true),
        Account(id: 'acc_3000', code: '3000', name: "Owner's Capital", type: AccountType.equity, isSystem: true),
        Account(id: 'acc_3100', code: '3100', name: "Owner's Drawings", type: AccountType.equity, isSystem: true),
        Account(id: 'acc_3200', code: '3200', name: 'Retained Earnings', type: AccountType.equity, isSystem: true),
        Account(id: 'acc_4000', code: '4000', name: 'Sales Revenue', type: AccountType.revenue, isSystem: true),
        Account(id: 'acc_4100', code: '4100', name: 'Service Income', type: AccountType.revenue, isSystem: true),
        Account(id: 'acc_5000', code: '5000', name: 'Cost of Goods Sold', type: AccountType.expense, isSystem: true),
        Account(id: 'acc_5100', code: '5100', name: 'Rent Expense', type: AccountType.expense, isSystem: true),
        Account(id: 'acc_5200', code: '5200', name: 'Utilities Expense', type: AccountType.expense, isSystem: true),
        Account(id: 'acc_5300', code: '5300', name: 'Salaries & Wages', type: AccountType.expense, isSystem: true),
        Account(id: 'acc_5400', code: '5400', name: 'Supplies Expense', type: AccountType.expense, isSystem: true),
      ];

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    final prefs = await _prefsProvider();
    String? rawBackup;
    final file = await _resolveStorageFile();
    if (file != null && await file.exists()) {
      try {
        rawBackup = await file.readAsString();
      } catch (_) {}
    }

    if (rawBackup != null && rawBackup.trim().isNotEmpty) {
      try {
        _loadFromJsonMap(jsonDecode(rawBackup) as Map<String, dynamic>);
      } catch (_) {}
    } else {
      final accStr = prefs.getString(_prefsAccountsKey);
      final entStr = prefs.getString(_prefsEntriesKey);
      if (accStr != null) {
        _accounts = (jsonDecode(accStr) as List)
            .whereType<Map>()
            .map((e) => Account.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      if (entStr != null) {
        _entries = (jsonDecode(entStr) as List)
            .whereType<Map>()
            .map((e) => JournalEntry.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    }

    if (_accounts.isEmpty) {
      _accounts = List<Account>.from(defaultChartOfAccounts());
    }

    final seeded = prefs.getBool(_prefsSeededKey) ?? false;
    if (!seeded && _entries.isEmpty) {
      final now = DateTime.now().toUtc();
      _entries = [
        JournalEntry(
          id: 'je_seed_1',
          date: now.subtract(const Duration(days: 2)),
          reference: 'JE-001',
          description: 'Initial owner capital investment',
          createdAt: now.subtract(const Duration(days: 2)),
          lines: const [
            JournalLine(accountId: 'acc_1100', debit: 10000.0),
            JournalLine(accountId: 'acc_3000', credit: 10000.0),
          ],
        ),
        JournalEntry(
          id: 'je_seed_2',
          date: now.subtract(const Duration(days: 1)),
          reference: 'JE-002',
          description: 'Client consulting service revenue (cash)',
          createdAt: now.subtract(const Duration(days: 1)),
          lines: const [
            JournalLine(accountId: 'acc_1100', debit: 1500.0),
            JournalLine(accountId: 'acc_4100', credit: 1500.0),
          ],
        ),
        JournalEntry(
          id: 'je_seed_3',
          date: now,
          reference: 'JE-003',
          description: 'Office rent payment',
          createdAt: now,
          lines: const [
            JournalLine(accountId: 'acc_5100', debit: 600.0),
            JournalLine(accountId: 'acc_1100', credit: 600.0),
          ],
        ),
      ];
      await prefs.setBool(_prefsSeededKey, true);
      await _persist();
    }

    notifyListeners();
  }

  Future<File?> _resolveStorageFile() async {
    final dir = await _directoryProvider();
    if (dir == null) return null;
    final sub = Directory('${dir.path}/accounting_app');
    if (!await sub.exists()) {
      await sub.create(recursive: true);
    }
    return File('${sub.path}/ledger.json');
  }

  void _loadFromJsonMap(Map<String, dynamic> map) {
    if (map['accounts'] is List) {
      _accounts = (map['accounts'] as List)
          .whereType<Map>()
          .map((e) => Account.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    if (map['entries'] is List) {
      _entries = (map['entries'] as List)
          .whereType<Map>()
          .map((e) => JournalEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
  }

  Future<void> _persist() async {
    final prefs = await _prefsProvider();
    await prefs.setString(
      _prefsAccountsKey,
      jsonEncode(_accounts.map((a) => a.toJson()).toList()),
    );
    await prefs.setString(
      _prefsEntriesKey,
      jsonEncode(_entries.map((e) => e.toJson()).toList()),
    );

    final file = await _resolveStorageFile();
    if (file != null) {
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsString(exportBackupJson());
      if (await file.exists()) await file.delete();
      await tmp.rename(file.path);
    }
  }

  Account? findAccount(String id) {
    for (final a in _accounts) {
      if (a.id == id) return a;
    }
    return null;
  }

  Future<Account> addAccount({
    required String code,
    required String name,
    required AccountType type,
    String description = '',
  }) async {
    await initialize();
    final cleanCode = code.trim();
    final cleanName = name.trim();
    if (cleanCode.isEmpty || cleanName.isEmpty) {
      throw ArgumentError('Account code and name are required.');
    }
    if (_accounts.any((a) => a.code == cleanCode)) {
      throw ArgumentError('Account code $cleanCode already exists.');
    }
    final acc = Account(
      id: 'acc_${DateTime.now().microsecondsSinceEpoch}',
      code: cleanCode,
      name: cleanName,
      type: type,
      description: description.trim(),
    );
    _accounts = [..._accounts, acc]..sort((a, b) => a.code.compareTo(b.code));
    await _persist();
    notifyListeners();
    return acc;
  }

  Future<JournalEntry> postJournalEntry({
    required DateTime date,
    required String reference,
    required String description,
    required List<JournalLine> lines,
  }) async {
    await initialize();
    final validLines =
        lines.where((l) => l.debit > 0 || l.credit > 0).toList();
    if (validLines.length < 2) {
      throw ArgumentError('A double-entry journal requires at least 2 lines.');
    }
    for (final l in validLines) {
      if (l.debit < 0 || l.credit < 0 || (l.debit > 0 && l.credit > 0)) {
        throw ArgumentError('Each line must have either a positive debit or credit.');
      }
      if (findAccount(l.accountId) == null) {
        throw ArgumentError('Unknown account ID: ${l.accountId}');
      }
    }

    final totalDebit = validLines.fold(0.0, (s, l) => s + l.debit);
    final totalCredit = validLines.fold(0.0, (s, l) => s + l.credit);
    if (totalDebit <= 0 || (totalDebit - totalCredit).abs() >= 0.005) {
      throw ArgumentError(
        'Debits (${totalDebit.toStringAsFixed(2)}) must equal Credits (${totalCredit.toStringAsFixed(2)}).',
      );
    }

    final nextNum = _entries.length + 1;
    final cleanRef = reference.trim().isEmpty
        ? 'JE-${nextNum.toString().padLeft(3, '0')}'
        : reference.trim();

    final entry = JournalEntry(
      id: 'je_${DateTime.now().microsecondsSinceEpoch}',
      date: date,
      reference: cleanRef,
      description: description.trim().isEmpty ? 'Journal Entry' : description.trim(),
      lines: validLines,
      createdAt: DateTime.now().toUtc(),
    );
    _entries.add(entry);
    await _persist();
    notifyListeners();
    return entry;
  }

  Future<void> deleteJournalEntry(String entryId) async {
    await initialize();
    _entries.removeWhere((e) => e.id == entryId);
    await _persist();
    notifyListeners();
  }

  Future<void> clearAllEntries() async {
    await initialize();
    _entries.clear();
    await _persist();
    notifyListeners();
  }

  AccountBalanceSummary getAccountBalance(Account account) {
    var debitSum = 0.0;
    var creditSum = 0.0;
    for (final entry in _entries) {
      for (final line in entry.lines) {
        if (line.accountId == account.id) {
          debitSum += line.debit;
          creditSum += line.credit;
        }
      }
    }
    final normal = account.type.isDebitNormal
        ? debitSum - creditSum
        : creditSum - debitSum;
    return AccountBalanceSummary(
      account: account,
      totalDebit: debitSum,
      totalCredit: creditSum,
      normalBalance: normal,
    );
  }

  List<LedgerPosting> getLedgerPostings(Account account) {
    final chronological = List<JournalEntry>.from(_entries)
      ..sort((a, b) {
        final cmp = a.date.compareTo(b.date);
        return cmp != 0 ? cmp : a.createdAt.compareTo(b.createdAt);
      });

    var running = 0.0;
    final postings = <LedgerPosting>[];
    for (final entry in chronological) {
      for (final line in entry.lines) {
        if (line.accountId == account.id) {
          running += account.type.isDebitNormal
              ? (line.debit - line.credit)
              : (line.credit - line.debit);
          postings.add(
            LedgerPosting(
              entryId: entry.id,
              date: entry.date,
              reference: entry.reference,
              description: line.memo.isNotEmpty
                  ? '${entry.description} — ${line.memo}'
                  : entry.description,
              debit: line.debit,
              credit: line.credit,
              runningBalance: running,
            ),
          );
        }
      }
    }
    return postings;
  }

  List<AccountBalanceSummary> getTrialBalance({bool includeZero = false}) {
    final sorted = List<Account>.from(_accounts)
      ..sort((a, b) => a.code.compareTo(b.code));
    final list = sorted.map(getAccountBalance).where((s) {
      if (includeZero) return true;
      return s.totalDebit > 0 || s.totalCredit > 0;
    }).toList();
    return list;
  }

  FinancialStatementsSummary getFinancialStatements() {
    var assets = 0.0;
    var liabilities = 0.0;
    var equity = 0.0;
    var revenue = 0.0;
    var expenses = 0.0;
    var tbDebits = 0.0;
    var tbCredits = 0.0;

    for (final acc in _accounts) {
      final bal = getAccountBalance(acc);
      tbDebits += bal.trialDebit;
      tbCredits += bal.trialCredit;
      switch (acc.type) {
        case AccountType.asset:
          assets += bal.normalBalance;
          break;
        case AccountType.liability:
          liabilities += bal.normalBalance;
          break;
        case AccountType.equity:
          equity += bal.normalBalance;
          break;
        case AccountType.revenue:
          revenue += bal.normalBalance;
          break;
        case AccountType.expense:
          expenses += bal.normalBalance;
          break;
      }
    }

    return FinancialStatementsSummary(
      totalAssets: assets,
      totalLiabilities: liabilities,
      totalContributedEquity: equity,
      totalRevenue: revenue,
      totalExpenses: expenses,
      trialBalanceDebits: tbDebits,
      trialBalanceCredits: tbCredits,
    );
  }

  String exportBackupJson() {
    return const JsonEncoder.withIndent('  ').convert({
      'app': 'accounting_app',
      'schemaVersion': 1,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'accounts': _accounts.map((a) => a.toJson()).toList(),
      'entries': _entries.map((e) => e.toJson()).toList(),
    });
  }

  Future<int> mergeBackupJson(String rawJson) async {
    await initialize();
    final decoded = jsonDecode(rawJson);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid Accounting App backup JSON.');
    }
    var added = 0;
    if (decoded['accounts'] is List) {
      for (final raw in decoded['accounts'] as List) {
        if (raw is! Map) continue;
        final acc = Account.fromJson(Map<String, dynamic>.from(raw));
        if (acc.id.isNotEmpty && findAccount(acc.id) == null) {
          _accounts.add(acc);
          added++;
        }
      }
    }
    if (decoded['entries'] is List) {
      for (final raw in decoded['entries'] as List) {
        if (raw is! Map) continue;
        final entry = JournalEntry.fromJson(Map<String, dynamic>.from(raw));
        if (entry.id.isNotEmpty && !_entries.any((e) => e.id == entry.id)) {
          _entries.add(entry);
          added++;
        }
      }
    }
    await _persist();
    notifyListeners();
    return added;
  }
}
