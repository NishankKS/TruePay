import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../scenarios.dart';
import '../widgets/theme.dart';
import 'approver.dart';

const masterIban = 'DE89370400440532013000';

String actOf(String? scenario, Map<String, dynamic> layers) => switch (scenario) {
      'baseline' => '0',
      'clean' => '1',
      'poisoned' => (layers['jailbreak_controller'] == true || layers['quarantine'] == false) ? '5' : '2',
      'swap' => '3',
      'insider' => '4',
      'judge' => 'judge',
      _ => 'idle',
    };

const banners = {
  'idle': ('Ready', 'Press a scenario to start.'),
  '0': ('Act 0: today, without IBAN-Wächter',
      "Simulation of today's process. IBAN-Wächter is not involved and none of its data is touched."),
  '1': ('Act 1: a clean invoice', 'Müller Bürobedarf, €4,280. Every check should pass.'),
  '2': ('Act 2: a poisoned invoice', 'Hidden instructions for the AI, invisible to people.'),
  '3': ('Act 3: the same invoice, now with IBAN-Wächter', 'The IBAN swap from Act 0 meets the crew.'),
  '4': ('Act 4: a compromised insider component', "An attacker controls the onboarding component's code."),
  '5': ('Act 5: AI defenses off, controller jailbroken', 'Assume breach: only the firewall and the human remain.'),
  'judge': ('Judge mode', 'Your text, printed on a clean invoice.'),
};

class MissionControl extends StatefulWidget {
  const MissionControl({super.key});
  @override
  State<MissionControl> createState() => _MissionControlState();
}

class _MissionControlState extends State<MissionControl> {
  StreamSubscription? _statsSub;
  Map<String, dynamic>? _prev;

  @override
  void initState() {
    super.initState();
    _statsSub = docStream('stats/demo').listen((s) async {
      final p = _prev;
      _prev = s;
      if (p == null || !mounted) return;
      final dBlocked = (s['blocked_cents'] ?? 0) - (p['blocked_cents'] ?? 0);
      final dLost = (s['lost_cents'] ?? 0) - (p['lost_cents'] ?? 0);
      if (dBlocked > 0) {
        final rt = (await db.doc('config/runtime').get()).data() ?? {};
        final inv = await db.collection('invoices').where('run_id', isEqualTo: rt['current_run_id']).limit(1).get();
        final reason = inv.docs.isEmpty ? 'policy' : (inv.docs.first.data()['hold_reason'] ?? 'policy');
        _toast('Stopped ${euro(dBlocked)}: $reason', cPass);
      }
      if (dLost > 0) _toast('Lost ${euro(dLost)}: transfer confirmed with a TAN', cBlock);
    });
  }

  void _toast(String msg, Color c) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: sans(c: Colors.white, w: FontWeight.w600)),
      backgroundColor: c,
      duration: const Duration(milliseconds: 2500),
    ));
  }

  @override
  void dispose() {
    _statsSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: StreamBuilder<Map<String, dynamic>>(
          stream: docStream('config/runtime'),
          builder: (context, rtSnap) => StreamBuilder<Map<String, dynamic>>(
            stream: docStream('config/layers'),
            builder: (context, lSnap) {
              final rt = rtSnap.data ?? {};
              final layers = {...defaultLayers, ...?lSnap.data};
              final runId = (rt['current_run_id'] ?? 'run-0000') as String;
              final act = actOf(rt['current_scenario'] as String?, layers);
              return SingleChildScrollView(
                child: SizedBox(
                  width: 1280,
                  child: Column(children: [
                    const Header(),
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      LeftRail(layers: layers),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(children: [
                            Pipeline(runId: runId, act: act),
                            const SizedBox(height: 12),
                            Evidence(runId: runId, act: act),
                          ]),
                        ),
                      ),
                      LayerRail(runId: runId, act: act, layers: layers),
                    ]),
                    const AuditBar(),
                  ]),
                ),
              );
            },
          ),
        ),
      );
}

