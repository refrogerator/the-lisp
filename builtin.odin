package main

import "core:fmt"

basic_math_stuff :: proc(state: ^InterpreterState) {
    addGlobal(state, "+", builtinNode(proc(node: ^Node, s: ^InterpreterState) -> ^Node {
        return reduce(node, proc(a: ^Node, b: ^Node, s: ^InterpreterState) -> ^Node {
            return numNode(asNumber(b) + asNumber(eval(a, s)))
        }, s)
    }))
    addGlobal(state, "-", builtinNode(proc(node: ^Node, s: ^InterpreterState) -> ^Node {
        return reduce(node, proc(a: ^Node, b: ^Node, s: ^InterpreterState) -> ^Node {
            return numNode(asNumber(b) - asNumber(eval(a, s)))
        }, s)
    }))
    addGlobal(state, "*", builtinNode(proc(node: ^Node, s: ^InterpreterState) -> ^Node {
        return reduce(node, proc(a: ^Node, b: ^Node, s: ^InterpreterState) -> ^Node {
            return numNode(asNumber(b) * asNumber(eval(a, s)))
        }, s)
    }))
    addGlobal(state, "/", builtinNode(proc(node: ^Node, s: ^InterpreterState) -> ^Node {
        return reduce(node, proc(a: ^Node, b: ^Node, s: ^InterpreterState) -> ^Node {
            return numNode(asNumber(b) / asNumber(eval(a, s)))
        }, s)
    }))

    addGlobal(state, ">", builtinNode(proc(node: ^Node, s: ^InterpreterState) -> ^Node {
        return reduce(node, proc(a: ^Node, b: ^Node, s: ^InterpreterState) -> ^Node {
            return boolNode(asNumber(b) > asNumber(eval(a, s)))
        }, s)
    }))

    addGlobal(state, "<", builtinNode(proc(node: ^Node, s: ^InterpreterState) -> ^Node {
        return reduce(node, proc(a: ^Node, b: ^Node, s: ^InterpreterState) -> ^Node {
            return boolNode(asNumber(b) < asNumber(eval(a, s)))
        }, s)
    }))

    addGlobal(state, ">=", builtinNode(proc(node: ^Node, s: ^InterpreterState) -> ^Node {
        return reduce(node, proc(a: ^Node, b: ^Node, s: ^InterpreterState) -> ^Node {
            return boolNode(asNumber(b) >= asNumber(eval(a, s)))
        }, s)
    }))

    addGlobal(state, "<=", builtinNode(proc(node: ^Node, s: ^InterpreterState) -> ^Node {
        return reduce(node, proc(a: ^Node, b: ^Node, s: ^InterpreterState) -> ^Node {
            return boolNode(asNumber(b) <= asNumber(eval(a, s)))
        }, s)
    }))

    addGlobal(state, "=", builtinNode(proc(node: ^Node, s: ^InterpreterState) -> ^Node {
        return reduce(node, proc(a: ^Node, b: ^Node, s: ^InterpreterState) -> ^Node {
            return boolNode(asNumber(b) == asNumber(eval(a, s)))
        }, s)
    }))

    addGlobal(state, "!=", builtinNode(proc(node: ^Node, s: ^InterpreterState) -> ^Node {
        return reduce(node, proc(a: ^Node, b: ^Node, s: ^InterpreterState) -> ^Node {
            return boolNode(asNumber(b) != asNumber(eval(a, s)))
        }, s)
    }))

}

bool_stuff :: proc(state: ^InterpreterState) {
    addGlobal(state, "not", builtinNode(proc(node: ^Node, s: ^InterpreterState) -> ^Node {
        return boolNode(!asBool(eval(car(node), s)))
    }))
}

