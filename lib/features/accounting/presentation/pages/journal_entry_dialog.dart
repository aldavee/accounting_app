import 'package:accounting_app/core/presentation/widgets/app_snackbar.dart';
import 'package:accounting_app/features/accounting/data/accounting_repository.dart';
import 'package:accounting_app/features/accounting/domain/entities/accounting_models.dart';
import 'package:material_ui/material_ui.dart';

class _DraftLine {
  _DraftLine({
    required this.accountId,
    String debitText = '',
    String creditText = '',
  })  : debitCtrl = TextEditingController(text: debitText),
        creditCtrl = TextEditingController(text: creditText);

  String accountId;
  final TextEditingController debitCtrl;
  final TextEditingController creditCtrl;

  double get debit => double.tryParse(debitCtrl.text.trim()) ?? 0.0;
  double get credit => double.tryParse(creditCtrl.text.trim()) ?? 0.0;

  void dispose() {
    debitCtrl.dispose();
    creditCtrl.dispose();
  }
}

class JournalEntryDialog extends StatefulWidget {
  const JournalEntryDialog({
    this.initialTemplate,
    super.key,
  });

  final String? initialTemplate;

  @override
  State<JournalEntryDialog> createState() => _JournalEntryDialogState();
}

class _JournalEntryDialogState extends State<JournalEntryDialog> {
  final AccountingRepository _repo = AccountingRepository.instance;
  final TextEditingController _refCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  final List<_DraftLine> _lines = [];

  @override
  void initState() {
    super.initState();
    _applyTemplate(widget.initialTemplate ?? 'custom');
  }

  @override
  void dispose() {
    _refCtrl.dispose();
    _descCtrl.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  String _pickAccount(String id, AccountType fallbackType) {
    if (_repo.findAccount(id) != null) return id;
    return _repo.accounts
        .firstWhere(
          (a) => a.type == fallbackType,
          orElse: () => _repo.accounts.first,
        )
        .id;
  }

  void _applyTemplate(String key) {
    for (final l in _lines) {
      l.dispose();
    }
    _lines.clear();

    switch (key) {
      case 'cash_sale':
        _descCtrl.text = 'Cash sale revenue';
        _lines.addAll([
          _DraftLine(accountId: _pickAccount('acc_1100', AccountType.asset)),
          _DraftLine(accountId: _pickAccount('acc_4000', AccountType.revenue)),
        ]);
        break;
      case 'expense':
        _descCtrl.text = 'Operating expense payment';
        _lines.addAll([
          _DraftLine(accountId: _pickAccount('acc_5400', AccountType.expense)),
          _DraftLine(accountId: _pickAccount('acc_1100', AccountType.asset)),
        ]);
        break;
      case 'owner_invest':
        _descCtrl.text = 'Owner capital contribution';
        _lines.addAll([
          _DraftLine(accountId: _pickAccount('acc_1100', AccountType.asset)),
          _DraftLine(accountId: _pickAccount('acc_3000', AccountType.equity)),
        ]);
        break;
      case 'invoice':
        _descCtrl.text = 'Customer invoice on credit';
        _lines.addAll([
          _DraftLine(accountId: _pickAccount('acc_1200', AccountType.asset)),
          _DraftLine(accountId: _pickAccount('acc_4100', AccountType.revenue)),
        ]);
        break;
      default:
        _descCtrl.clear();
        _lines.addAll([
          _DraftLine(accountId: _repo.accounts.first.id),
          _DraftLine(
            accountId: _repo.accounts.length > 1
                ? _repo.accounts[1].id
                : _repo.accounts.first.id,
          ),
        ]);
    }
    setState(() {});
  }

  double get _totalDebit => _lines.fold(0.0, (s, l) => s + l.debit);
  double get _totalCredit => _lines.fold(0.0, (s, l) => s + l.credit);
  bool get _isBalanced =>
      _totalDebit > 0 && (_totalDebit - _totalCredit).abs() < 0.005;

  Future<void> _submit() async {
    try {
      await _repo.postJournalEntry(
        date: _date,
        reference: _refCtrl.text,
        description: _descCtrl.text,
        lines: _lines
            .map(
              (l) => JournalLine(
                accountId: l.accountId,
                debit: l.debit,
                credit: l.credit,
              ),
            )
            .toList(),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(
          context,
          AppSnackBar.sanitizeError(e),
          backgroundColor: Theme.of(context).colorScheme.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final diff = (_totalDebit - _totalCredit).abs();
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Journal Entry'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: _isBalanced ? _submit : null,
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('Post Entry'),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.point_of_sale_rounded, size: 16),
                      label: const Text('Cash Sale'),
                      onPressed: () => _applyTemplate('cash_sale'),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.receipt_long_rounded, size: 16),
                      label: const Text('Pay Expense'),
                      onPressed: () => _applyTemplate('expense'),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.savings_rounded, size: 16),
                      label: const Text('Owner Capital'),
                      onPressed: () => _applyTemplate('owner_invest'),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.request_quote_rounded, size: 16),
                      label: const Text('Credit Invoice'),
                      onPressed: () => _applyTemplate('invoice'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _date,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) setState(() => _date = picked);
                        },
                        icon: const Icon(Icons.calendar_today_rounded, size: 16),
                        label: Text(
                          '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _refCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Reference (optional)',
                          hintText: 'Auto JE-###',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Description / Memo',
                    hintText: 'e.g. Monthly office utilities payment',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      'Journal Lines (Double-Entry)',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => setState(
                        () => _lines.add(
                          _DraftLine(accountId: _repo.accounts.first.id),
                        ),
                      ),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add Line'),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ..._lines.asMap().entries.map((entry) {
                  final i = entry.key;
                  final line = entry.value;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: line.accountId,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Account',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                  items: _repo.accounts
                                      .map(
                                        (a) => DropdownMenuItem(
                                          value: a.id,
                                          child: Text(
                                            '${a.code} · ${a.name} (${a.type.label})',
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() => line.accountId = val);
                                    }
                                  },
                                ),
                              ),
                              if (_lines.length > 2)
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded),
                                  onPressed: () {
                                    setState(() {
                                      final removed = _lines.removeAt(i);
                                      removed.dispose();
                                    });
                                  },
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: line.debitCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  decoration: const InputDecoration(
                                    labelText: 'Debit',
                                    prefixText: '\$ ',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                  onChanged: (v) {
                                    if (v.trim().isNotEmpty &&
                                        line.creditCtrl.text.isNotEmpty) {
                                      line.creditCtrl.clear();
                                    }
                                    setState(() {});
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: line.creditCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  decoration: const InputDecoration(
                                    labelText: 'Credit',
                                    prefixText: '\$ ',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                  onChanged: (v) {
                                    if (v.trim().isNotEmpty &&
                                        line.debitCtrl.text.isNotEmpty) {
                                      line.debitCtrl.clear();
                                    }
                                    setState(() {});
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _isBalanced
                        ? const Color(0xFF10B981).withValues(alpha: 0.12)
                        : cs.errorContainer.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _isBalanced
                          ? const Color(0xFF10B981)
                          : cs.error.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isBalanced
                            ? Icons.balance_rounded
                            : Icons.warning_amber_rounded,
                        color: _isBalanced ? const Color(0xFF059669) : cs.error,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _isBalanced
                              ? 'Balanced: Debits \$${_totalDebit.toStringAsFixed(2)} = Credits \$${_totalCredit.toStringAsFixed(2)}'
                              : 'Debits \$${_totalDebit.toStringAsFixed(2)} vs Credits \$${_totalCredit.toStringAsFixed(2)} (Diff: \$${diff.toStringAsFixed(2)})',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
