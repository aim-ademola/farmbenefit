import 'package:flint_ui/flint_ui.dart';

import 'registry.dart';
import 'styles/theme.dart';

void main() {
  createFlintApp(
    '#app',
    registry: farmsBenefitRegistry,
    rootDesign: farmsBenefitRootDesign,
  );
}
