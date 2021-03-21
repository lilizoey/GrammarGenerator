extends Node



# expression = can generate something
# rule = can modify an input string
# expressions are not rules
# rules are not expressions
# statement = rules and expressions
class Parser:
	const reserved_characters := ["(", ")", "{", "}", "[", "]", "=", "\n", " ", ",", "."]
	
	static func delimiter_parser(opener: Parser, pre_inner: Parser, inner: Parser, closer: Parser) -> Parser:
		return pre_inner.or_else([inner.delimited(opener, closer)]).parse_many1()

	static func nested_delimiter_parser_rec(opener: Parser, inner: Parser, closer: Parser) -> Parser:
		return RecursiveParser.new(funcref(Parser, "delimiter_parser"), [opener, inner, null, closer])
	
	func parse(input: String) -> ParseResult:
		push_error("must be overridden")
		return null
	
	func and_then(p: Array) -> AndThenParser:
		return AndThenParser.new([self] + p)
	
	func or_else(p: Array) -> OrElseParser:
		return OrElseParser.new([self] + p)
	
	func parse_many0() -> Many0Parser:
		return Many0Parser.new(self)
	
	func parse_many1() -> Many1Parser:
		return Many1Parser.new(self)
	
	func optional() -> OptionalParser:
		return OptionalParser.new(self)
	
	func delimited(opener: Parser, closer: Parser) -> DelimitedParser:
		return DelimitedParser.new(opener, self, closer)
	
	func discard() -> DiscardingParser:
		return DiscardingParser.new(self)
	
	func nested_delimiter(opener: Parser, closer: Parser, separator: Parser) -> NestedDelimitedParser:
		return NestedDelimitedParser.new(opener, self, closer, separator.discard())

class ParseResult:
	var success: bool
	var result: Statement
	var remainder: String
	
	static func Empty(remainder: String) -> ParseResult:
		return ParseResult.new(true, EmptyStatement.new(), remainder)
	
	static func Failure() -> ParseResult:
		return ParseResult.new(false, EmptyStatement.new(), "")
	
	func _init(_success: bool, _result: Statement, _remainder: String):
		success = _success
		result = _result
		remainder = _remainder
	
	func is_success() -> bool:
		return success and (not result is FailureStatement) 
	
	func is_complete() -> bool:
		return is_success() and get_remainder().length() == 0
	
	func get_result() -> Statement:
		if is_success():
			return result
		else:
			return EmptyStatement.new()
	
	func get_remainder() -> String:
		if is_success():
			return remainder
		else:
			return ""

# returns a failure if any parser fails
# combines all results if all are successful
class AndThenParser extends Parser:
	var parsers: Array
	func _init(_parsers: Array):
		for parser in _parsers:
			assert(parser is Parser)
		parsers = _parsers
	
	func parse(_input: String) -> ParseResult:
		var result = ParseResult.Empty(_input)
		var input = _input
		
		for parser in parsers:
			var new_result: ParseResult = parser.parse(input)
			if not new_result.is_success():
				result = ParseResult.Failure()
				break
			input = new_result.get_remainder()
			result = ParseResult.new(
				true, 
				result.get_result().combine(new_result.get_result()), 
				input
			)
		return result

# returns the first successful parse
class OrElseParser extends Parser:
	var parsers: Array
	func _init(_parsers: Array):
		for parser in _parsers:
			assert(parser is Parser)
		parsers = _parsers
	
	func parse(_input: String) -> ParseResult:
		var result = ParseResult.Failure()
		var input = _input
		
		for parser in parsers:
			var new_result: ParseResult = parser.parse(input)
			if not new_result.is_success():
				continue
			
			result = new_result
			break
		
		return result

class Many0Parser extends Parser:
	var parser: Parser
	func _init(_parser: Parser):
		parser = _parser
	
	func parse(_input) -> ParseResult:
		var result = ParseResult.Empty(_input)
		var input = _input
		
		while true:
			var new_result := parser.parse(input)
			if not new_result.is_success():
				break
			input = new_result.get_remainder()
			result = ParseResult.new(true, result.get_result().combine(new_result.get_result()), new_result.get_remainder())
		
		return result

class Many1Parser extends Parser:
	var parser: Parser
	func _init(_parser: Parser):
		parser = _parser
	
	func parse(_input: String) -> ParseResult:
		var result = ParseResult.Empty(_input)
		var input = _input
		
		while true:
			var new_result := parser.parse(input)
			if not new_result.is_success():
				break
			input = new_result.get_remainder()
			result = ParseResult.new(true, result.get_result().combine(new_result.get_result()), new_result.get_remainder())
		
		if input == _input:
			return ParseResult.Failure()
		else:
			return result

