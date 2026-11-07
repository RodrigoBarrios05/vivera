import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/errors.dart';
import 'app_error_view.dart';
import 'app_loading.dart';

class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({
    super.key,
    required this.value,
    required this.builder,
    this.onRetry,
    this.loading,
    this.compactError = false,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final VoidCallback? onRetry;
  final Widget? loading;
  final bool compactError;

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: builder,
      loading: () => loading ?? const AppLoading(),
      error: (error, stackTrace) => AppErrorView(
        message: readableError(error),
        onRetry: onRetry,
        compact: compactError,
      ),
    );
  }
}
