package main

import "core:fmt"

printInternal :: proc(input: ^Node, pretty: bool, s: ^InterpreterState) {
    if input == nil {
        fmt.print("nil")
        return;
    }
    switch v in input {
        case Cons:
            fmt.print("(")
            first := true
            cur := input
            loop: for cur != nil {
                #partial switch c in cur {
                    case Cons:
                        if !first { fmt.print(" ") }
                        printInternal(c.car, pretty, s)
                        cur = c.cdr
                    case:
                        fmt.print(" . ")
                        printInternal(cur, pretty, s)
                        break loop
                }
                first = false
            }
            fmt.print(")")
        case Number:
            fmt.print(v)
        case bool:
            if v {
                fmt.print("#t")
            } else {
                fmt.print("#f")
            }
        case rune:
            if pretty {
                fmt.printf("#\\%v", v)
            } else {
                fmt.print(v)
            }
        case string:
            if pretty {
                fmt.printf("\"%v\"", v)
            } else {
                fmt.print(v)
            }
        case Symbol:
            fmt.print(s.symbols[v])
        case Macro:
            fmt.print("(macro ")
            printInternal(v.args, pretty, s)
            fmt.print(")")
        case Lambda:
            fmt.print("(lambda ")
            printInternal(v.args, pretty, s)
            fmt.print(")")
        case Builtin:
            fmt.print("<builtin>")
        case [dynamic]^Node:
            fmt.print("#(")
            first2 := true
            for i in v {
                if !first2 {
                    fmt.print(" ")
                }
                print(i, s)
                first2 = false
            }
            fmt.print(")")
    }
}

write :: proc(node: ^Node, s: ^InterpreterState) {
    printInternal(node, false, s)
}

writeln :: proc(node: ^Node, s: ^InterpreterState) {
    write(node, s)
    fmt.print("\n")
}

print :: proc(node: ^Node, s: ^InterpreterState) {
    printInternal(node, true, s)
}

println :: proc(node: ^Node, s: ^InterpreterState) {
    print(node, s)
    fmt.print("\n")
}

printL :: proc(node: ^Node, s: ^InterpreterState) {
    dolist(node, proc(node: ^Node, s: ^InterpreterState) { print(node, s) }, s)
}

printlnL :: proc(node: ^Node, s: ^InterpreterState) {
    dolist(node, proc(node: ^Node, s: ^InterpreterState) { println(node, s) }, s)
}

