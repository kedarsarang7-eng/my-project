// @dart=3.6
// ignore_for_file: directives_ordering
// build_runner >=2.4.16
// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:build_runner/src/build_plan/builder_factories.dart' as _i1;
import 'package:mockito/src/builder.dart' as _i2;
import 'package:riverpod_generator/builder.dart' as _i3;
import 'package:source_gen/builder.dart' as _i4;
import 'dart:io' as _i5;
import 'package:build_runner/src/bootstrap/processes.dart' as _i6;

final _builderFactories = _i1.BuilderFactories(
  {
    'mockito:mockBuilder': [_i2.buildMocks],
    'riverpod_generator:riverpod_generator': [_i3.riverpodBuilder],
    'source_gen:combining_builder': [_i4.combiningBuilder],
  },
  postProcessBuilderFactories: {'source_gen:part_cleanup': _i4.partCleanup},
);
void main(List<String> args) async {
  _i5.exitCode = await _i6.ChildProcess.run(
    args,
    _builderFactories,
  )!;
}
