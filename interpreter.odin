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

    addGlobal(state, "gc", builtinNode(proc(node: ^Node, s: ^InterpreterState) -> ^Node {
        mark_sweep_run_gc(cast(^MarkSweepGC)s.allocator.data)
        return nil
    }))

    basic_math_stuff(state)
    bool_stuff(state)
    list_stuff(state)
    builtin_stuff(state)
    basic_io_stuff(state)
    vector_stuff(state)
    string_stuff(state)
    control_flow_stuff(state)

    return state
}

//new_namespace :: proc(s: ^InterpreterState) {
//    m := make(map[Symbol]^Node)
//    append(&s.stack, m)
//}

//new_extending_namespace :: proc(s: ^InterpreterState) {
//    m := new_clone(last(s.stack)^)
//    append(&s.stack, m)
//}

//pop_namespace :: proc(s: ^InterpreterState) {
//    pop(&s.stack)
//}

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
            
            _temp := evalL(f.body, s)
            //println(_temp, s)
            temp := eval(evalL(f.body, s), s) 

            pop(&s.stack)

            return temp
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

