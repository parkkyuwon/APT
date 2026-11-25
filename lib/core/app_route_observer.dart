import 'package:flutter/widgets.dart';

/// Includes dialogs, so a covered home never executes a pending tag silently.
final appRouteObserver = RouteObserver<ModalRoute<dynamic>>();