// ---------------------------------------------------------------- header
class Header extends StatelessWidget {
  const Header({super.key});
  Widget _kpi(String label, num? v, Color c, {bool money = true}) => Padding(
        padding: const EdgeInsets.only(left: 28),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisAlignment: MainAxisAlignment.center, children: [
          TweenAnimationBuilder<double>(
            tween: Tween(end: (v ?? 0).toDouble()),
            duration: const Duration(milliseconds: 800),
            builder: (_, x, __) => Text(money ? euro(x) : x.round().toString(), style: kpi(c).copyWith(height: 1)),
          ),
          Text(label, style: sans(size: 12.5, c: cMuted)),
        ]),
      );

  @override
  Widget build(BuildContext context) => Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: const BoxDecoration(color: cSurface, border: Border(bottom: BorderSide(color: cLine))),
        child: Row(children: [
          const Icon(Icons.shield_outlined, color: cInk, size: 30),
          const SizedBox(width: 10),
          Text('IBAN-Wächter', style: sans(size: 20, w: FontWeight.w600)),
          const SizedBox(width: 14),
          Text('Agents decide. Code enforces. Humans approve.', style: sans(c: cMuted)),
          const Spacer(),
          StreamBuilder<Map<String, dynamic>>(
            stream: docStream('stats/demo'),
            builder: (_, s) {
              final d = s.data ?? {};
              return Row(children: [
                _kpi('Lost without IBAN-Wächter', d['lost_cents'], cBlock),
                _kpi('Blocked by IBAN-Wächter', d['blocked_cents'], cPass),
                _kpi('Paid', d['paid_cents'], cInk),
                _kpi('Denied actions', d['denied_actions'], cInk, money: false),
              ]);
            },
          ),
        ]),
      );
}

// ---------------------------------------------------------------- left rail
class LeftRail extends StatefulWidget {
  final Map<String, dynamic> layers;
  const LeftRail({super.key, required this.layers});
  @override
  State<LeftRail> createState() => _LeftRailState();
}

class _LeftRailState extends State<LeftRail> {
  final note = TextEditingController();

  Future<void> run(String scenario, {String? text}) => db.collection('commands').add({
        'scenario': scenario,
        'status': 'NEW',
        'created_at': FieldValue.serverTimestamp(),
        if (text != null) 'note': text.length > 500 ? text.substring(0, 500) : text,
      });

  Widget _switch(String key, String label, {bool hold = false}) {
    final on = widget.layers[key] == true;
    return SwitchListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: sans(size: 13.5)),
      value: on,
      activeThumbColor: hold ? cHold : cActive,
      onChanged: (v) => db.doc('config/layers').update({key: v}),
    );
  }

  Widget _locked(String label) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          const Icon(Icons.lock_outline, size: 16, color: cMuted),
          const SizedBox(width: 8),
          Text(label, style: sans(size: 13.5, c: cMuted)),
        ]),
      );

  @override
  Widget build(BuildContext context) => Container(
        width: 280,
        padding: const EdgeInsets.all(12),
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: db.collection('commands').where('status', whereIn: ['NEW', 'RUNNING']).limit(1).snapshots(),
          builder: (context, cs) {
            final busy = (cs.data?.docs.isNotEmpty ?? false);
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Scenarios', style: sans(size: 15, w: FontWeight.w600)),
              const SizedBox(height: 8),
              for (final s in scenarioButtons)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SizedBox(
                    height: 56,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: s.act == '0' ? cIdleTint : cSurface,
                        side: BorderSide(color: s.act == '0' ? cIdle : cLine, width: s.act == '0' ? 1.5 : 1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      onPressed: busy ? null : () => run(s.key),
                      child: Row(children: [
                        Text(s.button, style: mono(size: 20, w: FontWeight.w600, c: s.act == '0' ? cIdle : cActive)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(s.title, style: sans(w: FontWeight.w600), overflow: TextOverflow.ellipsis),
                            Text(s.subtitle, style: sans(size: 12.5, c: cMuted), overflow: TextOverflow.ellipsis),
                          ]),
                        ),
                      ]),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Text('Judge mode', style: sans(size: 15, w: FontWeight.w600)),
              const SizedBox(height: 6),
              TextField(
                controller: note,
                maxLines: 3,
                maxLength: 500,
                style: sans(size: 13),
                decoration: const InputDecoration(
                    border: OutlineInputBorder(), isDense: true, hintText: 'Type an attack to print on the invoice'),
              ),
              FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: cActive, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  onPressed: busy ? null : () => run('judge', text: note.text),
                  child: const Text('Run attack')),
              const SizedBox(height: 14),
              Text('Breach simulation', style: sans(size: 15, w: FontWeight.w600)),
              _switch('hidden_text', 'L1 Hidden-text scan'),
              _switch('model_armor', 'L2 Model Armor'),
              _switch('quarantine', 'L3 Gemma quarantine'),
              _switch('jailbreak_controller', 'Jailbreak controller', hold: true),
              _locked('Action Firewall, always on'),
              _locked('Human approval, always on'),
            ]);
          },
        ),
      );
}

