import 'package:accounting_app/core/presentation/navigation/adaptive_page_route.dart';
import 'package:accounting_app/core/presentation/widgets/adaptive_overlay.dart';
import 'package:accounting_app/core/presentation/widgets/app_snackbar.dart';
import 'package:accounting_app/core/theme/theme_service.dart';
import 'package:accounting_app/features/accounting/data/accounting_repository.dart';
import 'package:accounting_app/features/accounting/domain/entities/accounting_models.dart';
import 'package:accounting_app/features/accounting/presentation/pages/journal_entry_dialog.dart';
import 'package:accounting_app/features/app_update/presentation/app_version_checker_card.dart';
import 'package:accounting_app/features/drive_sync/data/accounting_drive_sync_service.dart';
import 'package:accounting_app/features/security/presentation/biometric_lock_gate.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

enum _AccountingTab {
  overview('Overview', Icons.dashboard_outlined, Icons.dashboard_rounded),
  journal('Journal', Icons.receipt_long_outlined, Icons.receipt_long_rounded),
  accounts('Accounts', Icons.account_balance_outlined, Icons.account_balance_rounded),
  reports('Reports', Icons.assessment_outlined, Icons.assessment_rounded);

  const _AccountingTab(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AccountingRepository _repo = AccountingRepository.instance;
  final AccountingDriveSyncService _driveSync =
      AccountingDriveSyncService.instance;

  _AccountingTab _tab = _AccountingTab.overview;
  int _reportSegment = 0; // 0: Trial Balance, 1: Income Statement, 2: Balance Sheet
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _repo.addListener(_onChanged);
    _driveSync.addListener(_onChanged);
    _repo.initialize();
    _driveSync.initialize();
  }