class OptionalParser extends Parser:
	var parser: Parser
	func _init(_parser: Parser):
		parser = _parser
	
	func parse(_input: String) -> ParseResult:
		var result := parser.parse(_input)
		if result.is_success():
			return result
		else:
			return ParseResult.Empty(_input)

class DelimitedParser extends Parser:
	var opener: Parser
	var inner: Parser
	var closer: Parser
	
	func _init(_opener: Parser, _inner: Parser, _closer: Parser):
		opener = _opener
		inner = _inner
		closer = _closer
	
	func parse(_input: String) -> ParseResult:
		var open_result := opener.parse(_input)
		if not open_result.is_success():
			return ParseResult.Failure()
		
		var inner_result := inner.parse(open_result.get_remainder())
		if not inner_result.is_success():
			return ParseResult.Failure()
		
		var closer_result := closer.parse(inner_result.get_remainder())
		if not closer_result.is_success():
			return ParseResult.Failure()
		
		return ParseResult.new(true, inner_result.get_result(), closer_result.get_remainder())

class DiscardingParser extends Parser:
	var parser: Parser
	func _init(_parser: Parser):
		parser = _parser
	
	func parse(_input: String) -> ParseResult:
		var result := parser.parse(_input)
		if result.is_success():
			return ParseResult.Empty(result.get_remainder())
		else:
			return ParseResult.Empty(_input)

class RecursiveParser extends Parser:
	var parser: Parser
	
	func _init(new_parser: FuncRef, _args: Array):
		var args = _args
		
		for i in range(args.size()):
			if args[i] == null:
				args[i] = self
			assert(args[i] is Parser)
		
		parser = new_parser.call_funcv(args)
	
	func parse(_input: String) -> ParseResult:
		return parser.parse(_input)

class NestedDelimitedParser extends Parser:
	var opener: Parser
	var parser: Parser
	var closer: Parser
	var separator: Parser
	
	func _init(_opener: Parser, _parser: Parser, _closer: Parser, _separator: Parser):
		opener = _opener
		parser = _parser
		closer = _closer
		separator = _separator
	
	func parse(_input: String) -> ParseResult:
		var input = _input
		
		var opener_result := opener.parse(input)
		if not opener_result.is_success():
			return ParseResult.Failure()
		input = opener_result.get_remainder()
		
		var new_parser := (separator.optional()).and_then([parser.or_else([self]).and_then([separator.optional()]).parse_many1()])
		var parser_result := new_parser.parse(input)
		if not parser_result.is_success():
			return ParseResult.Failure()
		
		input = parser_result.get_remainder()
		
		var closer_result := closer.parse(input)
		if not closer_result.is_success():
			return ParseResult.Failure()
		input = closer_result.get_remainder()
		
		return ParseResult.new(
			true,
			parser_result.get_result(),
			input
		)

class DeferredParser extends Parser:
	var parser_ref: FuncRef
	var parser: Parser
	
	func _init(_parser_ref: FuncRef):
		parser_ref = _parser_ref
	
	func parse(_input: String) -> ParseResult:
		if not parser:
			parser = parser_ref.call_func()
		return parser.parse(_input)


# parse tree

class Statement:
	func combine(other: Statement) -> Statement:
		push_error("abstract method")
		return null
	
	static func get_parser() -> Parser:
		return RuleList.get_parser()

class FailureStatement extends Statement:
	func combine(_other) -> Statement:
		return self

class EmptyStatement extends Statement:
	func combine(other: Statement) -> Statement:
		return other

class Expr extends Statement:
	func generate() -> String:
		push_error("unimplemented static expression")
		return ""
	
	static func get_parser() -> Parser:
		return OrElseParser.new([
			Symbol.get_parser(),
			DeferredParser.new(funcref(ExprList, "get_parser")),
			DeferredParser.new(funcref(ExprBracketList, "get_parser")),
		])

# a static expression always evaluates to the same thing
class StaticExpr extends Expr:
	func get_value() -> String:
		push_error("unimplemented method")
		return ""

