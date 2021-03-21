extends Node




# exp := exp·exp | symbol | (exp) | {exp} | [exp exp …]
# symbol is any string of symbol not used for something else
# · is any amount of whitespace (including none unless both sides are symbols)
# exp·exp means exp then exp
# (exp) is equivalent to exp
# {exp} is an optional expression
# [exp exp …] is any of the exps

class Exp:
	var remainder := ""
	var contents = []
	var success  := false
	
	func _init(_input: String):
		var input := _input
		var completed := false
		while (not completed):
			if input.length() == 0:
				break
			var attempt = Symbol.new(input)
			if attempt.is_success():
				contents.append(attempt)
				input = attempt.get_remainder().strip_edges()
				continue
			attempt = OptionalExp.new(input)
			if attempt.is_success():
				contents.append(attempt)
				input = attempt.get_remainder().strip_edges()
				continue
			attempt = OrExp.new(input)
			if attempt.is_success():
				contents.append(attempt)
				input = attempt.get_remainder().strip_edges()
				continue
			attempt = ParenExp.new(input)
			if attempt.is_success():
				contents.append(attempt)
				input = attempt.get_remainder().strip_edges()
				continue
			
			completed = true
		
		if input.length() == 0:
			success = true
			remainder = ""
		else:
			success = false
			remainder = _input
		
	func get_remainder() -> String:
		return remainder
	
	func get_contents() -> Array:
		return contents
	
	func is_success() -> bool:
		return success
	
	func to_string() -> String:
		var s := ""
		for e in contents:
			s += e.to_string() + " "
		return s.strip_edges()
	
	func generate() -> String:
		var acc := ""
		for e in contents:
			acc += e.generate()
		return acc

class Symbol:
	var contents := ""
	var remainder := ""
	var success  := false
	
	var regex := RegEx.new()
	
	func _init(input: String):
		regex.compile("^[^\\(\\)\\{\\}\\[\\]\\s]+")
		var result := regex.search(input)
		if result:
			contents = result.get_string()
			remainder = input.substr(contents.length())
			success = true
		else:
			success = false
			remainder = input
		
	func get_remainder() -> String:
		return remainder
	
	func get_contents() -> String:
		return contents
	
	func is_success() -> bool:
		return success
	
	func to_string() -> String:
		return contents
	
	func generate() -> String:
		return contents

class OptionalExp:
	var contents: Object = null
	var remainder := ""
	var success  := false
	
	var regex := RegEx.new()
	
	func _init(input: String):
		if input[0] != "{":
			remainder = input
			return
		var counter := 1
		var acc := ""
		for c in input.substr(1):
			if c == "{":
				counter += 1
			if c == "}":
				counter -= 1
			
			if counter == 0:
				break
			else:
				acc += c
			
			
		if acc.length() == input.length() - 1:
			success = false
			remainder = input
		else:
			var expr := Exp.new(acc)
			success = expr.is_success()
			if success:
				contents = expr
				remainder = input.substr(acc.length() + 2)
			else:
				contents = null
				remainder = input
		
	func get_remainder() -> String:
		return remainder
	
	func get_contents() -> Object:
		return contents
	
	func is_success() -> bool:
		return success
	
	func to_string() -> String:
		return "{" + contents.to_string() + "}"
	
	func generate() -> String:
		var r := rand_range(0,1.0) < 0.5
		if r:
			return contents.generate()
		else:
			return ""

class OrExp:
	var contents: Array = []
	var remainder := ""
	var success  := false
	
	var regex := RegEx.new()
	
	func _init(input: String):
		if input[0] != "[":
			remainder = input
			return
		var counter := 1
		var acc := ""
		for c in input.substr(1):
			if c == "[":
				counter += 1
			if c == "]":
				counter -= 1
			
			if counter == 0:
				break
			else:
				acc += c
			
			
		if acc.length() == input.length() - 1:
			success = false
			remainder = input
		else:
			var expr := Exp.new(acc)
			success = expr.is_success()
			if success:
				contents = expr.get_contents()
				remainder = input.substr(acc.length() + 2)
			else:
				contents = []
				remainder = input
		
	func get_remainder() -> String:
		return remainder
	
	func get_contents() -> Array:
		return contents
	
	func is_success() -> bool:
		return success
	
	func to_string() -> String:
		var s := "["
		for e in contents:
			s += e.to_string() + " "
		return s.strip_edges() + "]"
	
	func generate() -> String:
		var r := floor(rand_range(0, contents.size()))
		return contents[r].generate()

