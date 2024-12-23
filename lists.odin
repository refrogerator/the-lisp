package main

import "core:fmt"
import "core:os"

set_car :: proc(n: ^Node, s: ^Node) {
    if n == nil {
    } else {
        if cons, ok := &n.(Cons); ok {
            cons.car = s
        } else {
            fmt.printf("cant take car of value %v", n)
            os.exit(1)
        }
    }
}

set_cdr :: proc(n: ^Node, s: ^Node) {
    if n == nil {
    } else {
        if cons, ok := &n.(Cons); ok {
            cons.cdr = s
        } else {
            fmt.printf("cant take car of value %v", n)
            os.exit(1)
        }
    }
}

car :: proc(n: ^Node) -> ^Node {
    if n == nil {
        return nil
    } else {
        if cons, ok := n.(Cons); ok {
            return cons.car
        } else {
            fmt.printf("cant take car of value %v", n)
            os.exit(1)
        }
    }
}

cdr :: proc(n: ^Node) -> ^Node {
    if n == nil {
        return nil
    } else {
        if cons, ok := n.(Cons); ok {
            return cons.cdr
        } else {
            fmt.printf("cant take cdr of value %v", n)
            os.exit(1)
        }
    }
}

reverse :: proc(list: ^Node) -> ^Node {
    prev: ^Node = nil
    cur := list

    for isCons(cur) {
        c := &cur.(Cons) 
        next := c.cdr
        c.cdr = prev
        prev = cur
        cur = next
    }

    return prev
}

length :: proc(list: ^Node) -> Number {
    cur := list
    count := 0

    for isCons(cur) {
        count += 1
        cur = cdr(cur)
    }
    return Number(count)
}

Reducer :: proc(^Node, ^Node, ^InterpreterState) -> ^Node

reduce :: proc(list: ^Node, reducer: Reducer, s: ^InterpreterState) -> ^Node {
    if !isCons(list) {
        return list
    }

    cur := list.(Cons).cdr
    acc := eval(list.(Cons).car, s)

    for isCons(cur) {
        c := cur.(Cons) 
        acc = reducer(c.car, acc, s)
        cur = c.cdr
    }

    return acc
}

dolist :: proc(list: ^Node, user: NodeConsumer, s: ^InterpreterState) {
    cur := list

    for isCons(cur) {
        c := cur.(Cons) 
        user(c.car, s)
        cur = c.cdr
    }
}

