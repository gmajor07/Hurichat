import 'package:flutter/widgets.dart';

import 'app_features.dart';

/// Guard registered routes before constructing disabled module screens.
Map<String, WidgetBuilder> guardFeatureRoutes(
  Map<String, WidgetBuilder> routes, {
  required WidgetBuilder fallback,
}) => routes.map(
  (name, builder) => MapEntry(
    name,
    (context) =>
        AppFeatures.canOpenRoute(name) ? builder(context) : fallback(context),
  ),
);
