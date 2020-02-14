import 'package:data_classes/data_classes.dart';
import 'package:kt_dart/kt.dart';

import '../location.dart';

part 'operation.dart';

class Program {
  final Map<LabelStatement, int> labelsToIndex;
  final KtList<Statement> statements;

  Program({@required this.labelsToIndex, @required this.statements})
      : assert(labelsToIndex != null),
        assert(statements != null);
}

abstract class Statement {
  Statement({@required this.location}) : assert(location != null);

  final Location location;
}

class LabelStatement extends Statement {
  LabelStatement({@required Location location, @required this.name})
      : assert(name != null),
        super(location: location);

  final String name;

  bool get isLocal => name.startsWith('.');
  bool get isGlobal => !isLocal;

  String toString() => name;
}

class CommentStatement extends Statement {
  CommentStatement({@required Location location, @required this.comment})
      : assert(comment != null),
        super(location: location);

  final String comment;

  String toString() => 'Comment: "$comment"';
}

class OperationStatement extends Statement {
  final Operation operation;
  final SizeStatement size;
  final List<OperandStatement> operands;

  OperationStatement({
    @required Location location,
    @required this.operation,
    @required this.size,
    @required this.operands,
  })  : assert(operation != null),
        assert(size != null),
        assert(operands != null),
        super(location: location);

  String toString() => '$operation.$size $operands';
}

class SizeStatement extends Statement {
  SizeStatement({@required Location location, @required this.size})
      : assert(size != null),
        super(location: location);

  final Size size;

  String toString() => '$size';
}

abstract class RegisterStatement extends Statement {
  RegisterStatement({@required Location location}) : super(location: location);

  bool get isPc => false;
  bool get isAx => false;
  bool get isDx => false;
}

class PcRegisterStatement extends RegisterStatement {
  PcRegisterStatement({@required Location location})
      : super(location: location);

  bool get isPc => true;
  String toString() => 'PC';
}

abstract class IndexedRegisterStatement extends RegisterStatement {
  IndexedRegisterStatement({@required Location location, @required this.index})
      : assert(index != null),
        assert(index >= 0),
        assert(index < 8),
        super(location: location);

  final int index;

  String toString() => 'X$index';
}

class AxRegisterStatement extends IndexedRegisterStatement {
  AxRegisterStatement({@required Location location, @required int index})
      : super(location: location, index: index);

  bool get isAx => true;
  String toString() => 'A$index';
}

class DxRegisterStatement extends IndexedRegisterStatement {
  DxRegisterStatement({@required Location location, @required int index})
      : super(location: location, index: index);

  bool get isDx => true;
  String toString() => 'D$index';
}

abstract class OperandStatement extends Statement {
  OperandStatement({@required Location location}) : super(location: location);

  OperandType get type;
}

class DxOperandStatement extends OperandStatement {
  DxOperandStatement({@required Location location, @required this.register})
      : assert(register != null),
        super(location: location);

  @override
  OperandType get type => OperandType.dx;
  final DxRegisterStatement register;
}

class AxOperandStatement extends OperandStatement {
  AxOperandStatement({@required Location location, @required this.register})
      : assert(register != null),
        super(location: location);

  @override
  OperandType get type => OperandType.ax;
  final AxRegisterStatement register;
}

class AxIndOperandStatement extends OperandStatement {
  AxIndOperandStatement({@required Location location, @required this.register})
      : assert(register != null),
        super(location: location);

  @override
  OperandType get type => OperandType.axInd;
  final AxRegisterStatement register;
}

class AxIndWithPostIncOperandStatement extends OperandStatement {
  AxIndWithPostIncOperandStatement({
    @required Location location,
    @required this.register,
  })  : assert(register != null),
        super(location: location);

  @override
  OperandType get type => OperandType.axIndWithPostInc;
  final AxRegisterStatement register;
}

class AxIndWithPreDecOperandStatement extends OperandStatement {
  AxIndWithPreDecOperandStatement({
    @required Location location,
    @required this.register,
  })  : assert(register != null),
        super(location: location);

  @override
  OperandType get type => OperandType.axIndWithPreDec;
  final AxRegisterStatement register;
}

class AxIndWithDisplacementOperandStatement extends OperandStatement {
  AxIndWithDisplacementOperandStatement({
    @required Location location,
    @required this.register,
    @required this.displacement,
  })  : assert(register != null),
        assert(displacement != null),
        super(location: location);

  @override
  OperandType get type => OperandType.axIndWithDisplacement;
  final AxRegisterStatement register;
  final int displacement;
}

class AxIndWithIndexOperandStatement extends OperandStatement {
  AxIndWithIndexOperandStatement({
    @required Location location,
    @required this.register,
    @required this.displacement,
    @required this.index,
    @required this.indexSize,
  })  : assert(register != null),
        assert(displacement != null),
        assert(index != null),
        assert(indexSize != null),
        super(location: location);

  @override
  OperandType get type => OperandType.axIndWithIndex;
  final AxRegisterStatement register;
  final int displacement;
  final IndexedRegisterStatement index;
  final SizeStatement indexSize;
}

class AbsoluteWordOperandStatement extends OperandStatement {
  AbsoluteWordOperandStatement(
      {@required Location location, @required this.value})
      : assert(value != null),
        super(location: location);

  @override
  OperandType get type => OperandType.absoluteWord;
  final int value;
}

class AbsoluteLongWordOperandStatement extends OperandStatement {
  AbsoluteLongWordOperandStatement(
      {@required Location location, @required this.value})
      : assert(value != null),
        super(location: location);

  @override
  OperandType get type => OperandType.absoluteLongWord;
  final int value;
}

class PcIndWithDisplacementOperandStatement extends OperandStatement {
  PcIndWithDisplacementOperandStatement({
    @required Location location,
    @required this.displacement,
  })  : assert(displacement != null),
        super(location: location);

  @override
  OperandType get type => OperandType.pcIndWithDisplacement;
  final int displacement;
}

class PcIndWithIndexOperandStatement extends OperandStatement {
  PcIndWithIndexOperandStatement({
    @required Location location,
    @required this.displacement,
    @required this.index,
    @required this.indexSize,
  })  : assert(displacement != null),
        assert(index != null),
        assert(indexSize != null),
        super(location: location);

  @override
  OperandType get type => OperandType.pcIndWithIndex;
  final int displacement;
  final IndexedRegisterStatement index;
  final SizeStatement indexSize;
}

class ImmediateOperandStatement extends OperandStatement {
  ImmediateOperandStatement({@required Location location, @required this.value})
      : assert(value != null),
        super(location: location);

  @override
  OperandType get type => OperandType.immediate;
  final int value;
}

class CcrOperandStatement extends OperandStatement {
  CcrOperandStatement({@required Location location})
      : super(location: location);

  @override
  OperandType get type => OperandType.ccr;
}

class SrOperandStatement extends OperandStatement {
  SrOperandStatement({@required Location location}) : super(location: location);

  @override
  OperandType get type => OperandType.sr;
}

class AddressOperandStatement extends OperandStatement {
  AddressOperandStatement({@required Location location})
      : super(location: location);

  @override
  OperandType get type => OperandType.address;
}

class UspOperandStatement extends OperandStatement {
  UspOperandStatement({@required Location location})
      : super(location: location);

  @override
  OperandType get type => OperandType.usp;
}