class Letter extends StaticExpr:
	var value: String
	
	func _init(_value: String):
		value = _value
	
	func combine(other: Statement) -> Statement:
		if other is Letter:
			return Symbol.new(self.get_value() + other.get_value())
		elif other is Symbol:
			return Symbol.new(self.get_value() + other.get_value())
		else:
			return Symbol.new(self.get_value()).combine(other)
	
	func get_value() -> String:
		return value
	
	class LetterParser extends Parser:
		var include: Array
		var exclude: Array
		
		func _init(_include: Array = [], _exclude: Array = reserved_characters):
			include = _include
			exclude = _exclude
	
		func parse(input: String) -> ParseResult:
			if input.length() == 0:
				return ParseResult.Failure()
			elif exclude.size() > 0 and input[0] in exclude:
				return ParseResult.Failure()
			elif include.size() > 0 and not input[0] in include:
				return ParseResult.Failure()
			else:
				return ParseResult.new(true, Letter.new(input[0]), input.substr(1))
	
	static func get_parser() -> Parser:
		return LetterParser.new()
	
	static func get_custom_parser(include: Array = [], exclude: Array = Parser.reserved_characters) -> Parser:
		return LetterParser.new(include, exclude)
	
	static func get_whitespace_parser() -> Parser:
		return LetterParser.new([" "], [])

class Symbol extends StaticExpr:
	var value: String
	
	func _init(_value: String):
		value = _value
	
	func get_value() -> String:
		return value
	
	func combine(other: Statement) -> Statement:
		if other is Letter:
			return Symbol.new(get_value() + other.get_value())
		elif other is Expr:
			return ExprList.new([self, other])
		elif other is Rule:
			return FailureStatement.new()
		elif other is EmptyStatement:
			return self
		else:
			push_error("unreachable code block reached")
			return FailureStatement.new()
	
	static func get_parser() -> Parser:
		return Letter.get_parser().parse_many1()

class ExprList extends Expr:
	var exprs: Array
	
	func _init(_exprs: Array):
		for expr in _exprs:
			assert(expr is Expr)
		
		exprs = _exprs
	
	func combine(other: Statement) -> Statement:
		if other is ExprList:
			return ExprList.new(exprs + other.get_exprs())
		elif other is FailureStatement:
			return other
		elif other is Rule:
			return FailureStatement.new()
		elif other is EmptyStatement:
			return self
		elif other is Expr:
			return ExprList.new(exprs + [other])
		else:
			push_error("reached unreachable branch")
			return null
	
	func get_exprs() -> Array:
		return exprs
	
	class ExprListParser extends Parser:
		var white_space := Letter.get_custom_parser([" "],[]).parse_many0()
		var parser := Expr.get_parser().nested_delimiter(
			Letter.get_custom_parser(["("], []),
			Letter.get_custom_parser([")"], []),
			white_space
		)
		
		func _init():
			pass
		
		func parse(_input: String) -> ParseResult:
			var parse_result := parser.parse(_input)
			if parse_result.is_success():
				var result = parse_result.get_result()
				if result is ExprList:
					return parse_result
				elif result is Expr:
					return ParseResult.new(true, ExprList.new([result]), parse_result.get_remainder())
				else:
					return ParseResult.Failure()
			else:
				return ParseResult.Failure()
	
	static func get_parser() -> Parser:
		return ExprListParser.new()

class ExprBracketList extends Expr:
	var exprs: Array
	
	func _init(_exprs: Array):
		for expr in _exprs:
			assert(expr is Expr)
		
		exprs = _exprs
	
	func combine(other: Statement) -> Statement:
		if other is FailureStatement:
			return other
		elif other is Rule:
			return FailureStatement.new()
		elif other is EmptyStatement:
			return self
		elif other is Expr:
			return ExprList.new([self] + [other])
		else:
			push_error("reached unreachable branch")
			return null
	
	func get_exprs() -> Array:
		return exprs
	
	class ExprBracketListParser extends Parser:
		var white_space := Letter.get_custom_parser([" "],[]).parse_many0()
		var parser := ExprBracketListItem.get_parser().nested_delimiter(
			Letter.get_custom_parser(["["], []),
			Letter.get_custom_parser(["]"], []),
			white_space
		)
		
		func _init():
			pass
		
		func parse(_input: String) -> ParseResult:
			var parse_result := parser.parse(_input)
			if parse_result.is_success():
				var result = parse_result.get_result()
				if result is ExprBracketList:
					return parse_result
				elif result is ExprList:
					return ParseResult.new(true, ExprBracketList.new(result.get_exprs()), parse_result.get_remainder())
				elif result is Expr:
					return ParseResult.new(true, ExprBracketList.new([result]), parse_result.get_remainder())
				else:
					return ParseResult.Failure()
			else:
				return ParseResult.Failure()
	
	static func get_parser() -> Parser:
		return ExprBracketListParser.new()