// ---------------------------------------------------------------- pipeline
const nodeOf = {
  'intake': 'intake', 'sentinel': 'intake', 'model_armor': 'intake', 'baseline': 'intake',
  'controller': 'controller', 'onboarding': 'controller', 'investigator': 'investigator',
  'vendor_agent': 'vendor', 'firewall': 'firewall', 'human': 'human', 'bank': 'bank',
};
const nodes = ['intake', 'controller', 'investigator', 'vendor', 'firewall', 'human', 'bank'];

Stream<List<Map<String, dynamic>>> runEvents(String runId) => db
    .collection('events')
    .where('run_id', isEqualTo: runId)
    .orderBy('ts')
    .snapshots()
    .map((q) => q.docs.map((d) => d.data()).toList());

class Pipeline extends StatelessWidget {
  final String runId, act;
  const Pipeline({super.key, required this.runId, required this.act});

  String label(String n) => switch (n) {
        'intake' => act == '0' ? 'Invoice automation' : 'Intake',
        'controller' => act == '4' ? 'Onboarding' : 'Controller',
        'investigator' => 'Investigator',
        'vendor' => 'Müller agent',
        'firewall' => 'Firewall',
        'human' => 'Human',
        _ => 'Bank',
      };

  @override
  Widget build(BuildContext context) {
    final b = banners[act]!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: card(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(b.$1, style: sans(size: 15, w: FontWeight.w600)),
        Text(b.$2, style: sans(c: cMuted)),
        const SizedBox(height: 14),
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: runEvents(runId),
          builder: (_, s) {
            final latest = <String, Map<String, dynamic>>{};
            for (final e in s.data ?? const []) {
              final n = nodeOf[e['actor']];
              if (n != null) latest[n] = e;
            }
            final children = <Widget>[];
            for (final n in nodes) {
              if (children.isNotEmpty) children.add(const Icon(Icons.arrow_forward, size: 16, color: cMuted));
              final notInstalled = act == '0' && !['intake', 'human', 'bank'].contains(n);
              children.add(Expanded(child: _Node(label(n), notInstalled ? null : latest[n], notInstalled, dashed: n == 'vendor')));
            }
            return Row(children: children);
          },
        ),
      ]),
    );
  }
}

