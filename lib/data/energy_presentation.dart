/// UI receipts never authorize spending or replace the server wallet.
class EnergyPresentationCredit {
  EnergyPresentationCredit(
    this.id,
    this.owner,
    this.amount, {
    this.animate = true,
  });
  final String id, owner;
  final int amount;
  final bool animate;
  bool pending = true, rejected = false;
  bool scheduled = false;
  int? acceptedAmount;
}

/// Holds an unambiguous visual baseline while named receipts are in flight.
/// Generic profile snapshots can already include a lost ACK, so their positive
/// deltas must never be guessed to be a particular receipt.
class EnergyPresentation {
  String? _owner;
  int _wallet = 0;
  int? _anchor;
  final _credits = <String, EnergyPresentationCredit>{};
  final _anchored = <String>{};
  final _debits = <String>{};
  int correctionSerial = 0;
  Iterable<EnergyPresentationCredit> get credits => _credits.values;
  bool get pending => _credits.values.any((c) => c.pending);
  int get balance =>
      (_anchor == null
              ? _wallet
              : _anchor! +
                    _anchored.fold<int>(
                      0,
                      (sum, id) =>
                          sum +
                          (_credits[id]!.rejected
                              ? 0
                              : (_credits[id]!.acceptedAmount ??
                                    _credits[id]!.amount)),
                    ))
          .clamp(0, 1000000000);

  void wallet(String? owner, int balance) {
    if (_owner != owner) {
      _credits.clear();
      _anchored.clear();
      _debits.clear();
      _anchor = null;
      _owner = owner;
    }
    _wallet = balance;
  }

  bool begin(String id, int amount, {bool animate = true}) {
    final owner = _owner;
    if (owner == null || amount < 0 || _credits.containsKey(id)) return false;
    if (animate && amount > 0) _anchor ??= _wallet;
    _credits[id] = EnergyPresentationCredit(
      id,
      owner,
      amount,
      animate: animate,
    );
    if (animate && amount > 0) _anchored.add(id);
    return true;
  }

  void debit(String id, int amount) {
    if (_anchor != null && _debits.add(id)) _anchor = _anchor! - amount;
  }

  void settle(String id, {bool rejected = false, int? amount}) {
    final credit = _credits[id];
    if (credit == null || !credit.pending) return;
    credit.pending = false;
    credit.rejected = rejected;
    if (amount != null && amount >= 0) credit.acceptedAmount = amount;
    if (credit.animate &&
        (rejected || amount != null && amount != credit.amount)) {
      correctionSerial++;
    }
    if (!pending) {
      _anchor = null;
      _anchored.clear();
      _debits.clear();
    }
  }
}
