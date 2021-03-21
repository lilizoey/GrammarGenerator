class_name AST
extends Node

func _ready():
	randomize()
	var parser := ASTParser.Statement.get_parser()
	var test_parse := parser.parse("A = a \\n c (d e [f g])")
	var ast := Statement.create_statement(test_parse.get_result())
	print(ast)
	print(ast.decode())
	print(ast.evaluate("A b c"))

class Statement:
	static func create_statement(parsed_expression: ASTParser.Statement) -> Statement:
		if parsed_expression is ASTParser.FailureStatement:
			return null
		elif parsed_expression is ASTParser.EmptyStatement:
			return EmptyStatement.new()
		elif parsed_expression is ASTParser.Expr:
			return Expr.create_expr(parsed_expression)
		elif parsed_expression is ASTParser.Rule:
			return Rule.new(parsed_expression)
		elif parsed_expression is ASTParser.RuleList:
			return RuleList.new(parsed_expression)
		else:
			return null
	
	func decode() -> String:
		push_error("unimplemented method")
		return ""

class EmptyStatement extends Statement:
	func decode() -> String:
		return ""
	
	func _to_string():
		return "Empty"

class Rule extends Statement:
	var lhs: Symbol
	var rhs: Expr
	func _init(parsed_expression: ASTParser.Rule):
		lhs = Symbol.new(parsed_expression.get_lhs())
		rhs = Expr.create_expr(parsed_expression.get_rhs())
	
	func decode() -> String:
		return lhs.decode() + " = " + rhs.decode()
	
	func _to_string():
		return str(lhs) + " = " + str(rhs)
	
	func evaluate(input: String) -> String:
		var lhs_index := input.find(lhs.generate())
		if lhs_index >= 0:
			return input.substr(0, lhs_index) + rhs.generate() + input.substr(lhs_index + lhs.generate().length(), input.length())
		else:
			return input
	
	func evaluate_all(input: String, max_steps: int = -1, _max_rules: int = -1) -> String:
		var prev := ""
		var cur  := input
		var step := 0
		
		while prev != cur and step != max_steps:
			prev = cur
			cur = evaluate(cur)
			step += 1
		
		return cur

class RuleList extends Statement:
	var rules: Array
	func _init(parsed_expression: ASTParser.RuleList):
		rules = parsed_expression.get_rules()
		for i in rules.size():
			rules[i] = Statement.create_statement(rules[i])
	
	func decode() -> String:
		var acc := "" 
		for rule in rules:
			acc += rule.decode() + "\n"
		return acc
	
	func _to_string() -> String:
		var acc := "" 
		for rule in rules:
			acc += str(rule) + "\n"
		return acc
	
	func evaluate(input: String, max_rules: int = -1, max_steps: int = -1) -> String:
		var prev := ""
		var cur  := input
		var successful_rules := 0
		for rule in rules:
			prev = cur
			cur = rule.evaluate_all(cur, max_steps)
			if prev != cur:
				successful_rules += 1
			if successful_rules == max_rules:
				break
		return cur
	
	func evaluate_all(input: String, max_rules: int = -1, max_steps: int = -1) -> String:
		var prev := ""
		var cur  := input
		var step := 0
		
		while cur != prev and step != max_steps:
			prev = cur
			cur = evaluate(cur, max_rules, max_steps)
			step += 1
		
		return cur

class Expr extends Statement:
	static func create_expr(parsed_expression: ASTParser.Expr) -> Expr:
		if parsed_expression is ASTParser.StaticExpr:
			return Symbol.new(parsed_expression)
		elif parsed_expression is ASTParser.ExprList:
			return ExprList.new(parsed_expression)
		elif parsed_expression is ASTParser.ExprBracketList:
			return ExprOrList.new(parsed_expression)
		elif parsed_expression is ASTParser.ExprBracketListItem:
			return SettingsItem.new(parsed_expression)
		else:
			push_error("unsupported feature")
			return null
	
	func generate() -> String:
		push_error("unimplemented method")
		return ""
	
	func get_amount() -> int:
		return 1

class Symbol extends Expr:
	const special_character_mapping := {
		"\\s": " ",
		"\\n": "\n",
		"\\e": "",
	}

	var value: String
	
	func _init(parsed_expression: ASTParser.StaticExpr):
		value = parsed_expression.get_value()
	
	func _to_string():
		return "Symbol(" + value + ")"
	
	func decode() -> String:
		return value
	
	func generate() -> String:
		var generated := value
		for key in special_character_mapping:
			generated = generated.replace(key, special_character_mapping[key])
		return generated

class ExprList extends Expr:
	var exprs := []
	
	func _init(parsed_expression: ASTParser.ExprList):
		for _expr in parsed_expression.get_exprs():
			var expr: ASTParser.Expr = _expr
			exprs.append(Expr.create_expr(expr))
	
	func _to_string():
		var acc := "List("
		for expr in exprs:
			acc += str(expr) + ", "
		
		return acc.substr(0, acc.length() - 2) + ")"
	
	func decode() -> String:
		var acc := "("
		for expr in exprs:
			acc += expr.decode() + " "
		
		return acc.substr(0, acc.length() - 1) + ")"
	
	func generate() -> String:
		var acc := ""
		for expr in exprs:
			acc += expr.generate()
		
		return acc

class ExprOrList extends Expr:
	var exprs := []
	
	func _init(parsed_expression: ASTParser.ExprBracketList):
		for _expr in parsed_expression.get_exprs():
			var expr: ASTParser.Expr = _expr
			exprs.append(Expr.create_expr(expr))
	
	func _to_string():
		var acc := "Or["
		for expr in exprs:
			acc += str(expr) + ", "
		
		return acc.substr(0, acc.length() - 2) + "]"
	
	func decode() -> String:
		var acc := "["
		for expr in exprs:
			acc += expr.decode() + " "
		
		return acc.substr(0, acc.length() - 1) + "]"
	
	func generate() -> String:
		var r := int(rand_range(0, get_total()))
		var acc := 0
		var prev = exprs[0]
		for expr in exprs:
			if acc >= r:
				return prev.generate()
			acc += expr.get_amount()
			prev = expr
		
		return prev.generate()
	
	func get_total() -> int:
		var acc = 0
		for expr in exprs:
			acc += expr.get_amount()
		return acc

class SettingsItem extends Expr:
	var expr: Expr
	var settings: Symbol 
	
	func _init(parsed_expression: ASTParser.ExprBracketListItem):
		expr = create_expr(parsed_expression.get_expr())
		if parsed_expression.get_settings() is ASTParser.Symbol:
			settings = create_expr(parsed_expression.get_settings())
	
	func _to_string():
		return str(expr) + "{" + str(settings) + "}"
	
	func decode() -> String:
		return expr.decode() + "{" + settings.decode() + "}"
	
	func generate() -> String:
		return expr.generate()
	
	func get_amount() -> int:
		if not settings:
			return 1
		var s := settings.generate()
		if int(s) > 0:
			return int(s)
		else:
			return 1
