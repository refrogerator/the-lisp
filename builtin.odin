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

    addGlobal(state, "map", builtinNode(proc(node: ^Node, s: ^InterpreterState) -> ^Node {
        cur := eval(car(cdr(node)), s)
        ret: ^Node = nil

        e := consNode(eval(car(node), s), consNode(nil, nil))

        for isCons(cur) {
            set_car(cdr(e), car(cur))
            ret = consNode(eval(e, s), ret)
            cur = cdr(cur)
        }

        return reverse(ret)
    }))

    addGlobal(state, "foreach", builtinNode(proc(node: ^Node, s: ^InterpreterState) -> ^Node {
        cur := eval(car(cdr(node)), s)

        e := consNode(eval(car(node), s), consNode(nil, nil))

        for isCons(cur) {
            set_car(cdr(e), car(cur))
            eval(e, s)
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

    addGlobal(state, "lambda", builtinNode(proc(node: ^Node, s: ^InterpreterState) -> ^Node {
        return lambdaNode(car(node), cdr(node), last(s.stack)^ if len(s.stack) > 0 else nil)
    }))

    addAlias(state, "lambda", "fn")

    addGlobal(state, "define-macro", builtinNode(proc(node: ^Node, s: ^InterpreterState) -> ^Node {
        s.globals[asSymbol(car(node))] = macroNode(car(cdr(node)), cdr(cdr(node)))
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

    addGlobal(state, "string-foreach", builtinNode(proc(node: ^Node, s: ^InterpreterState) -> ^Node {
        e := consNode(eval(car(node), s), consNode(nil, nil))

        str := asString(eval(car(cdr(node)), s))

        for c in str {
            set_car(cdr(e), charNode(c))
            eval(e, s)
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
