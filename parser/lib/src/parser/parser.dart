import 'dart:core';

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import '../error.dart';
import '../scanner/scanner.dart';
import 'statements.dart';

export 'statements.dart';

class ParserException implements Exception {
  ParserException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract class Parser {
  Parser._();

  static Program parse({
    @required List<Token> tokens,
    @required ErrorCollector errorCollector,
  }) {
    assert(tokens != null);
    assert(errorCollector != null);

    final labels = <LabelStatement, int>{};
    final statements = <Statement>[];

    final tokensByLine = groupBy<Token, int>(
      tokens,
      (Token token) => token.location.line,
    );

    final labelsWaitingForCode = <LabelStatement>{};

    tokensByLine.forEach((line, tokens) {
      // Global label line.
      if (tokens.first.isIdentifier && tokens[1].isColon) {
        labelsWaitingForCode.add(LabelStatement(
          location: tokens.first.location,
          name: tokens.first.literal,
        ));
        tokens.removeRange(0, 2);
      }

      // Local label line.
      if (tokens.first.isDot && tokens[1].isIdentifier && tokens[2].isColon) {
        labelsWaitingForCode.add(LabelStatement(
          location: tokens.first.location,
          name: '.${tokens[1].literal}',
        ));
        tokens.removeRange(0, 3);
      }

      // Comment at the end of the line.
      Token comment;
      if (tokens.last.isComment) {
        comment = tokens.last;
        tokens.removeLast();
      }

      if (tokens.isEmpty) {
        if (comment != null) {
          statements.add(CommentStatement(
            location: comment.location,
            comment: comment.literal,
          ));
        }
      }

      // This is an operation or a directive. Let the labels point to the next
      // statement, which will be inserted at the end of the list.
      labels.addAll({
        for (final label in labelsWaitingForCode) label: statements.length,
      });
      final state = _LineParserState(tokens, errorCollector, line);
      state.tryOrRegisterError(() {
        statements.add(parseOperationOrDirective(state));
      });
    });

    // Once we parsed the file, there should be no labels waiting for code.
    for (final label in labelsWaitingForCode) {
      errorCollector.add(Error(
        location: label.location,
        message: "There should be code after labels, but label $label isn't "
            "followed by any statements.",
      ));
    }

    return Program(labelsToIndex: labels, statements: statements);
  }

  static void parseLine(_LineParserState state) {
    // A line can contain some labels as well as an operation or directive.
    final labels = <LabelStatement>{};
    Statement operationOrDirective;

    // Parse labels.
    while (state.peek2().isColon || state.peek3().isColon) {
      state.tryOrRegisterError(() {
        labels.add(parseLabel(state));
      });
    }

    if (state.peek()?.isIdentifier ?? false) {
      parseOperationOrDirective(state);
    }
  }

  static LabelStatement parseLabel(_LineParserState state) {
    final numberOfDots = state.advanceWhile((token) => token.isDot).length;
    if (numberOfDots >= 2) {
      state
        ..advanceWhile((token) => !token.isColon)
        ..advance();
      throw ParserException(
          'A line started with $numberOfDots dots.\nIf you tried to create a '
          'local label, consider using only one dot.');
    }

    final identifier =
        state.expect(TokenType.identifier, expected: "a label identifier");
    assert(state.advance().isColon);

    return LabelStatement(
      location: identifier.location,
      name: identifier.literal,
    );
  }

  static Statement parseOperationOrDirective(_LineParserState state) {
    final identifier = state.expect(TokenType.identifier,
        expected: "an operation or directive identifier");

    SizeStatement size;
    if (state.peek().isDot) {
      state.advance();
      state.tryOrRegisterError(() {
        size = parseSize(state);
      });
    }

    final operands = <OperandStatement>[];
    while (state.peek()?.isComment == false) {
      state.tryOrRegisterError(() {
        operands.add(parseOperand(state));
      });
    }

    // Now, we got the [identifier] of the operation as well as its [size] and
    // [operands]. It's time to see if there actually exists an operation or
    // directive which matches that signature!

    var operation = Operation.values.firstOrNull(
      (operation) => operation.code == identifier.literal,
    );

    if (operation != null) {
      state.tryOrRegisterError(() {
        ensureMatchingOperationConfigurationExists(
          operation,
          size.size,
          operands,
        );
      });

      return OperationStatement(
        location: identifier.location,
        operation: operation,
        size: size,
        operands: operands,
      );
    }

    // No matching operation was found. Maybe this is a directive?

    //return DirectiveStatement();
    return null;
  }

  static SizeStatement parseSize(_LineParserState state) {
    final token = state.expect(TokenType.identifier,
        expected: "a size (either B for byte, W for word or L for long word)");
    final name = token.literal.toString().toUpperCase();

    final size = {
      'B': Size.byte,
      'W': Size.word,
      'L': Size.longWord,
    }[name];
    if (size == null) {
      throw ParserException(
          "A size was expected. That's either B for byte, W for word or L for "
          "long word. But $name was given. That's not a valid size.");
    }
    return SizeStatement(location: token.location, size: size);
  }

  static OperandStatement parseOperand(_LineParserState state) {
    Token expect(TokenType type, {OperandType operandType, String expected}) {
      final expectedMessage = StringBuffer(expected);
      if (operandType != null) {
        expectedMessage.write(' for an ${operandTypeToStringShort(operandType)}'
            'operand (\'${operandTypeToString(operandType)}\')');
      }
      return state.expect(type, expected: expectedMessage.toString());
    }

    RegisterStatement parseRegister(Token token) {
      final token = state.advance();
      final lexeme = token.lexeme;
      if (!token.isIdentifier ||
          !lexeme.startsWith('A') && !lexeme.startsWith('D')) {
        throw ParserException('Expected register, but found ${token.lexeme}.');
      }
      if (lexeme == 'PC') {
        return PcRegisterStatement(location: token.location);
      }
      final index = int.tryParse(lexeme.substring(1));
      if (index == null) {
        throw ParserException(
            'Expected a register index, but found ${lexeme.substring(1)}.');
      }
      if (lexeme.startsWith('A')) {
        return AxRegisterStatement(location: token.location, index: index);
      } else {
        return DxRegisterStatement(location: token.location, index: index);
      }
    }

    RegisterStatement expectRegister<T>(Token token) {
      final register = parseRegister(token);
      if (register is T) {
        return register;
      }
      throw ParserException(
          'Expected register of type $T, but actually found register of type '
          '${token.runtimeType}.');
    }

    final location = state.peek().location;

    // Dn, An, CCR, SR, USP or immediate with label.
    if (state.peek().isIdentifier) {
      final identifier = state.advance();
      final operand = {
        'CCR': CcrOperandStatement(location: location),
        'SR': SrOperandStatement(location: location),
        'USP': UspOperandStatement(location: location),
      }[identifier.lexeme];
      if (operand != null) {
        return operand;
      }

      final register = parseRegister(identifier);
      if (register?.isPc ?? false) {
        throw ParserException('Unexpected identifier ${identifier.lexeme}.');
      }
    }

    // #xxx
    if (state.peek().isNumberSign) {
      state.advance();
      final token = expect(
        TokenType.number,
        expected: 'a value',
        operandType: OperandType.immediate,
      );
      final data = int.tryParse(token.lexeme);
      if (data == null) {
        throw ParserException(
            'Immediate data was expected, but found ${token.lexeme}.');
      }
      return ImmediateOperandStatement(location: location, value: data);
    }

    // -(An)
    if (state.peek().isMinus) {
      state.advance();
      expect(
        TokenType.leftParen,
        expected: 'an opening parenthesis',
        operandType: OperandType.axIndWithPreDec,
      );
      final identifier = state.expect(TokenType.identifier,
          expected: 'An for a predecrement -(An) operand');
      final register = expectRegister<AxRegisterStatement>(identifier);
      expect(
        TokenType.rightParen,
        expected: 'a closing parenthesis',
        operandType: OperandType.axIndWithPreDec,
      );
      return AxIndWithPreDecOperandStatement(
          location: location, register: register);
    }

    expect(TokenType.leftParen, expected: 'an operand');

    // (An) and (An)+
    if (state.peek().isIdentifier) {
      final identifier = state.advance();
      final register = expectRegister<AxRegisterStatement>(identifier);
      expect(TokenType.rightParen,
          expected: 'a closing parenthesis for an address register operand');
      if (state.peek().isPlus) {
        state.advance();
        return AxIndWithPostIncOperandStatement(
          location: location,
          register: register,
        );
      } else {
        return AxIndOperandStatement(location: location, register: register);
      }
    }

    final number = expect(TokenType.number,
        expected: 'a number for a displaced or absolute operand');

    // (xxx).W and (xxx).L
    if (state.peek().isRightParen) {
      expect(TokenType.dot, expected: 'a dot for an absolute (xxx).s operand');
      final size = parseSize(state);
      if (size.size == Size.byte) {
        throw ParserException(
            'Only word (W) or long word (L) sizes are permitted after (xxx).s '
            'operand.');
      }
      return {
        Size.word: AbsoluteWordOperandStatement(
          location: location,
          value: number.literal,
        ),
        Size.longWord: AbsoluteLongWordOperandStatement(
          location: location,
          value: number.literal,
        ),
      }[size.size];
    }

    // One of (d, An), (d, An, Xn.s), (d, PC), (d, PC, Xn.s)

    final displacement = number.literal;
    expect(TokenType.comma, expected: 'a comma after the displacement');
    final register = parseRegister(expect(TokenType.identifier,
        expected: 'either An or PC for a displaced operand'));
    if (register.isDx) {
      throw ParserException('Data register cannot be displaced.');
    }

    if (state.peek().isRightParen) {
      state.advance();
      return register.isPc
          ? PcIndWithDisplacementOperandStatement(
              location: location,
              displacement: displacement,
            )
          : AxIndWithDisplacementOperandStatement(
              location: location,
              displacement: displacement,
              register: register,
            );
    }

    // One of (d, An, Xn.s), (d, PC, Xn.s)

    final type =
        register.isPc ? OperandType.pcIndWithIndex : OperandType.axIndWithIndex;
    expect(TokenType.comma, expected: 'a comma', operandType: type);
    final index = parseRegister(state.advance());
    if (register.isPc) {
      throw ParserException('Expected index register.');
    }
    expect(TokenType.dot, expected: 'a dot', operandType: type);
    final size = parseSize(state);
    return register.isPc
        ? PcIndWithIndexOperandStatement(
            location: location,
            displacement: displacement,
            index: index,
            indexSize: size,
          )
        : AxIndWithIndexOperandStatement(
            location: location,
            register: register,
            displacement: displacement,
            index: index,
            indexSize: size,
          );
  }

  /// Makes sure that an operation configuration matches the given size and
  /// operands. Otherwise throws a [ParserException].
  static void ensureMatchingOperationConfigurationExists(
    Operation operation,
    Size size,
    List<OperandStatement> operands,
  ) {
    final sizeMatchingConfigs = operation.configurations.where((operation) {
      return operation.sizes.contains(size);
    });

    if (sizeMatchingConfigs.isEmpty) {
      final supportedSizes = operation.configurations
          .map((op) => op.sizes)
          .reduce((a, b) => a.union(b))
          .map(sizeToString);
      throw ParserException(
          "The operation ${operation.code} only supports the sizes "
          "${iterableToString(supportedSizes)}, but you tried to use it "
          "with the size ${sizeToString(size)}. That doesn't work.");
    }

    final matchingConfigs = sizeMatchingConfigs.where((configuration) {
      return IterableZip([configuration.operandTypes, operands])
          .every((operands) {
        final fittingTypes = operands.first as Set<OperandType>;
        final actualType = (operands.last as OperandStatement).type;
        return fittingTypes.contains(actualType);
      });
    });

    if (matchingConfigs.isEmpty) {
      final buffer = StringBuffer()
        ..write("You provided operands of the types ")
        ..write(iterableToString(
          operands.map((operand) => operandTypeToString(operand.type)),
        ))
        ..write(". But the ${operation.code} operation on size "
            "${sizeToString(size)} doesn't accept operands of these "
            "types. Here are all the combinations that are accepted:\n")
        ..writeAll([
          for (final config in sizeMatchingConfigs)
            '- ${iterableToString(config.sizes)}'
        ]);
      throw ParserException(buffer.toString());
    }

    assert(matchingConfigs.length == 1);
  }
}

class _LineParserState {
  _LineParserState(this.tokens, this.errorCollector, this.line)
      : assert(tokens != null),
        assert(errorCollector != null),
        assert(line != null);

  final List<Token> tokens;
  final ErrorCollector errorCollector;
  final int line;

  int start = 0;
  int current = 0;

  bool get isAtEnd => current >= tokens.length;
  Token peek() => isAtEnd ? null : tokens[current];
  Token peek2() => current + 1 >= tokens.length ? null : tokens[current + 1];
  Token peek3() => current + 2 >= tokens.length ? null : tokens[current + 2];

  Token advance() => tokens[current++];
  List<Token> advanceWhile(bool Function(Token token) predicate) {
    while (predicate(peek()) && !isAtEnd) {
      advance();
    }
    return tokens.sublist(start, current);
  }

  /// Advances the cursor if the type matches the expected [type]. Otherwise
  /// throws a [ParserException] describing what was [expected].
  Token expect(TokenType type, {@required String expected}) {
    if (peek().type != type) {
      throw ParserException("Expected $expected, but found "
          "'${peek().lexeme}' instead.");
    }
    return advance();
  }

  void tryOrRegisterError(void Function() callback) {
    try {
      callback();
    } on ParserException catch (error) {
      errorCollector.add(Error(
        location: peek().location,
        message: error.message,
      ));
    }
  }
}
