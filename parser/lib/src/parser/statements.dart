import 'package:data_classes/data_classes.dart';
import 'package:kt_dart/kt.dart';

import '../location.dart';
import '../utils.dart';

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

  String toAlignedString() => toString();
}

class LabelStatement extends Statement {
  LabelStatement({@required Location location, @required this.name})
      : assert(name != null),
        super(location: location);

  final String name;

  bool get isLocal => name.startsWith('.');
  bool get isGlobal => !isLocal;

  String toString() => name;

  @override
  operator ==(Object other) =>
      other is LabelStatement &&
      location == other.location &&
      name == other.name;
  @override
  int get hashCode => hashList([runtimeType, location, name]);
}

class CommentStatement extends Statement {
  CommentStatement({@required Location location, @required this.comment})
      : assert(comment != null),
        super(location: location);

  final String comment;

  String toString() => 'Comment: "$comment"';

  @override
  operator ==(Object other) =>
      other is CommentStatement &&
      location == other.location &&
      comment == other.comment;
  @override
  int get hashCode => hashList([runtimeType, location, comment]);
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

  String toString() => '$operation.${size.toShortString()} '
      '${operands.join(', ')}';
  String toAlignedString() =>
      '${'${operation.toString()}.${size.toShortString()}'.padRight(8)} '
      '${operands.join(', ')}';

  @override
  operator ==(Object other) =>
      other is OperationStatement &&
      location == other.location &&
      operation == other.operation &&
      size == other.size &&
      operands.deeplyEquals(other.operands);
  @override
  int get hashCode =>
      hashList([runtimeType, location, operation, size, operands]);
}

class SizeStatement extends Statement {
  SizeStatement({@required Location location, @required this.size})
      : assert(size != null),
        super(location: location);

  final Size size;

  String toString() => size.toReadableString();
  String toShortString() => size.toShortString();

  @override
  operator ==(Object other) =>
      other is SizeStatement &&
      location == other.location &&
      size == other.size;
  @override
  int get hashCode => hashList([runtimeType, location, size]);
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

  @override
  operator ==(Object other) => other is PcRegisterStatement;
  @override
  int get hashCode => hashList([runtimeType, location]);
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

  @override
  operator ==(Object other) =>
      other is AxRegisterStatement &&
      location == other.location &&
      index == other.index;
  @override
  int get hashCode => hashList([runtimeType, location, index]);
}

class DxRegisterStatement extends IndexedRegisterStatement {
  DxRegisterStatement({@required Location location, @required int index})
      : super(location: location, index: index);

  bool get isDx => true;
  String toString() => 'D$index';

  @override
  operator ==(Object other) =>
      other is DxRegisterStatement &&
      location == other.location &&
      index == other.index;
  @override
  int get hashCode => hashList([runtimeType, location, index]);
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

  String toString() => register.toString();

  @override
  operator ==(Object other) =>
      other is DxOperandStatement &&
      location == other.location &&
      register == other.register;
  @override
  int get hashCode => hashList([runtimeType, location, register]);
}

class AxOperandStatement extends OperandStatement {
  AxOperandStatement({@required Location location, @required this.register})
      : assert(register != null),
        super(location: location);

  @override
  OperandType get type => OperandType.ax;
  final AxRegisterStatement register;

  String toString() => register.toString();

  @override
  operator ==(Object other) =>
      other is AxOperandStatement &&
      location == other.location &&
      register == other.register;
  @override
  int get hashCode => hashList([runtimeType, location, register]);
}

class AxIndOperandStatement extends OperandStatement {
  AxIndOperandStatement({@required Location location, @required this.register})
      : assert(register != null),
        super(location: location);

  @override
  OperandType get type => OperandType.axInd;
  final AxRegisterStatement register;

  String toString() => register.toString();

  @override
  operator ==(Object other) =>
      other is AxIndOperandStatement &&
      location == other.location &&
      register == other.register;
  @override
  int get hashCode => hashList([runtimeType, location, register]);
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

  String toString() => '($register)+';

  @override
  operator ==(Object other) =>
      other is AxIndWithPostIncOperandStatement &&
      location == other.location &&
      register == other.register;
  @override
  int get hashCode => hashList([runtimeType, location, register]);
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

  String toString() => '-($register)';

