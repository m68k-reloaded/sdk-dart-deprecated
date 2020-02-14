import 'dart:typed_data';

import 'package:kt_dart/kt.dart';
import 'package:m68k_reloaded_parser/parser.dart';

import 'bits.dart';
import 'compiler.dart';
import 'statement_extensions.dart';

final KtMap<Operation, StatementCompiler> logicalCompilers = KtMap.from({
  Operation.not: _compileNot,
});

final _notBits = [0, 1, 0, 0, 0, 1, 1, 0].bits;
Uint8List _compileNot(OperationStatement statement) {
  assert(statement.operation == Operation.not);
  assert(statement.operands.length == 1);
  final operand = statement.operands.first;

  final sizeBits = statement.compiledSizeZeroBased;
  final addressModeBits = operand.compiledMode;
  final addressRegisterBits = operand.compiledRegister;

  final bits = _notBits + sizeBits + addressModeBits + addressRegisterBits;
  bits.assertWordLength();
  return bits.asUint8List;
}
