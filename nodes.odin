package main

NodeConsumer :: proc(^Node, ^InterpreterState)
NodeTransformer :: proc(^Node, ^InterpreterState) -> ^Node

Builtin :: struct {
    tr: NodeTransformer,
    // TODO add type info
}

Cons :: struct {
    car: ^Node,
    cdr: ^Node,
}

Number :: f64

Symbol :: distinct int

Lambda :: struct {
    args: ^Node,
    body: ^Node,
    captures: map[Symbol]^Node,
}

Macro :: distinct Lambda

Port :: struct {
    len: ^Node // optional
}

Node :: union {
    Cons,
    Number,
    rune,
    string,
    Symbol,
    [dynamic]^Node,
    bool,
    Lambda,
    Macro,
    Builtin,
}

consNode :: proc(car: ^Node, cdr: ^Node) -> ^Node {
    ret := new(Node)
    ret^ = Cons{car, cdr}
    return ret
}

numNode :: proc(n: Number) -> ^Node {
    ret := new(Node)
    ret^ = n
    return ret
}

charNode :: proc(s: rune) -> ^Node {
    ret := new(Node)
    ret^ = s
    return ret
}

strNode :: proc(s: string) -> ^Node {
    ret := new(Node)
    ret^ = s
    return ret
}

vectorNode :: proc(vec: [dynamic]^Node) -> ^Node {
    ret := new(Node)
    ret^ = vec
    return ret
}

symNode :: proc(str: string, s: ^InterpreterState) -> ^Node {
    ret := new(Node)
    ret^ = toSymbol(str, s)
    return ret
}

boolNode :: proc(n: bool) -> ^Node {
    ret := new(Node)
    ret^ = n
    return ret
}

lambdaNode :: proc(args: ^Node, body: ^Node, env: map[Symbol]^Node) -> ^Node {
    ret := new(Node)
    ret^ = Lambda { args, body, env }
    return ret
}

macroNode :: proc(args: ^Node, body: ^Node) -> ^Node {
    ret := new(Node)
    ret^ = Macro { args, body, nil }
    return ret
}

builtinNode :: proc(tr: NodeTransformer) -> ^Node {
    ret := new(Node)
    ret^ = Builtin { tr }
    return ret
}

asCons :: proc(node: ^Node) -> Cons {
    if node == nil {
        error("node is not of type cons")
    }
    if n, ok := node.(Cons); ok {
        return n
    }
    error("node is not of type cons")
    return Cons{nil, nil}
}

asString :: proc(node: ^Node) -> string {
    if node == nil {
        error("node is not of type string")
    }
    if n, ok := node.(string); ok {
        return n
    }
    error("node is not of type string")
    return ""
}

asSymbol :: proc(node: ^Node) -> Symbol {
    if node == nil {
        error("node is not of type symbol")
    }
    if n, ok := node.(Symbol); ok {
        return n
    }
    error("node is not of type symbol")
    return Symbol(0)
}

asNumber :: proc(node: ^Node) -> Number {
    if node == nil {
        error("node is not of type number")
    }
    if n, ok := node.(Number); ok {
        return n
    }
    error("node is not of type number")
    return 0
}

asBool :: proc(node: ^Node) -> bool {
    if node == nil {
        error("node is not of type bool")
    }
    if n, ok := node.(bool); ok {
        return n
    }
    error("node is not of type bool")
    return false
}

asVector :: proc(node: ^Node) -> [dynamic]^Node {
    if node == nil {
        error("node is not of type vector")
    }
    if n, ok := node.([dynamic]^Node); ok {
        return n
    }
    error("node is not of type vector")
    return nil
}

isCons :: proc(node: ^Node) -> bool {
    if node == nil {
        return false
    }
    if _, ok := node.(Cons); ok {
        return true
    }
    return false
}

isSymbol :: proc(node: ^Node) -> bool {
    if node == nil {
        return false
    }
    if _, ok := node.(Symbol); ok {
        return true
    }
    return false
}