class ParenExp:
	var contents: Object = null
	var remainder := ""
	var success  := false
	
	var regex := RegEx.new()
	
	func _init(input: String):
		if input[0] != "(":
			remainder = input
			return
		var counter := 1
		var acc := ""
		for c in input.substr(1):
			if c == "(":
				counter += 1
			if c == ")":
				counter -= 1
			
			if counter == 0:
				break
			else:
				acc += c
			
		if acc.length() == 0:
			success = true
			remainder = input.substr(2)
			contents = Symbol.new("")
			contents.success = true
			contents.contents = ""
			contents.remainder = ""
		elif acc.length() == input.length() - 1:
			success = false
			remainder = input
		else:
			var expr := Exp.new(acc)
			success = expr.is_success()
			if success:
				contents = expr
				remainder = input.substr(acc.length() + 2)
			else:
				contents = null
				remainder = input
		
	func get_remainder() -> String:
		return remainder
	
	func get_contents() -> Object:
		return contents
	
	func is_success() -> bool:
		return success
	
	func to_string() -> String:
		return "(" + contents.to_string() + ")"
	
	func generate() -> String:
		return contents.generate()

class Rule:
	var remainder := ""
	var name: Symbol = null
	var expr: Exp = null
	var success  := false
	
	func _init(_input: String):
		var input := _input.strip_edges()
		name = Symbol.new(input)
		if not name.is_success():
			success = false
			remainder = _input
			return
		
		input = name.get_remainder().strip_edges()
		if not input.begins_with(":="):
			success = false
			remainder = _input
			return
		
		var regex := RegEx.new()
		regex.compile("^[^\\n]*\\n?")
		input = input.substr(2).strip_edges()
		var contents := regex.search(input)
		if not contents:
			success = false
			remainder = _input
			return
		expr = Exp.new(contents.get_string())
		
		if not expr.is_success():
			success = false
			remainder = _input
			return
		
		success = true
		remainder = input.substr(contents.get_string().length())
	
	
	func get_remainder() -> String:
		return remainder
	
	func get_name() -> Symbol:
		return name
	
	func is_success() -> bool:
		return success
	
	func to_string() -> String:
		if not success:
			return ""
		else:
			return name.to_string() + " := " + expr.to_string() + "\n"
	
	func apply(_input: String, max_steps: int = -1) -> String:
		var input := _input
		var regex := RegEx.new()
		regex.compile(name.generate())
		var found := regex.search(input)
		var step := 0
		while (found and not step == max_steps):
			var replacement := expr.generate()
			var prefix := input.substr(0, found.get_start())
			var suffix := input.substr(found.get_end(), input.length())
			input = prefix + replacement + suffix
			found = regex.search(input)
			step += 1
		return input

class VocabGenerator:
	var success := false
	var failure: Rule = null
	var rules := []
	
	func _init(input: String):
		var lines := input.strip_edges().split("\n")
		for line in lines:
			if line.strip_edges().length() == 0:
				continue
			var new_rule := Rule.new(line)
			if not new_rule.is_success():
				success = false
				failure = new_rule
				return
			rules.append(new_rule)
		success = true
	
	func is_success() -> bool:
		return success
	
	func get_failure() -> Rule:
		return failure
	
	func apply(input: String, max_steps: int = -1, max_steps_per_rule: int = -1) -> String:
		var step := 0
		var prev := input
		var cur := prev
		
		while step != max_steps:
			for rule in rules:
				cur = rule.apply(cur, max_steps_per_rule)
				if cur != prev:
					break
			if cur == prev:
				break
			
			step += 1
			prev = cur
		
		return cur

class TracingGenerator:
	var vocab: VocabGenerator
	var input: String
	var derivation := []
	
	func _init(_vocab: VocabGenerator, _input: String):
		vocab = _vocab
		input = _input
		derivation.append(input)
	
	func step(max_steps: int = -1, max_steps_per_rule: int = -1) -> String:
		input = vocab.apply(input, max_steps, max_steps_per_rule)
		derivation.append(input)
		return input
	
	func to_string(sep: String = "\n") -> String:
		var acc = ""
		for d in derivation:
			acc += d + sep
		return acc.strip_edges()