  @override
  operator ==(Object other) =>
      other is AxIndWithPreDecOperandStatement &&
      location == other.location &&
      register == other.register;
  @override
  int get hashCode => hashList([runtimeType, location, register]);
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

  String toString() => '($displacement, $register)';

  @override
  operator ==(Object other) =>
      other is AxIndWithDisplacementOperandStatement &&
      location == other.location &&
      register == other.register;
  @override
  int get hashCode => hashList([runtimeType, location, register]);
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

  String toString() => '($displacement, $register, $index$indexSize)';

  @override
  operator ==(Object other) =>
      other is AxIndWithIndexOperandStatement &&
      location == other.location &&
      register == other.register;
  @override
  int get hashCode => hashList([runtimeType, location, register]);
}

class AbsoluteWordOperandStatement extends OperandStatement {
  AbsoluteWordOperandStatement(
      {@required Location location, @required this.value})
      : assert(value != null),
        super(location: location);

  @override
  OperandType get type => OperandType.absoluteWord;
  final int value;

  String toString() => '($value).W';

  @override
  operator ==(Object other) =>
      other is AbsoluteWordOperandStatement &&
      location == other.location &&
      value == other.value;
  @override
  int get hashCode => hashList([runtimeType, location, value]);
}

class AbsoluteLongWordOperandStatement extends OperandStatement {
  AbsoluteLongWordOperandStatement({
    @required Location location,
    @required this.value,
  })  : assert(value != null),
        super(location: location);

  @override
  OperandType get type => OperandType.absoluteLongWord;
  final int value;

  String toString() => '($value).L';

  @override
  operator ==(Object other) =>
      other is AbsoluteLongWordOperandStatement &&
      location == other.location &&
      value == other.value;
  @override
  int get hashCode => hashList([runtimeType, location, value]);
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

  String toString() => '($displacement, PC)';

  @override
  operator ==(Object other) =>
      other is PcIndWithDisplacementOperandStatement &&
      location == other.location &&
      displacement == other.displacement;
  @override
  int get hashCode => hashList([runtimeType, location, displacement]);
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

  String toString() => '($displacement, PC, $index$indexSize)';

  @override
  operator ==(Object other) =>
      other is PcIndWithIndexOperandStatement &&
      location == other.location &&
      displacement == other.displacement &&
      index == other.index &&
      indexSize == other.indexSize;
  @override
  int get hashCode =>
      hashList([runtimeType, location, displacement, index, indexSize]);
}

class ImmediateOperandStatement extends OperandStatement {
  ImmediateOperandStatement({
    @required Location location,
    @required this.value,
  })  : assert(value != null),
        super(location: location);

  @override
  OperandType get type => OperandType.immediate;
  final int value;

  String toString() => '#$value';

  @override
  operator ==(Object other) =>
      other is ImmediateOperandStatement &&
      location == other.location &&
      value == other.value;
  @override
  int get hashCode => hashList([runtimeType, location, value]);
}

class CcrOperandStatement extends OperandStatement {
  CcrOperandStatement({@required Location location})
      : super(location: location);

  @override
  OperandType get type => OperandType.ccr;
  String toString() => 'CCR';

  @override
  operator ==(Object other) =>
      other is CcrOperandStatement && location == other.location;
  @override
  int get hashCode => hashList([runtimeType, location]);
}

class SrOperandStatement extends OperandStatement {
  SrOperandStatement({@required Location location}) : super(location: location);

  @override
  OperandType get type => OperandType.sr;
  String toString() => 'SR';

  @override
  operator ==(Object other) =>
      other is SrOperandStatement && location == other.location;
  @override
  int get hashCode => hashList([runtimeType, location]);
}

class AddressOperandStatement extends OperandStatement {
  AddressOperandStatement({@required Location location})
      : super(location: location);

  @override
  OperandType get type => OperandType.address;
  String toString() => '[address operand]';

  @override
  operator ==(Object other) =>
      other is AddressOperandStatement && location == other.location;
  @override
  int get hashCode => hashList([runtimeType, location]);
}

class UspOperandStatement extends OperandStatement {
  UspOperandStatement({@required Location location})
      : super(location: location);

  @override
  OperandType get type => OperandType.usp;
  String toString() => 'USP';

  @override
  operator ==(Object other) =>
      other is UspOperandStatement && location == other.location;
  @override
  int get hashCode => hashList([runtimeType, location]);
}