list_stuff :: proc(state: ^InterpreterState) {
    addGlobal(state, "cons", builtinNode(proc(node: ^Node, s: ^InterpreterState) -> ^Node {
        c := asCons(node)
        return consNode(eval(c.car,s ), eval(asCons(c.cdr).car, s))
    }))

    addGlobal(state, "car", builtinNode(proc(node: ^Node, s: ^InterpreterState) -> ^Node {
        return car(eval(car(node), s))
    }))

    addGlobal(state, "cdr", builtinNode(proc(node: ^Node, s: ^InterpreterState) -> ^Node {
        return cdr(eval(car(node), s))
    }))

    addGlobal(state, "list", builtinNode(proc(node: ^Node, s: ^InterpreterState) -> ^Node {
        cur := node
        ret: ^Node = nil

        for isCons(cur) {
            ret = consNode(eval(car(cur), s), ret)
            cur = cdr(cur)
        }

        return reverse(ret)
    }))

    call_on :: proc() {
    }

    addGlobal(state, "map", builtinNode(proc(node: ^Node, s: ^InterpreterState) -> ^Node {
        cur := eval(car(cdr(node)), s)
        ret: ^Node = nil

        e := eval(car(node), s)

        for isCons(cur) {
            ret = consNode(call_no_eval(s, e, consNode(car(cur), nil)), ret)
            cur = cdr(cur)
        }

        return reverse(ret)
    }))

    addGlobal(state, "foreach", builtinNode(proc(node: ^Node, s: ^InterpreterState) -> ^Node {
        cur := eval(car(cdr(node)), s)

        e := eval(car(node), s)

        for isCons(cur) {
            call_no_eval(s, e, consNode(car(cur), nil))
            cur = cdr(cur)
        }

        return nil
    }))
}

builtin_stuff :: proc(state: ^InterpreterState) {
    // TODO arity checking
    addGlobal(state, "quote", builtinNode(proc(node: ^Node, s: ^InterpreterState) -> ^Node {
        return car(node)
    }))

    addGlobal(state, "unquote", builtinNode(proc(node: ^Node, s: ^InterpreterState) -> ^Node {
        error("not inside a quasiquote")
        return nil
    }))

    addGlobal(state, "quasiquote", builtinNode(proc(node: ^Node, s: ^InterpreterState) -> ^Node {
        cur := car(node)

        unquote := toSymbol("unquote", s)
        ret: ^Node = nil

        for isCons(cur) {
            if isCons(car(cur)) && isSymbol(car(car(cur))) && asSymbol(car(car(cur))) == unquote {
                ret = consNode(eval(car(cdr(car(cur))), s), ret)
            } else {
                ret = consNode(car(cur), ret)
            }
            cur = cdr(cur)
        }

        return reverse(ret)
    }))

    addGlobal(state, "lambda", builtinNode(proc(node: ^Node, s: ^InterpreterState) -> ^Node {
        return lambdaNode(car(node), cdr(node), last(s.stack)^ if len(s.stack) > 0 else nil)
    }))

    addAlias(state, "lambda", "fn")

    addGlobal(state, "define-macro", builtinNode(proc(node: ^Node, s: ^InterpreterState) -> ^Node {
        s.globals[asSymbol(car(node))] = macroNode(car(cdr(node)), cdr(cdr(node)))
        return nil
    }))

    addGlobal(state, "macroexpand", builtinNode(proc(node: ^Node, s: ^InterpreterState) -> ^Node {
        first := eval(car(node), s)
        return call_lambda_internal(s, false, Lambda(asMacro(eval(car(first), s))), cdr(first))
    }))


    //addGlobal(state, "let", builtinNode(proc(node: ^Node, s: ^InterpreterState) -> ^Node {
    //}))

    addGlobal(state, "set!", builtinNode(proc(node: ^Node, s: ^InterpreterState) -> ^Node {
        setSymbol(asSymbol(car(node)), eval(car(cdr(node)), s), s)
        return nil
    }))

    addGlobal(state, "define", builtinNode(proc(node: ^Node, s: ^InterpreterState) -> ^Node {
        c := asCons(node)
        if isCons(c.car) {
            s.globals[asSymbol(car(c.car))] = eval(consNode(s.globals[toSymbol("lambda", s)], consNode(cdr(c.car), c.cdr)), s)
        } else {
            s.globals[asSymbol(c.car)] = eval(car(c.cdr), s)
        }
        return nil
    }))

    addGlobal(state, "gensym", builtinNode(proc(node: ^Node, s: ^InterpreterState) -> ^Node {
        if node != nil {
            return symNode(fmt.aprintf("%s%i", s.symbols[asSymbol(eval(car(node), s))], len(s.symbols)), s)
        } else {
            return symNode(fmt.aprintf("g%i", len(s.symbols)), s)
        }
    }))

    addGlobal(state, "nil?", builtinNode(proc(node: ^Node, s: ^InterpreterState) -> ^Node {
        return boolNode(eval(car(node), s) == nil)
    }))
}