  @override
  void dispose() {
    _repo.removeListener(_onChanged);
    _driveSync.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  String _fmt(double v) {
    final neg = v < 0;
    final abs = v.abs().toStringAsFixed(2);
    return neg ? '-\$$abs' : '\$$abs';
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _openNewJournal({String? template}) async {
    final saved = await Navigator.of(context).push<bool>(
      adaptivePageRoute(
        context,
        builder: (_) => JournalEntryDialog(initialTemplate: template),
      ),
    );
    if (saved == true && mounted) {
      AppSnackBar.show(
        context,
        'Journal entry posted',
        icon: Icons.check_circle_outline,
      );
    }
  }

  Future<void> _syncWithDrive() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);
    try {
      if (!_driveSync.isSignedIn) {
        final ok = await _driveSync.signIn();
        if (!ok) return;
      }
      final remote = await _driveSync.downloadBackupJson();
      var merged = 0;
      if (remote != null && remote.trim().isNotEmpty) {
        merged = await _repo.mergeBackupJson(remote);
      }
      await _driveSync.uploadBackupJson(_repo.exportBackupJson());
      if (mounted) {
        AppSnackBar.show(
          context,
          merged > 0
              ? 'Synced ledger with Google Drive ($merged imported)'
              : 'Ledger backed up to Google Drive',
          icon: Icons.cloud_done_rounded,
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(
          context,
          AppSnackBar.sanitizeError(e),
          backgroundColor: Theme.of(context).colorScheme.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _showAddAccountDialog() async {
    final codeCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    var selectedType = AccountType.expense;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Account'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: codeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Account Code',
                  hintText: 'e.g. 5500',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Account Name',
                  hintText: 'e.g. Marketing Expense',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<AccountType>(
                initialValue: selectedType,
                decoration: const InputDecoration(labelText: 'Account Type'),
                items: AccountType.values
                    .map(
                      (t) => DropdownMenuItem(value: t, child: Text(t.label)),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) setDialogState(() => selectedType = v);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  await _repo.addAccount(
                    code: codeCtrl.text,
                    name: nameCtrl.text,
                    type: selectedType,
                  );
                  if (ctx.mounted) Navigator.of(ctx).pop();
                } catch (e) {
                  if (ctx.mounted) {
                    AppSnackBar.show(
                      ctx,
                      AppSnackBar.sanitizeError(e),
                      backgroundColor: Theme.of(ctx).colorScheme.error,
                    );
                  }
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
    codeCtrl.dispose();
    nameCtrl.dispose();
  }

  Future<void> _showAccountLedger(Account account) async {
    final postings = _repo.getLedgerPostings(account);
    final bal = _repo.getAccountBalance(account);
    await showAdaptiveDialogOrSheet<void>(
      context: context,
      maxWidth: 640,
      desktopTitle: '${account.code} · ${account.name}',
      desktopIcon: Icons.menu_book_rounded,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Chip(label: Text(account.type.label)),
                  const SizedBox(width: 8),
                  Text(
                    account.type.isDebitNormal
                        ? 'Normal Balance: Debit'
                        : 'Normal Balance: Credit',
                    style: Theme.of(ctx).textTheme.bodySmall,
                  ),
                  const Spacer(),
                  Text(
                    _fmt(bal.normalBalance),
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              const Divider(height: 20),
              if (postings.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text('No ledger postings yet.')),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 360),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: postings.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final p = postings[i];
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text('${p.reference} · ${p.description}'),
                        subtitle: Text(_fmtDate(p.date)),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              p.debit > 0
                                  ? 'Dr ${_fmt(p.debit)}'
                                  : 'Cr ${_fmt(p.credit)}',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: p.debit > 0
                                    ? const Color(0xFF059669)
                                    : const Color(0xFFD97706),
                              ),
                            ),
                            Text(
                              'Bal: ${_fmt(p.runningBalance)}',
                              style: Theme.of(ctx).textTheme.labelSmall,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showBackupSheet() async {
    final jsonCtrl = TextEditingController();
    await showAdaptiveDialogOrSheet<void>(
      context: context,
      maxWidth: 540,
      desktopTitle: 'Backup, Google Drive & Updates',
      desktopIcon: Icons.cloud_sync_rounded,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  child: Icon(
                    _driveSync.isSignedIn
                        ? Icons.cloud_done_rounded
                        : Icons.cloud_outlined,
                  ),
                ),
                title: Text(
                  _driveSync.isSignedIn
                      ? _driveSync.profile?.displayName ?? 'Google Account'
                      : 'Google Drive Ledger Sync',
                ),
                subtitle: Text(
                  _driveSync.isSignedIn
                      ? _driveSync.profile?.email ?? 'Connected'
                      : 'Back up & merge journal entries to Google Drive',
                ),
                trailing: _driveSync.isSignedIn
                    ? TextButton(
                        onPressed: () async {
                          await _driveSync.signOut();
                          if (ctx.mounted) Navigator.of(ctx).pop();
                        },
                        child: const Text('Sign out'),
                      )
                    : FilledButton(
                        onPressed: () async {
                          Navigator.of(ctx).pop();
                          await _syncWithDrive();
                        },
                        child: const Text('Connect'),
                      ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: _repo.exportBackupJson()),
                      );
                      if (ctx.mounted) {
                        AppSnackBar.show(ctx, 'Ledger JSON copied to clipboard');
                      }
                    },
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('Copy JSON Backup'),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      await _repo.clearAllEntries();
                      if (ctx.mounted) Navigator.of(ctx).pop();
                    },
                    icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                    label: const Text('Clear Journal Entries'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: jsonCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Restore / Merge from JSON Backup',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () async {
                    try {
                      final added = await _repo.mergeBackupJson(jsonCtrl.text);
                      if (ctx.mounted) Navigator.of(ctx).pop();
                      if (mounted) {
                        AppSnackBar.show(context, 'Imported $added record(s)');
                      }
                    } catch (e) {
                      if (ctx.mounted) {
                        AppSnackBar.show(
                          ctx,
                          AppSnackBar.sanitizeError(e),
                          backgroundColor: Theme.of(ctx).colorScheme.error,
                        );
                      }
                    }
                  },
                  child: const Text('Import & Merge'),
                ),
              ),
              const Divider(height: 28),
              const AppVersionCheckerCard(autoCheckOnInit: true),
            ],
          ),
        ),
      ),
    );
    jsonCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDesktop = isDesktopLayoutContext(context);
    final summary = _repo.getFinancialStatements();

    return Scaffold(
      appBar: AppBar(
        titleSpacing: isDesktop ? 20 : 8,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.account_balance_wallet_rounded,
                color: cs.onPrimaryContainer,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Accounting App',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Sync with Google Drive',
            icon: _isSyncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    _driveSync.isSignedIn
                        ? Icons.cloud_done_outlined
                        : Icons.cloud_sync_outlined,
                  ),
            onPressed: _isSyncing ? null : _syncWithDrive,
          ),
          IconButton(
            tooltip: 'Theme: ${ThemeService.instance.modeLabel}',
            icon: Icon(ThemeService.instance.modeIcon),
            onPressed: () => ThemeService.instance.cycleThemeMode(),
          ),
          IconButton(
            tooltip: 'Security & App Lock',
            icon: const Icon(Icons.shield_outlined),
            onPressed: () => BiometricLockGate.showSettingsSheet(context),
          ),
          IconButton(
            tooltip: 'Backup & Updates',
            icon: const Icon(Icons.tune_rounded),
            onPressed: _showBackupSheet,
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Row(
        children: [
          if (isDesktop)
            NavigationRail(
              selectedIndex: _tab.index,
              extended: MediaQuery.sizeOf(context).width >= 1060,
              onDestinationSelected: (idx) =>
                  setState(() => _tab = _AccountingTab.values[idx]),
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: FloatingActionButton.extended(
                  heroTag: 'desktop_new_je',
                  onPressed: () => _openNewJournal(),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('New Entry'),
                ),
              ),
              destinations: _AccountingTab.values
                  .map(
                    (t) => NavigationRailDestination(
                      icon: Icon(t.icon),
                      selectedIcon: Icon(t.selectedIcon),
                      label: Text(t.label),
                    ),
                  )
                  .toList(),
            ),
          Expanded(
            child: switch (_tab) {
              _AccountingTab.overview => _buildOverview(summary),
              _AccountingTab.journal => _buildJournal(),
              _AccountingTab.accounts => _buildAccounts(),
              _AccountingTab.reports => _buildReports(summary),
            },
          ),
        ],
      ),
      bottomNavigationBar: isDesktop
          ? null
          : NavigationBar(
              selectedIndex: _tab.index,
              onDestinationSelected: (idx) =>
                  setState(() => _tab = _AccountingTab.values[idx]),
              destinations: _AccountingTab.values
                  .map(
                    (t) => NavigationDestination(
                      icon: Icon(t.icon),
                      selectedIcon: Icon(t.selectedIcon),
                      label: t.label,
                    ),
                  )
                  .toList(),
            ),
      floatingActionButton: isDesktop
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _openNewJournal(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Journal Entry'),
            ),
    );
  }

  Widget _buildOverview(FinancialStatementsSummary s) {
    final cs = Theme.of(context).colorScheme;
    final entries = _repo.entries;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: cs.primaryContainer.withValues(alpha: 0.45),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.balance_rounded, color: cs.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Fundamental Accounting Equation',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const Spacer(),
                    Chip(
                      label: Text(
                        s.isAccountingEquationBalanced ? 'Balanced' : 'Check',
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Assets ${_fmt(s.totalAssets)}  =  Liabilities ${_fmt(s.totalLiabilities)}  +  Equity ${_fmt(s.totalEquity)}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _kpiCard('Total Assets', _fmt(s.totalAssets), const Color(0xFF059669)),
            _kpiCard('Liabilities', _fmt(s.totalLiabilities), const Color(0xFFD97706)),
            _kpiCard('Revenue', _fmt(s.totalRevenue), const Color(0xFF0284C7)),
            _kpiCard('Expenses', _fmt(s.totalExpenses), const Color(0xFFE11D48)),
            _kpiCard(
              'Net Income',
              _fmt(s.netIncome),
              s.netIncome >= 0 ? const Color(0xFF059669) : const Color(0xFFE11D48),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: () => _openNewJournal(template: 'cash_sale'),
              icon: const Icon(Icons.point_of_sale_rounded, size: 18),
              label: const Text('Record Sale'),
            ),
            FilledButton.tonalIcon(
              onPressed: () => _openNewJournal(template: 'expense'),
              icon: const Icon(Icons.receipt_long_rounded, size: 18),
              label: const Text('Record Expense'),
            ),
            OutlinedButton.icon(
              onPressed: () => _openNewJournal(template: 'owner_invest'),
              icon: const Icon(Icons.savings_rounded, size: 18),
              label: const Text('Owner Capital'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          'Recent Journal Entries',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        if (entries.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('No journal entries yet. Tap "New Entry" to begin.'),
            ),
          )
        else
          ...entries.take(5).map(_buildJournalCard),
      ],
    );
  }

  Widget _kpiCard(String label, String value, Color accent) {
    return SizedBox(
      width: 175,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: accent,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildJournal() {
    final entries = _repo.entries;
    if (entries.isEmpty) {
      return Center(
        child: FilledButton.icon(
          onPressed: () => _openNewJournal(),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Post First Journal Entry'),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: entries.length,
      itemBuilder: (_, i) => _buildJournalCard(entries[i]),
    );
  }

  Widget _buildJournalCard(JournalEntry entry) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Chip(
                  label: Text(entry.reference),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    entry.description,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  _fmtDate(entry.date),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                ),
                IconButton(
                  tooltip: 'Delete entry',
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  onPressed: () => _repo.deleteJournalEntry(entry.id),
                ),
              ],
            ),
            const Divider(height: 14),
            ...entry.lines.map((line) {
              final acc = _repo.findAccount(line.accountId);
              final label = acc != null ? '${acc.code} · ${acc.name}' : line.accountId;
              return Padding(
                padding: EdgeInsets.only(
                  left: line.credit > 0 ? 20 : 0,
                  top: 3,
                  bottom: 3,
                ),
                child: Row(
                  children: [
                    Expanded(child: Text(label)),
                    SizedBox(
                      width: 90,
                      child: Text(
                        line.debit > 0 ? _fmt(line.debit) : '',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF059669),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 90,
                      child: Text(
                        line.credit > 0 ? _fmt(line.credit) : '',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFD97706),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildAccounts() {
    final accounts = _repo.accounts;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Text(
              'Chart of Accounts & General Ledger',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const Spacer(),
            FilledButton.tonalIcon(
              onPressed: _showAddAccountDialog,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add Account'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...AccountType.values.map((type) {
          final group = accounts.where((a) => a.type == type).toList();
          if (group.isEmpty) return const SizedBox.shrink();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  '${type.label}s (${type.isDebitNormal ? 'Debit Normal' : 'Credit Normal'})',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: type.badgeColor,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              ...group.map((acc) {
                final bal = _repo.getAccountBalance(acc);
                return Card(
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    onTap: () => _showAccountLedger(acc),
                    leading: CircleAvatar(
                      backgroundColor: type.badgeColor.withValues(alpha: 0.15),
                      child: Text(
                        acc.code.substring(0, 2),
                        style: TextStyle(
                          color: type.badgeColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    title: Text('${acc.code} · ${acc.name}'),
                    subtitle: Text(
                      'Dr ${_fmt(bal.totalDebit)} | Cr ${_fmt(bal.totalCredit)} · Tap for ledger',
                    ),
                    trailing: Text(
                      _fmt(bal.normalBalance),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                );
              }),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildReports(FinancialStatementsSummary s) {
    final tb = _repo.getTrialBalance();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 0, label: Text('Trial Balance')),
            ButtonSegment(value: 1, label: Text('Income Statement')),
            ButtonSegment(value: 2, label: Text('Balance Sheet')),
          ],
          selected: {_reportSegment},
          onSelectionChanged: (set) =>
              setState(() => _reportSegment = set.first),
        ),
        const SizedBox(height: 16),
        if (_reportSegment == 0) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Text(
                        'Trial Balance',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const Spacer(),
                      Chip(
                        label: Text(
                          s.isTrialBalanced ? 'Debits = Credits' : 'Unbalanced',
                        ),
                      ),
                    ],
                  ),
                  const Divider(),
                  ...tb.map(
                    (row) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text('${row.account.code} · ${row.account.name}'),
                          ),
                          SizedBox(
                            width: 95,
                            child: Text(
                              row.trialDebit > 0 ? _fmt(row.trialDebit) : '—',
                              textAlign: TextAlign.right,
                            ),
                          ),
                          SizedBox(
                            width: 95,
                            child: Text(
                              row.trialCredit > 0 ? _fmt(row.trialCredit) : '—',
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'TOTAL',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      SizedBox(
                        width: 95,
                        child: Text(
                          _fmt(s.trialBalanceDebits),
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      SizedBox(
                        width: 95,
                        child: Text(
                          _fmt(s.trialBalanceCredits),
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ] else if (_reportSegment == 1) ...[
          _statementSection(
            title: 'Income Statement (Profit & Loss)',
            rows: [
              ('Total Revenue', _fmt(s.totalRevenue)),
              ('Total Expenses', _fmt(s.totalExpenses)),
            ],
            totalLabel: 'Net Income / (Loss)',
            totalValue: _fmt(s.netIncome),
          ),
        ] else ...[
          _statementSection(
            title: 'Balance Sheet',
            rows: [
              ('Total Assets', _fmt(s.totalAssets)),
              ('Total Liabilities', _fmt(s.totalLiabilities)),
              ('Contributed Equity', _fmt(s.totalContributedEquity)),
              ('Current Net Income', _fmt(s.netIncome)),
            ],
            totalLabel: 'Total Liabilities + Equity',
            totalValue: _fmt(s.totalLiabilities + s.totalEquity),
          ),
        ],
      ],
    );
  }

  Widget _statementSection({
    required String title,
    required List<(String, String)> rows,
    required String totalLabel,
    required String totalValue,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const Divider(),
            ...rows.map(
              (r) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(child: Text(r.$1)),
                    Text(
                      r.$2,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(),
            Row(
              children: [
                Expanded(
                  child: Text(
                    totalLabel,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  totalValue,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
