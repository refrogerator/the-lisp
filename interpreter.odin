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

    file, err := os.read_entire_file_from_filename("core/builtin.lisp")
    if !err {
        fmt.println("builtins not found")
        os.exit(1)
    }
    defer delete(file);

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

    temp := read(string(file), state)
    evalL(temp, state)

    return state
}

new_namespace :: proc(s: ^InterpreterState) {
    m := make(map[Symbol]^Node)
    append(&s.stack, m)
}

new_extending_namespace :: proc(s: ^InterpreterState) {
    m := make(map[Symbol]^Node)
    for k, v in last(s.stack) {
        m[k] = v
    }
    append(&s.stack, m)
}

pop_namespace :: proc(s: ^InterpreterState) {
    pop(&s.stack)
}

call_lambda_internal :: proc(s: ^InterpreterState, e: bool, lambda: Lambda, args: ^Node) -> ^Node {
    curIn := args
    curArg := lambda.args

    m := make(map[Symbol]^Node)

    if lambda.captures != nil {
        for k, v in lambda.captures {
            m[k] = v
        }
    }

    for isCons(curArg) { // TODO arity checking
        if car(curIn) == nil {
            error("not enough arguments were given")
        }
        m[asSymbol(car(curArg))] = eval(car(curIn), s) if e else car(curIn)
        curIn = cdr(curIn)
        curArg = cdr(curArg)
    }

    if curArg != nil {
        if car(curIn) == nil {
            error("not enough arguments were given")
        }

        ret: ^Node = nil
        for isCons(curIn) { // TODO arity checking
            ret = consNode(eval(car(curIn), s) if e else car(curIn), ret)
            curIn = cdr(curIn)
        }

        m[asSymbol(curArg)] = reverse(ret)
    }

    append(&s.stack, m)

    temp: ^Node
    if e {
        temp = evalL(lambda.body, s) 
    } else {
        temp = evalL(lambda.body, s)
    }

    pop(&s.stack)

    return temp
}

call_macro :: proc(s: ^InterpreterState, macro: Macro, args: ^Node) -> ^Node {
    temp := call_lambda_internal(s, false, Lambda(macro), args)
    writeln(temp, s)
    return eval(temp, s)
}

call_builtin :: proc(s: ^InterpreterState, builtin: Builtin, args: ^Node) -> ^Node {
    return builtin.tr(args, s)
}

call_no_eval :: proc(s: ^InterpreterState, fn: ^Node, args: ^Node) -> ^Node {
    #partial switch f in eval(fn, s) {
    case Builtin:
        temp := f.tr(args, s)
        return temp
    case Macro:
        return call_macro(s, f, args)
    case Lambda:
        return call_lambda_internal(s, false, f, args)
    case:
        fmt.eprint("can't call non-function ")
        println(fn, s)
        os.exit(1)
    }
}

eval :: proc(node: ^Node, s: ^InterpreterState) -> ^Node {
    if node == nil {
        return nil
    }
    #partial switch n in node {
    case Cons:
        #partial switch f in eval(n.car, s) {
        case Builtin:
            //append(&s.allocStack, make([dynamic]rawptr, (cast(^MarkSweepGC)s.allocator.data).backing_allocator))
            //mark_sweep_pause(s.allocator)
            temp := f.tr(n.cdr, s)

            //delete(pop(&s.allocStack))
            //mark_sweep_unpause(s.allocator)
            return temp
        case Macro:
            return call_macro(s, f, n.cdr)
        case Lambda:
            return call_lambda_internal(s, true, f, n.cdr)
        case:
            fmt.eprint("can't call non-function ")
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

