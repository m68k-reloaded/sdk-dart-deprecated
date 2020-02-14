import 'package:data_classes/data_classes.dart';
import 'package:meta/meta.dart';

@immutable
class Location {
  final int line;
  final int col;

  const Location({@required this.line, @required this.col})
      : assert(line != null),
        assert(col != null);

  const Location.invalid() : this(line: -1, col: -1);
  bool get isInvalid => line < 0 || col < 0;

  @override
  String toString() => '$line:$col';

  bool operator ==(Object other) =>
      other is Location && line == other.line && col == other.col;
  int get hashCode => hashList([line, col]);
}
