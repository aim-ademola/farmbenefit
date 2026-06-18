import 'package:flint_ui/flint_ui.dart';

import '../components/site_layout.dart';

class HomePage extends FlintComponent {
  @override
  FlintNode build() => SiteLayout(activeComponent: 'Home');
}
