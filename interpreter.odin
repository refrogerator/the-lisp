package main

import "core:fmt"
import "core:os"
import "base:runtime"

error :: proc(s: string) {
    fmt.eprintln(s)
    os.exit(1)
}

InterpreterState :: struct {
    symbols: [dynamic]string,
    globals: map[Symbol]^Node,
    stack: [dynamic]map[Symbol]^Node,
    allocStack: [dynamic][dynamic]rawptr,
    allocator: runtime.Allocator,
}

toSymbol :: proc(s: string, state: ^InterpreterState) -> Symbol {
    for sym, i in state.symbols {
        if s == sym {
            return Symbol(i)
        }
    }
    append(&state.symbols, s)
    return Symbol(len(state.symbols) - 1)
}

findSymbol :: proc(sym: Symbol, state: ^InterpreterState) -> ^Node {
    ret: ^Node
    ok := false
    if len(state.stack) > 0 {
        ret, ok = last(state.stack)[sym]
    }
    if !ok {
        ret, ok = state.globals[sym]
        if !ok {
            fmt.println("symbol", state.symbols[sym], "doesn't exist")
            os.exit(1)
        }
    }
    return ret
}

addGlobal :: proc(state: ^InterpreterState, key: string, value: ^Node) {
    state.globals[toSymbol(key, state)] = value
}

addAlias :: proc(state: ^InterpreterState, key: string, alias: string) {
    addGlobal(state, alias, state.globals[toSymbol(key, state)])
}

createInterpreter :: proc() -> ^InterpreterState {
    state := new(InterpreterState)
    state^ = { make([dynamic]string), make(map[Symbol]^Node), make([dynamic]map[Symbol]^Node), make([dynamic][dynamic]rawptr), mark_sweep_gc(state) }

    append(&state.allocStack, make([dynamic]rawptr))

    context.allocator = state.allocator

    addGlobal(state, "nil", nil)

    addGlobal(state, "true", boolNode(true))
    addGlobal(state, "false", boolNode(false))

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

    addGlobal(state, "not", builtinNode(proc(node: ^Node, s: ^InterpreterState) -> ^Node {
        return boolNode(!asBool(eval(car(node), s)))
    }))

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

    addGlobal(state, "if", builtinNode(proc(node: ^Node, s: ^InterpreterState) -> ^Node {
        if asBool(eval(car(node), s)) {
            return eval(car(cdr(node)), s)
        } else {
            return eval(car(cdr(cdr(node))), s)
        }
    }))

    addGlobal(state, "when", builtinNode(proc(node: ^Node, s: ^InterpreterState) -> ^Node {
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

    addGlobal(state, "list", builtinNode(proc(node: ^Node, s: ^InterpreterState) -> ^Node {
        cur := node
        ret: ^Node = nil

        for isCons(cur) {
            ret = consNode(eval(car(cur), s), ret)
            cur = cdr(cur)
        }

        return reverse(ret)
    }))

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

    addGlobal(state, "string-foreach", builtinNode(proc(node: ^Node, s: ^InterpreterState) -> ^Node {
        return nil // TODO dont have
    }))

    addGlobal(state, "string->symbol", builtinNode(proc(node: ^Node, s: ^InterpreterState) -> ^Node {
        return symNode(asString(eval(car(node), s)), s)
    }))

    addGlobal(state, "symbol->string", builtinNode(proc(node: ^Node, s: ^InterpreterState) -> ^Node {
        return strNode(s.symbols[asSymbol(eval(car(node), s))])
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

    addGlobal(state, "while", builtinNode(proc(node: ^Node, s: ^InterpreterState) -> ^Node {
        for asBool(eval(car(node), s)) {
            evalL(cdr(node), s)
        }

        return nil
    }))

    addGlobal(state, "gc", builtinNode(proc(node: ^Node, s: ^InterpreterState) -> ^Node {
        mark_sweep_run_gc(cast(^MarkSweepGC)s.allocator.data)
        return nil
    }))


    return state
}

eval :: proc(node: ^Node, s: ^InterpreterState) -> ^Node {
    if node == nil {
        return nil
    }
    #partial switch n in node {
    case Cons:
        #partial switch f in eval(n.car, s) {
        case Builtin:
            append(&s.allocStack, make([dynamic]rawptr, (cast(^MarkSweepGC)s.allocator.data).backing_allocator))
            //mark_sweep_pause(s.allocator)
            temp := f.tr(n.cdr, s)

            delete(pop(&s.allocStack))
            //mark_sweep_unpause(s.allocator)
            return temp
        case Macro:
            curIn := n.cdr
            curArg := f.args

            m := make(map[Symbol]^Node, (cast(^MarkSweepGC)s.allocator.data).backing_allocator)

            for isCons(curArg) { // TODO arity checking
                if car(curIn) == nil {
                    error("not enough arguments were given")
                }
                m[asSymbol(car(curArg))] = car(curIn)
                curIn = cdr(curIn)
                curArg = cdr(curArg)
            }

            if curArg != nil {
                if car(curIn) == nil {
                    error("not enough arguments were given")
                }

                ret: ^Node = nil
                for isCons(curIn) { // TODO arity checking
                    ret = consNode(car(curIn), ret)
                    curIn = cdr(curIn)
                }

                m[asSymbol(curArg)] = reverse(ret)
            }

            append(&s.stack, m)
            
            return eval(evalL(f.body, s), s)
        case Lambda:
            curIn := n.cdr
            curArg := f.args

            m := make(map[Symbol]^Node)

            if f.captures != nil {
                for k, v in f.captures {
                    m[k] = v
                }
            }

            for isCons(curArg) { // TODO arity checking
                if car(curIn) == nil {
                    error("not enough arguments were given")
                }
                m[asSymbol(car(curArg))] = eval(car(curIn), s)
                curIn = cdr(curIn)
                curArg = cdr(curArg)
            }

            if curArg != nil {
                if car(curIn) == nil {
                    error("not enough arguments were given")
                }

                ret: ^Node = nil
                for isCons(curIn) { // TODO arity checking
                    ret = consNode(eval(car(curIn), s), ret)
                    curIn = cdr(curIn)
                }

                m[asSymbol(curArg)] = reverse(ret)
            }

            append(&s.stack, m)
            
            temp := evalL(f.body, s) 

            pop(&s.stack)

            return temp
        case:
            fmt.eprintln("can't call non-function", f)
            print(n.car,s)
            os.exit(1)
        }
    case Symbol:
        return findSymbol(n, s)
    }
    return node
}

evalL :: proc(list: ^Node, s: ^InterpreterState) -> ^Node {
    c := context
    cur := list
    last: ^Node = nil

    for isCons(cur) {
        c := cur.(Cons) 
        last = eval(c.car, s)
        cur = c.cdr
    }

    return last
}

evalI :: proc(list: ^Node, s: ^InterpreterState) -> ^Node {
    context.allocator = s.allocator
    return evalL(list, s)
}

evalLW :: proc(list: ^Node, s: ^InterpreterState) {
    dolist(list, proc(node: ^Node, s: ^InterpreterState) { write(eval(node, s), s) }, s)
}

evalLP :: proc(list: ^Node, s: ^InterpreterState) {
    dolist(list, proc(node: ^Node, s: ^InterpreterState) { print(eval(node, s), s) }, s)
}