class _Node extends StatelessWidget {
  final String label;
  final Map<String, dynamic>? ev;
  final bool notInstalled, dashed;
  const _Node(this.label, this.ev, this.notInstalled, {this.dashed = false});
  @override
  Widget build(BuildContext context) {
    final v = ev?['verdict'] as String?;
    final c = notInstalled ? cIdle : verdictColor(v);
    final icon = switch (v) {
      'PASS' || 'ALLOW' => Icons.check_circle,
      'BLOCK' || 'DENY' => Icons.cancel,
      'INFO' => Icons.radio_button_checked,
      _ => Icons.radio_button_unchecked,
    };
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 92,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: notInstalled || v == null ? cIdleTint : (v == 'INFO' ? const Color(0xFFEAF0FD) : verdictTint(v)),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: v == null || notInstalled ? cLine : c, width: dashed ? 1 : 1.5),
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: c, size: 20),
        FittedBox(fit: BoxFit.scaleDown, child: Text(label, maxLines: 1, style: sans(size: 13, w: FontWeight.w600))),
        if (dashed) Text('A2A', style: mono(size: 11, c: cMuted)),
        Text(notInstalled ? 'Not installed' : (ev?['title'] ?? 'Idle'),
            maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(size: 11.5, c: cMuted)),
      ]),
    );
  }
}

// ---------------------------------------------------------------- evidence
class Evidence extends StatelessWidget {
  final String runId, act;
  const Evidence({super.key, required this.runId, required this.act});

  @override
  Widget build(BuildContext context) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: db.collection('invoices').where('run_id', isEqualTo: runId).limit(1).snapshots(),
        builder: (_, s) {
          final inv = (s.data?.docs.isNotEmpty ?? false) ? s.data!.docs.first.data() : <String, dynamic>{};
          final fixture = (inv['fixture'] as String?) ??
              (act == '0' ? 'INV-1003' : null);
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: _Paper(fixture: fixture, inv: inv, act: act, runId: runId)),
            const SizedBox(width: 12),
            Expanded(child: _RightCard(inv: inv, act: act)),
          ]);
        },
      );
}

class _Paper extends StatelessWidget {
  final String? fixture;
  final Map<String, dynamic> inv;
  final String act, runId;
  const _Paper({required this.fixture, required this.inv, required this.act, required this.runId});
  @override
  Widget build(BuildContext context) {
    final spans = (inv['hidden_spans'] as List?) ?? const [];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: card(),
      child: fixture == null
          ? SizedBox(height: 200, child: Center(child: Text(act == '4' ? 'No invoice: an insider component acts directly' : 'No invoice yet', style: sans(c: cMuted))))
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: db.collection('baseline_transfers').limit(1).snapshots(),
                builder: (_, bt) {
                  final lost = act == '0' && (bt.data?.docs.isNotEmpty ?? false);
                  final blocked = inv['status'] == 'HOLD';
                  return Stack(alignment: Alignment.center, children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        decoration: BoxDecoration(border: Border.all(color: cLine), borderRadius: BorderRadius.circular(6)),
                        child: Image.asset('assets/invoices/$fixture.png', height: 420, fit: BoxFit.contain),
                      ),
                    ),
                    if (blocked || lost) Stamp(lost ? 'LOST' : 'BLOCKED'),
                  ]);
                },
              ),
              if (spans.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: card(color: cBlockTint, border: cBlock, r: 10),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Hidden text revealed', style: sans(w: FontWeight.w600, c: cBlock)),
                    for (final sp in spans) Text('${sp['text']}', style: mono(size: 12.5, c: cBlock)),
                  ]),
                ),
              ],
            ]),
    );
  }
}

class _RightCard extends StatelessWidget {
  final Map<String, dynamic> inv;
  final String act;
  const _RightCard({required this.inv, required this.act});

