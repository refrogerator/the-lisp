package main

import "core:fmt"
import "core:strconv"

last :: proc(arr: [dynamic]$T) -> ^T {
    return &arr[len(arr) - 1]
}

appendNode :: proc(state: ^InterpreterState, node: ^Node, ret: ^^Node, listStack: [dynamic]^Node) {
    if len(listStack) == 0 {
        ret^ = consNode(node, ret^)
    } else {
        listStack[len(listStack) - 1] = consNode(node, listStack[len(listStack) - 1])
    }
}

// for dotted list support
reverseForReader :: proc(list: ^Node, isDot: bool) -> ^Node {
    prev: ^Node = nil
    cur := list

    if !isCons(cdr(cur)) {
        return list
    }

    second := cdr(cur)

    for isCons(cur) {
        c := &cur.(Cons) 
        next := c.cdr
        c.cdr = prev
        prev = cur
        cur = next
    }

    if isDot {
        set_cdr(second, car(cdr(second)))
    }

    return prev
}

handleSymbol :: proc(start: int, i: int, input: string, state: ^InterpreterState, ret: ^^Node, listStack: [dynamic]^Node) -> int {
    if start != i - 1 {
        appendNode(state, symNode(input[start+1:i], state), ret, listStack)
    }
    return i
}

TokenType :: enum {
    Any,
    Integer,
    Float,
    String,
    Comment,
    Other,
    Char,
}

Reader :: struct {
    input: string,
    offset: int,
    state: ^InterpreterState,
}

read_comment :: proc(using reader: ^Reader) {
    for input[offset] != '\n' {
        offset += 1
    }
}

read_list :: proc(using reader: ^Reader) -> ^Node {
    //fmt.println("list")
    list: ^Node = nil

    cur := list
    dot := 0

    for input[offset] != ')' {
        new := consNode(read_next(reader), nil)

        if isSymbol(car(new)) && state.symbols[asSymbol(car(new))] == "." {
            set_cdr(cur, read_next(reader))
            if input[offset] != ')' {
                fmt.println("amog", input[offset:])
                error("can't have more than one element after dot")
            }
            offset += 1
            return list
        }

        if cur == nil {
            cur = new
            list = cur
        } else {
            set_cdr(cur, new)
            cur = cdr(cur)
        }
    }

    offset += 1

    return list
}

read_number :: proc(using reader: ^Reader) -> ^Node {
    //fmt.println("number")
    start := offset
    is_float := false

    for {
        c := input[offset]
        if c == '.' {
            if is_float {
                error("invalid numeric literal")
            }
            is_float = true
        } else if (c < '0' || c > '9') {
            return numNode(strconv.atof(input[start:offset]))
        }
        offset += 1
    }
}

read_symbol :: proc(using reader: ^Reader) -> ^Node {
    //fmt.println("symbol")
    start := offset

    for {
        switch input[offset] {
        case '(', ')', '0'..='9', ';', '\'', ' ', '\t', '\n', '"':
            return symNode(input[start:offset], state)
        }
        offset += 1
    }
}

read_string :: proc(using reader: ^Reader) -> ^Node {
    start := offset
    for input[offset] != '"' {
        offset += 1
    }
    offset += 1
    return strNode(input[start:offset-1])
}

quote :: proc(using reader: ^Reader) -> ^Node {
    return consNode(symNode("quote", reader.state), consNode(read_next(reader), nil))
}

read_next :: proc(using reader: ^Reader) -> ^Node {
    //fmt.println(rune(input[offset]))
    for offset < len(input) {
        switch input[offset] {
        case '(':
            offset += 1
            return read_list(reader) // offset += 1
        case '"':
            offset += 1
            return read_string(reader) // offset += 1
        case '0'..='9':
            return read_number(reader)
        case '\'':
            offset += 1
            return quote(reader)
        case ';':
            read_comment(reader)
        case ' ', '\t', '\n':
            offset += 1
        case:
            return read_symbol(reader)
        }
    }
    return nil
}

read :: proc(input: string, state: ^InterpreterState) -> ^Node {
    reader := Reader { input, 0, state }
    cur: ^Node = nil

    out := read_next(&reader)
    for out != nil {
        cur = consNode(out, cur)
        out = read_next(&reader)
    }

    return reverse(cur)
}