class ExprBracketListItem extends Expr:
	var expr: Expr
	var settings: Statement
	
	func _init(_expr: Expr, _settings: Statement):
		expr = _expr
		settings = _settings
	
	func combine(other: Statement) -> Statement:
		if other is FailureStatement:
			return other
		elif other is Rule:
			return FailureStatement.new()
		elif other is EmptyStatement:
			return self
		elif other is Expr:
			return ExprList.new([self] + [other])
		else:
			push_error("reached unreachable branch")
			return null
	
	func get_expr() -> Expr:
		return expr
	
	func get_settings() -> Statement:
		return settings
	
	class ExprBracketListItemParser extends Parser:
		var white_space := Letter.get_custom_parser([" "],[]).parse_many0()
		var settings_parser := Letter \
			.get_custom_parser(["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"], []) \
			.parse_many1() \
			.delimited(
				Letter.get_custom_parser(["{"], []).and_then([Letter.get_whitespace_parser().parse_many0()]), 
				Letter.get_whitespace_parser().parse_many0().and_then([Letter.get_custom_parser(["}"], [])])
			).optional()
		
		func _init():
			pass
		
		func parse(_input: String) -> ParseResult:
			var expr := Expr.get_parser().parse(_input)
			if not expr.is_success():
				return ParseResult.Failure()
			
			var settings := settings_parser.parse(expr.get_remainder())
			
			return ParseResult.new(
				true,
				ExprBracketListItem.new(expr.get_result(), settings.get_result()),
				settings.get_remainder()
			)
	
	static func get_parser() -> Parser:
		return ExprBracketListItemParser.new()

class Rule extends Statement:
	var lhs: StaticExpr
	var rhs: Expr
	
	func _init(_lhs: StaticExpr, _rhs: Expr):
		lhs = _lhs
		rhs = _rhs
	
	func get_lhs() -> StaticExpr:
		return lhs
	
	func get_rhs() -> Expr:
		return rhs
	
	func combine(other: Statement) -> Statement:
		if other is RuleList:
			return RuleList.new([self] + other.get_rules())
		elif other is Rule:
			return RuleList.new([self, other])
		elif other is Expr:
			return Rule.new(lhs, rhs.combine(other))
		elif other is FailureStatement:
			return other
		elif other is EmptyStatement:
			return self
		else:
			push_error("unreachable code block reached")
			return FailureStatement.new()
	
	class RuleParser extends Parser:
		func parse(input: String) -> ParseResult:
			var lhs_result := AndThenParser.new([
				Letter.get_whitespace_parser().parse_many0().discard(),
				Symbol.get_parser(),
				Letter.get_whitespace_parser().parse_many0().discard()
			]).parse(input)
			
			if not lhs_result.is_success():
				return ParseResult.Failure()
			
			var equals_result := Letter.get_custom_parser(["="], []).parse(lhs_result.get_remainder())
			
			if not equals_result.is_success():
				return ParseResult.Failure()
			
			var rhs_result := AndThenParser.new([
				Letter.get_whitespace_parser().parse_many0().discard(),
				AndThenParser.new([
					Expr.get_parser(),
					Letter.get_whitespace_parser().parse_many0().discard(),
				]).parse_many1(),
				Letter.get_custom_parser(["\n"], []).optional().discard()
			]).parse(equals_result.get_remainder())
			
			if not rhs_result.is_success():
				return ParseResult.Failure()
			
			return ParseResult.new(
				true,
				Rule.new(lhs_result.get_result(), rhs_result.get_result()),
				rhs_result.get_remainder()
			)
	
	static func get_parser() -> Parser:
		return RuleParser.new()

class RuleList extends Statement:
	var rules: Array
	
	func _init(_rules: Array):
		for rule in rules:
			assert(rule is Rule)
		rules = _rules
	
	func join(other: RuleList) -> RuleList:
		return RuleList.new(rules + other.get_rules())
	
	func combine(other: Statement) -> Statement:
		if other is RuleList:
			return RuleList.new(rules + other.get_rules())
		elif other is Expr:
			var new_rules = rules.duplicate()
			new_rules[new_rules.size() - 1] = new_rules[new_rules.size() - 1].combine(other)
			return RuleList.new(new_rules)
		elif other is FailureStatement:
			return other
		elif other is EmptyStatement:
			return self
		elif other is Rule:
			return RuleList.new(rules + [other])
		else:
			push_error("reached unreachable branch")
			return null
	
	func get_rules() -> Array:
		return rules
	
	static func get_parser() -> Parser:
		return Rule.get_parser().and_then([Letter.get_custom_parser([" ", "\n"], []).parse_many0().discard()]).parse_many1()