  Widget row(String k, Widget v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 130, child: Text(k, style: sans(c: cMuted))),
          Expanded(child: v),
        ]),
      );

  @override
  Widget build(BuildContext context) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: db.collection('approvals').where('status', isEqualTo: 'PENDING').limit(1).snapshots(),
        builder: (_, ap) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: db.collection('baseline_confirmations').where('status', isEqualTo: 'PENDING').limit(1).snapshots(),
          builder: (_, bc) {
            final pendingAp = ap.data?.docs.isNotEmpty ?? false;
            final pendingBc = bc.data?.docs.isNotEmpty ?? false;
            if (pendingAp || pendingBc) {
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: card(),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text("On the CFO's phone", style: sans(size: 15, w: FontWeight.w600)),
                  const SizedBox(height: 10),
                  pendingAp
                      ? ApprovalCard(doc: ap.data!.docs.first, readOnly: true)
                      : BankCard(doc: bc.data!.docs.first, readOnly: true),
                ]),
              );
            }
            if (act == '0') {
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: card(),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('What the automation saw', style: sans(size: 15, w: FontWeight.w600)),
                  const SizedBox(height: 8),
                  row('IBAN', Text('DE39 9999 9999 0012 3456 78', style: mono())),
                  row('Amount', Text('€18,950.00', style: sans(w: FontWeight.w600))),
                  const SizedBox(height: 6),
                  Text('No checks ran', style: sans(w: FontWeight.w600, c: cBlock)),
                ]),
              );
            }
            if (inv.isEmpty) {
              return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: card(),
                  child: Text('What the agents see: nothing yet', style: sans(c: cMuted)));
            }
            final iban = (inv['iban'] ?? '') as String;
            final isMaster = iban == masterIban;
            final status = (inv['status'] ?? '') as String;
            final withheld = ((inv['suspicious_instructions'] as List?)?.length ?? 0);
            final hidden = ((inv['hidden_spans'] as List?)?.length ?? 0);
            final n = withheld > 0 ? withheld : hidden;
            final (fg, bg) = switch (status) {
              'HOLD' || 'QUARANTINED' || 'FLAGGED' || 'REJECTED' => (cBlock, cBlockTint),
              'PAID' || 'VERIFIED' || 'SCREENED' => (cPass, cPassTint),
              'PENDING_APPROVAL' => (cHold, cHoldTint),
              _ => (cIdle, cIdleTint),
            };
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: card(),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('What the agents see', style: sans(size: 15, w: FontWeight.w600)),
                const SizedBox(height: 8),
                row('Vendor', Text('${inv['vendor_name'] ?? '—'}', style: sans())),
                row('Invoice / order', Text('${inv['invoice_no'] ?? '—'} · ${inv['po_number'] ?? '—'}', style: mono())),
                row('Amount', Text(euro(inv['amount_cents']), style: sans(w: FontWeight.w600))),
                row(
                    'IBAN',
                    Wrap(spacing: 8, children: [
                      Text(maskIban(iban), style: mono()),
                      Text(isMaster ? '= master' : '≠ master …3000',
                          style: mono(w: FontWeight.w600, c: isMaster ? cPass : cBlock)),
                    ])),
                row('Status', Align(alignment: Alignment.centerLeft, child: chip(status, fg, bg))),
                const SizedBox(height: 6),
                Text('${inv['notice'] ?? ''}', style: sans(size: 12.5, c: cIdle)),
                if (n > 0) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: card(color: cBlockTint, border: cBlock, r: 10),
                    child: Text('Withheld from agents: $n hidden instruction${n > 1 ? 's' : ''} (operator only)',
                        style: sans(size: 13, c: cBlock, w: FontWeight.w600)),
                  ),
                ],
              ]),
            );
          },
        ),
      );
}

// ---------------------------------------------------------------- right rail: defense layers
const layerNames = {
  'L1': 'Hidden-text scan', 'L2': 'Model Armor', 'L3': 'Gemma quarantine',
  'L4': 'Vendor callback (A2A)', 'L5': 'Action Firewall', 'L6': 'Human approval',
};
const layerSwitch = {'L1': 'hidden_text', 'L2': 'model_armor', 'L3': 'quarantine'};

class LayerRail extends StatelessWidget {
  final String runId, act;
  final Map<String, dynamic> layers;
  const LayerRail({super.key, required this.runId, required this.act, required this.layers});