basic_io_stuff :: proc(state: ^InterpreterState) {
    addGlobal(state, "write", builtinNode(proc(node: ^Node, s: ^InterpreterState) -> ^Node {
        evalLW(node, s)
        return nil
    }))

    addGlobal(state, "writeln", builtinNode(proc(node: ^Node, s: ^InterpreterState) -> ^Node {
        evalLW(node, s)
        fmt.print("\n")
        return nil
    }))

    addGlobal(state, "print", builtinNode(proc(node: ^Node, s: ^InterpreterState) -> ^Node {
        evalLP(node, s)
        return nil
    }))

    addGlobal(state, "println", builtinNode(proc(node: ^Node, s: ^InterpreterState) -> ^Node {
        evalLP(node, s)
        fmt.print("\n")
        return nil
    }))

}

vector_stuff :: proc(state: ^InterpreterState) {
    addGlobal(state, "vector", builtinNode(proc(node: ^Node, s: ^InterpreterState) -> ^Node {
        ret := make([dynamic]^Node)
        cur := node

        for isCons(cur) {
            append(&ret, eval(car(cur), s))
            cur = cdr(cur)
        }

        return vectorNode(ret)
    }))

    addGlobal(state, "vector-len", builtinNode(proc(node: ^Node, s: ^InterpreterState) -> ^Node {
        return numNode(Number(len(asVector(eval(car(node), s)))))
    }))

    addGlobal(state, "vector-ref", builtinNode(proc(node: ^Node, s: ^InterpreterState) -> ^Node {
        return asVector(eval(car(node), s))[cast(int)asNumber(eval(car(cdr(node)), s))]
    }))
}

string_stuff :: proc(state: ^InterpreterState) {
    addGlobal(state, "string->symbol", builtinNode(proc(node: ^Node, s: ^InterpreterState) -> ^Node {
        return symNode(asString(eval(car(node), s)), s)
    }))

    addGlobal(state, "symbol->string", builtinNode(proc(node: ^Node, s: ^InterpreterState) -> ^Node {
        return strNode(s.symbols[asSymbol(eval(car(node), s))])
    }))

    addGlobal(state, "string-len", builtinNode(proc(node: ^Node, s: ^InterpreterState) -> ^Node {
        return numNode(Number(len(asString(eval(car(node), s)))))
    }))

    addGlobal(state, "string-ref", builtinNode(proc(node: ^Node, s: ^InterpreterState) -> ^Node {
        return charNode(rune(asString(eval(car(node), s))[int(asNumber(car(cdr(node))))]))
    }))

    addGlobal(state, "string-foreach", builtinNode(proc(node: ^Node, s: ^InterpreterState) -> ^Node {
        e := eval(car(node), s)

        str := asString(eval(car(cdr(node)), s))

        for c in str {
            call_no_eval(s, e, consNode(charNode(c), nil))
        }

        return nil
    }))
}

control_flow_stuff :: proc(state: ^InterpreterState) {
    addGlobal(state, "if", builtinNode(proc(node: ^Node, s: ^InterpreterState) -> ^Node {
        if asBool(eval(car(node), s)) {
            return eval(car(cdr(node)), s)
        } else {
            return eval(car(cdr(cdr(node))), s)
        }
    }))

    addGlobal(state, "do", builtinNode(proc(node: ^Node, s: ^InterpreterState) -> ^Node {
        return evalL(node, s)
    }))

    addGlobal(state, "dotimes", builtinNode(proc(node: ^Node, s: ^InterpreterState) -> ^Node {
        for i in 0..<int(asNumber(eval(car(node), s))) {
            evalL(node, s)
        }
        return nil
    }))

    addGlobal(state, "when", builtinNode(proc(node: ^Node, s: ^InterpreterState) -> ^Node { // could be a macro!
        if asBool(eval(car(node), s)) {
            return evalL(cdr(node), s)
        }
        return nil
    }))

    addGlobal(state, "unless", builtinNode(proc(node: ^Node, s: ^InterpreterState) -> ^Node {
        if !asBool(eval(car(node), s)) {
            return evalL(cdr(node), s)
        }
        return nil
    }))

    addGlobal(state, "while", builtinNode(proc(node: ^Node, s: ^InterpreterState) -> ^Node {
        for asBool(eval(car(node), s)) {
            evalL(cdr(node), s)
        }

        return nil
    }))
}
