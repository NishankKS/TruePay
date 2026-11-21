// Mirrors SCENARIOS in backend/common/config.py (PRD §3). Keys are a frozen contract.

class Scenario {
  final String act; // '0'..'5' or 'judge'
  final String key; // command `scenario` value
  final String? fixture;
  final String button;
  final String title;
  final String subtitle;
  final String switches; // 'ignored' | 'defaults' | 'L1-L3 off, jailbreak on' | 'as set'
  const Scenario(this.act, this.key, this.fixture, this.button, this.title, this.subtitle, this.switches);
}

const scenarios = <Scenario>[
  Scenario('0', 'baseline', 'INV-1003', '0', 'Today, without IBAN-Wächter', 'Same IBAN swap, paid with a TAN', 'ignored'),
  Scenario('1', 'clean', 'INV-1001', '1', 'Clean invoice', 'Müller, €4,280', 'defaults'),
  Scenario('2', 'poisoned', 'INV-1002', '2', 'Poisoned invoice', 'Hidden instructions', 'defaults'),
  Scenario('3', 'swap', 'INV-1003', '3', 'Silent IBAN swap', 'Checked by IBAN-Wächter', 'defaults'),
  Scenario('4', 'insider', null, '4', 'Insider component', 'Compromised onboarding', 'ignored'),
  Scenario('5', 'poisoned', 'INV-1002', '2', 'Breach simulation', 'Defenses off, controller jailbroken', 'L1-L3 off, jailbreak on'),
  Scenario('judge', 'judge', 'INV-1099', 'Run attack', 'Judge mode', 'Your text on a clean invoice', 'as set'),
];

/// The five scenario buttons in the left rail (Act 5 reuses button 2 with switches).
final scenarioButtons = scenarios.where((s) => ['0', '1', '2', '3', '4'].contains(s.act)).toList();

const defaultLayers = {'hidden_text': true, 'model_armor': true, 'quarantine': true, 'jailbreak_controller': false};