  @override
  Widget build(BuildContext context) => Container(
        width: 320,
        padding: const EdgeInsets.all(12),
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: runEvents(runId),
          builder: (_, s) {
            final latest = <String, Map<String, dynamic>>{};
            for (final e in s.data ?? const []) {
              if (e['layer'] != null) latest[e['layer'] as String] = e;
            }
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Defense layers', style: sans(size: 15, w: FontWeight.w600)),
              const SizedBox(height: 8),
              for (final l in layerNames.keys) _layerRow(l, latest[l]),
            ]);
          },
        ),
      );

  Widget _layerRow(String l, Map<String, dynamic>? ev) {
    final v = ev?['verdict'] as String?;
    final locked = l == 'L5' || l == 'L6';
    final disabled = layerSwitch.containsKey(l) && layers[layerSwitch[l]] == false && act != '0';
    final (state, c) = act == '0'
        ? ('NOT INSTALLED', cIdle)
        : disabled
            ? ('DISABLED', cIdle)
            : switch (v) {
                'BLOCK' || 'DENY' => ('BLOCKED', cBlock),
                'PASS' || 'ALLOW' => ('CLEAR', cPass),
                _ => ('STANDBY', cIdle),
              };
    final row = Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: card(color: state == 'BLOCKED' ? cBlockTint : cSurface, border: state == 'BLOCKED' ? cBlock : cLine, r: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(l, style: mono(w: FontWeight.w600)),
          const SizedBox(width: 8),
          Expanded(child: Text(layerNames[l]!, style: sans(w: FontWeight.w600))),
          if (locked) const Icon(Icons.lock_outline, size: 14, color: cMuted),
          const SizedBox(width: 4),
          chip(state, c, c == cIdle ? cIdleTint : (c == cBlock ? Colors.white : cPassTint)),
        ]),
        if (locked) Text('Always on', style: sans(size: 12.5, c: cMuted)),
        if (ev != null && act != '0' && !disabled)
          Text('${ev['detail'] ?? ''}', maxLines: 2, overflow: TextOverflow.ellipsis, style: sans(size: 12.5, c: cMuted)),
      ]),
    );
    if (state != 'BLOCKED') return row;
    return TweenAnimationBuilder<double>(
      key: ValueKey('${l}_${ev?['title']}'),
      tween: Tween(begin: 1, end: 0),
      duration: const Duration(milliseconds: 600),
      builder: (_, x, child) => Container(
        decoration: BoxDecoration(color: cBlock.withValues(alpha: 0.35 * x), borderRadius: BorderRadius.circular(10)),
        child: child,
      ),
      child: row,
    );
  }
}

// ---------------------------------------------------------------- bottom bar: audit trail
class AuditBar extends StatelessWidget {
  const AuditBar({super.key});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.all(12),
        decoration: card(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Text('Audit trail', style: sans(size: 15, w: FontWeight.w600)),
            const Spacer(),
            TextButton(onPressed: () => Navigator.pushNamed(context, '/report'), child: const Text('Open audit report')),
          ]),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: db.collection('events').orderBy('ts', descending: true).limit(8).snapshots(),
            builder: (_, s) => Column(children: [
              for (final d in s.data?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                _eventRow(d.data()),
            ]),
          ),
        ]),
      );

  Widget _eventRow(Map<String, dynamic> e) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          SizedBox(width: 80, child: Text(hms(e['ts']), style: mono(size: 12.5, c: cMuted))),
          SizedBox(width: 110, child: Text('${e['actor']}', style: sans(size: 13))),
          SizedBox(width: 40, child: Text('${e['layer'] ?? ''}', style: mono(size: 12.5, c: cMuted))),
          SizedBox(width: 70, child: Align(alignment: Alignment.centerLeft, child: chip('${e['verdict']}', verdictColor(e['verdict']), verdictTint(e['verdict'])))),
          Expanded(
              child: Text('${e['title']}${(e['codes'] as List?)?.isNotEmpty == true ? '  ${(e['codes'] as List).join(' ')}' : ''}',
                  overflow: TextOverflow.ellipsis, style: sans(size: 13))),
        ]),
      );
}
